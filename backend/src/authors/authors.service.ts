import { Injectable, Logger } from '@nestjs/common';
import { SearchService } from '../search/search.service';

export interface AuthorSummary {
  name: string;
  olid?: string | null;
  photoUrl?: string | null;
  birthDate?: string | null;
  topWork?: string | null;
  workCount?: number | null;
  subjects?: string[];
}

export interface AuthorDetail extends AuthorSummary {
  bio?: string | null;
  deathDate?: string | null;
  books: any[];
  booksCount: number;
  averageRating?: number | null;
}

@Injectable()
export class AuthorsService {
  private readonly logger = new Logger(AuthorsService.name);

  // Caché simple en memoria para no martillear Open Library
  private static readonly cache = new Map<string, { value: any; expiresAt: number }>();
  private static readonly TTL_MS = 1000 * 60 * 60 * 6; // 6 h

  constructor(private readonly searchService: SearchService) {}

  private cacheGet<T>(key: string): T | null {
    const hit = AuthorsService.cache.get(key);
    if (!hit) return null;
    if (Date.now() > hit.expiresAt) {
      AuthorsService.cache.delete(key);
      return null;
    }
    return hit.value as T;
  }

  private cacheSet(key: string, value: any) {
    if (AuthorsService.cache.size > 300) {
      const oldest = AuthorsService.cache.keys().next().value;
      if (oldest) AuthorsService.cache.delete(oldest);
    }
    AuthorsService.cache.set(key, { value, expiresAt: Date.now() + AuthorsService.TTL_MS });
  }

  private photoFromOlid(olid?: string | null, photoId?: number | null): string | null {
    if (photoId) return `https://covers.openlibrary.org/a/id/${photoId}-M.jpg`;
    if (olid) return `https://covers.openlibrary.org/a/olid/${olid}-M.jpg`;
    return null;
  }

  /** Busca autores por nombre en Open Library. */
  async searchAuthors(query: string): Promise<AuthorSummary[]> {
    const q = (query ?? '').trim();
    if (q.length < 2) return [];

    const cacheKey = `search:${q.toLowerCase()}`;
    const cached = this.cacheGet<AuthorSummary[]>(cacheKey);
    if (cached) return cached;

    try {
      const url = `https://openlibrary.org/search/authors.json?q=${encodeURIComponent(q)}&limit=20`;
      const res = await fetch(url, {
        headers: {
          'User-Agent': 'BuenasLecturas/1.0 (contacto@buenaslecturas.app)',
          Accept: 'application/json',
        },
      });
      if (!res.ok) return [];
      const data = (await res.json()) as any;
      const docs: any[] = data?.docs ?? [];

      const results: AuthorSummary[] = docs
        .filter(d => d?.name)
        .map(d => ({
          name: d.name,
          olid: d.key ?? null,
          photoUrl: this.photoFromOlid(d.key),
          birthDate: d.birth_date ?? null,
          topWork: d.top_work ?? null,
          workCount: typeof d.work_count === 'number' ? d.work_count : null,
          subjects: Array.isArray(d.top_subjects) ? d.top_subjects.slice(0, 5) : [],
        }));

      this.cacheSet(cacheKey, results);
      return results;
    } catch (e) {
      this.logger.warn(`Error buscando autores: ${e.message}`);
      return [];
    }
  }

  /** Ficha completa de un autor: datos de Open Library + libros de Google Books. */
  async getAuthorDetail(name: string): Promise<AuthorDetail> {
    const clean = (name ?? '').trim();
    if (!clean) {
      return { name: '', books: [], booksCount: 0 };
    }

    const cacheKey = `detail:${clean.toLowerCase()}`;
    const cached = this.cacheGet<AuthorDetail>(cacheKey);
    if (cached) return cached;

    // 1) Libros del autor (Google Books, con fallback a Open Library dentro de searchBooks)
    const books = await this.searchService.searchBooks(`inauthor:"${clean}"`);

    // 2) Metadatos del autor en Open Library
    let summary: AuthorSummary = { name: clean };
    let bio: string | null = null;
    let deathDate: string | null = null;

    try {
      const matches = await this.searchAuthors(clean);
      // Preferimos coincidencia exacta de nombre; si no, el primero
      const best =
        matches.find(m => m.name.toLowerCase() === clean.toLowerCase()) ?? matches[0] ?? null;

      if (best) {
        summary = best;
        if (best.olid) {
          const res = await fetch(`https://openlibrary.org/authors/${best.olid}.json`, {
            headers: {
              'User-Agent': 'BuenasLecturas/1.0 (contacto@buenaslecturas.app)',
              Accept: 'application/json',
            },
          });
          if (res.ok) {
            const detail = (await res.json()) as any;
            // bio puede ser string o { type, value }
            if (typeof detail?.bio === 'string') bio = detail.bio;
            else if (detail?.bio?.value) bio = detail.bio.value;
            deathDate = detail?.death_date ?? null;
            const photoId = Array.isArray(detail?.photos) && detail.photos.length > 0 ? detail.photos[0] : null;
            if (photoId && photoId > 0) {
              summary = { ...summary, photoUrl: this.photoFromOlid(best.olid, photoId) };
            }
          }
        }
      }
    } catch (e) {
      this.logger.warn(`Error obteniendo detalle del autor: ${e.message}`);
    }

    // 3) Nota media aproximada a partir de los libros encontrados
    const rated = books.filter((b: any) => typeof b.averageRating === 'number' && b.averageRating > 0);
    const averageRating =
      rated.length > 0
        ? Number((rated.reduce((acc: number, b: any) => acc + b.averageRating, 0) / rated.length).toFixed(2))
        : null;

    const result: AuthorDetail = {
      ...summary,
      name: summary.name || clean,
      bio,
      deathDate,
      books,
      booksCount: books.length,
      averageRating,
    };

    this.cacheSet(cacheKey, result);
    return result;
  }

  /** Solo los libros de un autor (para paginar o refrescar sin recargar la bio). */
  async getAuthorBooks(name: string) {
    const clean = (name ?? '').trim();
    if (!clean) return [];
    return this.searchService.searchBooks(`inauthor:"${clean}"`);
  }
}
