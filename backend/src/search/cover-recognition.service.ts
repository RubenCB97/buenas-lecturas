import {
  BadRequestException,
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import Anthropic from '@anthropic-ai/sdk';
import { SearchService } from './search.service';

export const COVER_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'] as const;
type CoverMime = (typeof COVER_MIME_TYPES)[number];

/** Lo que Claude lee en la foto de la portada. */
export interface CoverReading {
  isBook: boolean;
  title: string | null;
  authors: string[];
  isbn: string | null;
}

const PROMPT = `Esta foto debería mostrar la portada (o el lomo o la contraportada) de un libro.
Lee el título y el autor tal y como aparecen impresos. Si se ve un ISBN, cópialo.
No inventes datos: deja un campo a null si no se lee con claridad.
Si la foto no muestra un libro, marca isBook como false.`;

const READING_SCHEMA = {
  type: 'object',
  properties: {
    isBook: { type: 'boolean' },
    title: { type: ['string', 'null'], description: 'Título principal, sin subtítulo ni frases promocionales' },
    authors: { type: 'array', items: { type: 'string' } },
    isbn: { type: ['string', 'null'] },
  },
  required: ['isBook', 'title', 'authors', 'isbn'],
  additionalProperties: false,
};

/**
 * Reconoce un libro a partir de una foto de su portada: Claude lee título,
 * autor e ISBN y después lo buscamos en los catálogos habituales.
 * Requiere ANTHROPIC_API_KEY en el entorno del backend.
 */
@Injectable()
export class CoverRecognitionService {
  private readonly logger = new Logger(CoverRecognitionService.name);
  private client: Anthropic | null = null;

  constructor(private readonly searchService: SearchService) {}

  get isEnabled(): boolean {
    return !!process.env.ANTHROPIC_API_KEY;
  }

  private getClient(): Anthropic {
    if (!this.isEnabled) {
      throw new ServiceUnavailableException(
        'El reconocimiento de portadas no está configurado en el servidor',
      );
    }
    this.client ??= new Anthropic({ timeout: 60_000, maxRetries: 1 });
    return this.client;
  }

  async recognize(image: Buffer, mimeType: string) {
    if (!COVER_MIME_TYPES.includes(mimeType as CoverMime)) {
      throw new BadRequestException('Formato de imagen no soportado (usa JPG, PNG o WebP)');
    }
    const reading = await this.readCover(image, mimeType as CoverMime);
    if (!reading.isBook || (!reading.title && !reading.isbn)) {
      return { reading, results: [] };
    }

    // Con ISBN legible el resultado es exacto
    const isbn = reading.isbn ? SearchService.normalizeIsbn(reading.isbn) : null;
    if (isbn) {
      const byIsbn = await this.searchService.lookupByIsbn(isbn).catch(() => null);
      if (byIsbn) return { reading, results: [byIsbn] };
    }

    const query = CoverRecognitionService.buildQuery(reading);
    const results = query ? await this.searchService.searchBooks(query).catch(() => []) : [];
    return { reading, results: Array.isArray(results) ? results.slice(0, 10) : [] };
  }

  /**
   * Tipo real de la imagen según sus primeros bytes: los móviles a veces la
   * envían como application/octet-stream y Claude exige el tipo correcto.
   */
  static sniffMime(buffer: Buffer): CoverMime | null {
    if (buffer.length < 12) return null;
    if (buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) return 'image/jpeg';
    if (buffer.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return 'image/png';
    if (buffer.toString('ascii', 0, 4) === 'RIFF' && buffer.toString('ascii', 8, 12) === 'WEBP') return 'image/webp';
    if (buffer.toString('ascii', 0, 4) === 'GIF8') return 'image/gif';
    return null;
  }

  /** Consulta de búsqueda a partir de lo leído en la portada. */
  static buildQuery(reading: CoverReading): string | null {
    const title = reading.title?.replace(/["]/g, '').trim();
    if (!title) return null;
    const author = reading.authors?.[0]?.replace(/["]/g, '').trim();
    return author ? `intitle:"${title}" inauthor:"${author}"` : `intitle:"${title}"`;
  }

  private async readCover(image: Buffer, mimeType: CoverMime): Promise<CoverReading> {
    const client = this.getClient();
    let response: Anthropic.Beta.BetaMessage;
    try {
      response = await client.beta.messages.create({
        model: 'claude-opus-5',
        max_tokens: 2000,
        betas: ['server-side-fallback-2026-07-01'],
        fallbacks: 'default',
        output_config: {
          effort: 'low',
          format: { type: 'json_schema', schema: READING_SCHEMA },
        },
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'image',
                source: { type: 'base64', media_type: mimeType, data: image.toString('base64') },
              },
              { type: 'text', text: PROMPT },
            ],
          },
        ],
      });
    } catch (error) {
      if (error instanceof Anthropic.RateLimitError) {
        throw new ServiceUnavailableException('Demasiadas peticiones, prueba en unos segundos');
      }
      if (error instanceof Anthropic.APIError) {
        this.logger.error(`Claude API ${error.status}: ${error.message}`);
      } else {
        this.logger.error(`Error reconociendo portada: ${(error as Error).message}`);
      }
      throw new ServiceUnavailableException('No se pudo analizar la foto ahora mismo');
    }

    if (response.stop_reason === 'refusal') {
      return { isBook: false, title: null, authors: [], isbn: null };
    }
    const text = response.content.find((b): b is Anthropic.Beta.BetaTextBlock => b.type === 'text')?.text;
    try {
      const parsed = JSON.parse(text ?? '');
      return {
        isBook: parsed.isBook === true,
        title: typeof parsed.title === 'string' && parsed.title.trim() ? parsed.title.trim() : null,
        authors: Array.isArray(parsed.authors) ? parsed.authors.filter((a) => typeof a === 'string' && a.trim()) : [],
        isbn: typeof parsed.isbn === 'string' && parsed.isbn.trim() ? parsed.isbn.trim() : null,
      };
    } catch {
      this.logger.warn('Respuesta de Claude no interpretable al leer una portada');
      return { isBook: false, title: null, authors: [], isbn: null };
    }
  }
}
