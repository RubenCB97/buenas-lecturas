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
 * Misma estructura para Gemini, sin tipos nulables (su subconjunto de JSON
 * Schema es más limitado): los campos que no se lean van como cadena vacía.
 */
const GEMINI_READING_SCHEMA = {
  type: 'object',
  properties: {
    isBook: { type: 'boolean' },
    title: { type: 'string', description: 'Título principal; cadena vacía si no se lee' },
    authors: { type: 'array', items: { type: 'string' } },
    isbn: { type: 'string', description: 'ISBN impreso; cadena vacía si no se ve' },
  },
  required: ['isBook', 'title', 'authors', 'isbn'],
};

const EMPTY_READING: CoverReading = { isBook: false, title: null, authors: [], isbn: null };

/** Modelo de Gemini con plan gratuito que lee imágenes (configurable). */
const DEFAULT_GEMINI_MODEL = 'gemini-3.5-flash-lite';

/**
 * Reconoce un libro a partir de una foto de su portada: una IA lee título,
 * autor e ISBN y después lo buscamos en los catálogos habituales.
 *
 * Proveedores, por orden:
 *   1. Gemini (GEMINI_API_KEY, plan gratuito de Google AI Studio)
 *   2. Claude (ANTHROPIC_API_KEY), solo si Gemini no está o falla
 */
@Injectable()
export class CoverRecognitionService {
  private readonly logger = new Logger(CoverRecognitionService.name);
  private client: Anthropic | null = null;

  constructor(private readonly searchService: SearchService) {}

  get isEnabled(): boolean {
    return !!process.env.GEMINI_API_KEY || !!process.env.ANTHROPIC_API_KEY;
  }

  private getClaudeClient(): Anthropic {
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
    if (!this.isEnabled) {
      throw new ServiceUnavailableException(
        'El reconocimiento de portadas no está configurado en el servidor',
      );
    }
    let geminiError: unknown = null;
    if (process.env.GEMINI_API_KEY) {
      try {
        return await this.readWithGemini(image, mimeType);
      } catch (error) {
        geminiError = error;
        this.logger.warn(`Gemini no pudo leer la portada: ${(error as Error).message}`);
      }
    }
    if (process.env.ANTHROPIC_API_KEY) {
      return this.readWithClaude(image, mimeType);
    }
    if (geminiError instanceof GeminiRateLimitError) {
      throw new ServiceUnavailableException('Se ha alcanzado el límite gratuito de análisis, prueba más tarde');
    }
    throw new ServiceUnavailableException('No se pudo analizar la foto ahora mismo');
  }

  private async readWithGemini(image: Buffer, mimeType: CoverMime): Promise<CoverReading> {
    const model = process.env.GEMINI_MODEL?.trim() || DEFAULT_GEMINI_MODEL;
    const res = await fetch('https://generativelanguage.googleapis.com/v1beta/interactions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': process.env.GEMINI_API_KEY!,
      },
      body: JSON.stringify({
        model,
        store: false,
        input: [
          { type: 'text', text: PROMPT },
          { type: 'image', mime_type: mimeType, data: image.toString('base64') },
        ],
        response_format: { type: 'text', mime_type: 'application/json', schema: GEMINI_READING_SCHEMA },
      }),
      signal: AbortSignal.timeout(60_000),
    });
    if (res.status === 429) throw new GeminiRateLimitError();
    if (!res.ok) {
      const body = await res.text().catch(() => '');
      throw new Error(`HTTP ${res.status} ${body.slice(0, 300)}`);
    }
    const body: any = await res.json();
    if (body?.status && body.status !== 'completed') {
      throw new Error(`Interacción en estado ${body.status}`);
    }
    const text = CoverRecognitionService.extractGeminiText(body);
    if (text === null) throw new Error('Respuesta de Gemini sin texto');
    return CoverRecognitionService.parseReading(text);
  }

  /** Texto generado en una respuesta de la Interactions API de Gemini. */
  static extractGeminiText(body: any): string | null {
    const texts: string[] = [];
    for (const step of Array.isArray(body?.steps) ? body.steps : []) {
      if (step?.type && step.type !== 'model_output') continue;
      for (const part of Array.isArray(step?.content) ? step.content : []) {
        if (part?.type === 'text' && typeof part.text === 'string') texts.push(part.text);
      }
    }
    return texts.length ? texts.join('') : null;
  }

  /** Normaliza el JSON devuelto por la IA (acepta que venga entre ```json). */
  static parseReading(text: string): CoverReading {
    try {
      const clean = text.trim().replace(/^```(?:json)?\s*/i, '').replace(/```$/, '').trim();
      const parsed = JSON.parse(clean);
      return {
        isBook: parsed.isBook === true,
        title: typeof parsed.title === 'string' && parsed.title.trim() ? parsed.title.trim() : null,
        authors: Array.isArray(parsed.authors)
          ? parsed.authors.filter((a) => typeof a === 'string' && a.trim()).map((a) => a.trim())
          : [],
        isbn: typeof parsed.isbn === 'string' && parsed.isbn.trim() ? parsed.isbn.trim() : null,
      };
    } catch {
      return EMPTY_READING;
    }
  }

  private async readWithClaude(image: Buffer, mimeType: CoverMime): Promise<CoverReading> {
    const client = this.getClaudeClient();
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

    if (response.stop_reason === 'refusal') return EMPTY_READING;
    const text = response.content.find((b): b is Anthropic.Beta.BetaTextBlock => b.type === 'text')?.text;
    return CoverRecognitionService.parseReading(text ?? '');
  }
}

class GeminiRateLimitError extends Error {
  constructor() {
    super('Límite de peticiones de Gemini alcanzado');
  }
}
