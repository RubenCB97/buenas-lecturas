import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Like, Repository } from 'typeorm';
import { Book } from './entities/book.entity';
import axios from 'axios';

@Injectable()
export class BooksService implements OnModuleInit {
  private readonly logger = new Logger(BooksService.name);

  constructor(
    @InjectRepository(Book)
    private booksRepository: Repository<Book>,
  ) {}

  async onModuleInit() {
    // Migración perezosa: normalizar thumbnails que quedaron con host de proxy
    // guardado en versiones anteriores (localhost:3000, 10.0.2.2:3000, etc.)
    try {
      const toFix = await this.booksRepository.find({
        where: { thumbnail: Like('%/proxy/image?url=%') },
      });
      if (toFix.length === 0) return;
      this.logger.log(`Normalizando ${toFix.length} thumbnails con URL de proxy antigua...`);
      for (const b of toFix) {
        const clean = this.normalizeThumbnail(b.thumbnail);
        if (clean && clean !== b.thumbnail) {
          b.thumbnail = clean;
          await this.booksRepository.save(b);
        }
      }
    } catch (e) {
      this.logger.warn(`No se pudo normalizar thumbnails: ${e.message}`);
    }
  }

  async fetchAdditionalDetailsFromOpenLibrary(isbn: string) {
    try {
      const response = await axios.get(`https://openlibrary.org/api/books?bibkeys=ISBN:${isbn}&format=json&jscmd=data`);
      const data = response.data[`ISBN:${isbn}`];
      if (data) {
        return {
          language: data.languages ? data.languages.map(l => l.name).join(', ') : null,
          publisher: data.publishers ? data.publishers.map(p => p.name).join(', ') : null,
          pageCount: this.normalizePageCount(data.number_of_pages),
        };
      }
    } catch (error) {
      this.logger.error(`Error fetching from Open Library: ${error.message}`);
    }
    return {};
  }

  /**
   * Un número de páginas solo es válido si es positivo y plausible. Las APIs
   * devuelven a veces 0, null o cadenas, y guardarlo tal cual acaba mostrando
   * "0 páginas" en la ficha del libro.
   */
  private normalizePageCount(raw: any): number | null {
    let n: number | null = null;
    if (typeof raw === 'number') n = Math.trunc(raw);
    else if (typeof raw === 'string') {
      const parsed = parseInt(raw, 10);
      n = Number.isNaN(parsed) ? null : parsed;
    }
    if (n === null || n <= 0 || n > 50000) return null;
    return n;
  }

  /**
   * Intenta completar el número de páginas cuando la fuente original no lo
   * trae. Como mezclamos Google Books y Open Library, es habitual que una lo
   * tenga y la otra no, así que probamos en cascada:
   *   1. Open Library por ISBN
   *   2. Google Books por su id de volumen
   */
  private async resolvePageCount(bookData: any, extraInfo: any): Promise<number | null> {
    const direct = this.normalizePageCount(bookData?.pageCount);
    if (direct) return direct;

    const fromExtra = this.normalizePageCount(extraInfo?.pageCount);
    if (fromExtra) return fromExtra;

    // Google Books por id de volumen
    const googleId = bookData?.googleId ?? bookData?.id;
    if (googleId && typeof googleId === 'string' && !googleId.startsWith('OL')) {
      try {
        const apiKey = process.env.GOOGLE_BOOKS_API_KEY;
        const res = await fetch(
          `https://www.googleapis.com/books/v1/volumes/${encodeURIComponent(googleId)}${apiKey ? `?key=${apiKey}` : ''}`,
          { headers: { Accept: 'application/json' } },
        );
        if (res.ok) {
          const vol: any = await res.json();
          const n = this.normalizePageCount(vol?.volumeInfo?.pageCount);
          if (n) return n;
        }
      } catch (e) {
        this.logger.debug(`No se pudo completar pageCount desde Google Books: ${e.message}`);
      }
    }

    return null;
  }

  /**
   * Extrae la URL original de una thumbnail que puede venir envuelta por el
   * proxy (`http(s)://<host>/proxy/image?url=<encoded>`). Guardar la URL
   * original en BD evita que la caché quede atada a un host concreto
   * (localhost, 10.0.2.2, IP LAN, dominio de producción...) y garantiza que
   * cualquier cliente pueda decidir si necesita proxy o no.
   */
  private normalizeThumbnail(raw: any): string | null {
    if (!raw || typeof raw !== 'string') return null;
    let url = raw.trim();
    if (!url) return null;
    try {
      const match = url.match(/\/proxy\/image\?url=([^&]+)/i);
      if (match && match[1]) {
        url = decodeURIComponent(match[1]);
      }
    } catch (_) { /* ignore */ }
    if (url.startsWith('http://')) url = 'https://' + url.substring('http://'.length);
    return url;
  }

  async findOrCreateByGoogleId(bookData: any): Promise<Book> {
    try {
      const googleId = bookData.googleId || (bookData.id ? bookData.id.toString() : null);
      let book: Book | null = null;
      if (googleId) {
        book = await this.booksRepository.findOne({ where: { googleId } });
      }
      if (!book && bookData.title) {
        book = await this.booksRepository.findOne({ where: { title: bookData.title } });
      }

      if (!book) {
        let extraInfo: any = {};
        if (bookData.isbn) {
          extraInfo = await this.fetchAdditionalDetailsFromOpenLibrary(bookData.isbn);
        }

        book = this.booksRepository.create({
          googleId: googleId || `custom_${Date.now()}`,
          title: bookData.title || 'Sin título',
          subtitle: bookData.subtitle,
          authors: Array.isArray(bookData.authors) ? bookData.authors.join(', ') : (bookData.authors || ''),
          description: bookData.description,
          isbn: bookData.isbn,
          publishedDate: bookData.publishedDate?.toString(),
          thumbnail: this.normalizeThumbnail(bookData.thumbnail) ?? undefined,
          pageCount: (await this.resolvePageCount(bookData, extraInfo)) ?? undefined,
          categories: Array.isArray(bookData.categories) ? bookData.categories.join(', ') : (bookData.categories || ''),
          averageRating: typeof bookData.averageRating === 'number' ? bookData.averageRating : (parseFloat(bookData.averageRating) || null),
          publisher: bookData.publisher || extraInfo['publisher'],
          language: bookData.language || extraInfo['language'],
          asin: bookData.asin,
          awards: Array.isArray(bookData.awards) ? bookData.awards.join(', ') : (bookData.awards || null),
        });
        book = await this.booksRepository.save(book);
      } else if (!this.normalizePageCount(book.pageCount)) {
        // El libro ya estaba guardado pero sin páginas (o con 0): aprovechamos
        // para completarlo ahora que puede que tengamos ISBN o id de volumen.
        let extraInfo: any = {};
        const isbn = book.isbn || bookData.isbn;
        if (isbn) {
          extraInfo = await this.fetchAdditionalDetailsFromOpenLibrary(isbn);
        }
        const resolved = await this.resolvePageCount(
          { ...bookData, googleId: book.googleId, pageCount: bookData?.pageCount },
          extraInfo,
        );
        if (resolved) {
          book.pageCount = resolved;
          book = await this.booksRepository.save(book);
        }
      }

      return book;
    } catch (e) {
      this.logger.error(`Error in findOrCreateByGoogleId: ${e.message}`, e.stack);
      throw e;
    }
  }

  findAll() {
    return this.booksRepository.find();
  }

  findByGoogleId(googleId: string) {
    return this.booksRepository.findOne({ where: { googleId } });
  }

  findOne(id: number) {
    return this.booksRepository.findOneBy({ id });
  }
}
