import { Injectable, Logger } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom } from 'rxjs';

@Injectable()
export class SearchService {
  private readonly logger = new Logger(SearchService.name);

  constructor(
    private readonly httpService: HttpService,
    private readonly configService: ConfigService,
  ) {}

  private async fetchWithRetry(url: string, maxRetries = 2): Promise<Response | null> {
    for (let attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        const res = await fetch(url, { headers: { 'Accept': 'application/json' } });
        if (res.ok) return res;
        if (res.status === 503 && attempt < maxRetries) {
          const delay = 500 * (attempt + 1);
          this.logger.warn(`Google Books 503, reintentando en ${delay}ms (intento ${attempt + 1}/${maxRetries})...`);
          await new Promise(r => setTimeout(r, delay));
          continue;
        }
        this.logger.warn(`Google Books status: ${res.status}`);
        return null;
      } catch (error) {
        if (attempt < maxRetries) {
          await new Promise(r => setTimeout(r, 500 * (attempt + 1)));
          continue;
        }
        throw error;
      }
    }
    return null;
  }

  async searchBooks(query: string) {
    // 1. Intentar Google Books API (con reintentos para 503 intermitentes)
    try {
      const apiKey = this.configService.get<string>('GOOGLE_BOOKS_API_KEY');
      const url = `https://www.googleapis.com/books/v1/volumes?q=${encodeURIComponent(query)}&maxResults=20${apiKey ? `&key=${apiKey}` : ''}`;
      
      const res = await this.fetchWithRetry(url);
      if (res) {
        const data = await res.json() as any;
        if (data && data.items && data.items.length > 0) {
          return data.items.map((item: any) => ({
            googleId: item.id,
            title: item.volumeInfo?.title || 'Sin título',
            subtitle: item.volumeInfo?.subtitle,
            authors: item.volumeInfo?.authors || ['Autor desconocido'],
            description: item.volumeInfo?.description,
            isbn: item.volumeInfo?.industryIdentifiers?.find((i: any) => i.type === 'ISBN_13')?.identifier || 
                  item.volumeInfo?.industryIdentifiers?.find((i: any) => i.type === 'ISBN_10')?.identifier,
            thumbnail: item.volumeInfo?.imageLinks?.thumbnail || item.volumeInfo?.imageLinks?.smallThumbnail,
            publishedDate: item.volumeInfo?.publishedDate,
            averageRating: item.volumeInfo?.averageRating,
            pageCount: item.volumeInfo?.pageCount && item.volumeInfo.pageCount > 0 ? item.volumeInfo.pageCount : null,
            categories: item.volumeInfo?.categories,
            publisher: item.volumeInfo?.publisher,
            language: item.volumeInfo?.language,
            asin: null,
          }));
        }
      } else {
        this.logger.warn(`Google Books falló, consultando Open Library...`);
      }
    } catch (error) {
      this.logger.warn(`Error en Google Books: ${error.message}, consultando Open Library...`);
    }

    // 2. Fallback de alta disponibilidad con Open Library API
    try {
      const openLibUrl = `https://openlibrary.org/search.json?q=${encodeURIComponent(query)}&limit=20`;
      const res = await fetch(openLibUrl, {
        headers: {
          'User-Agent': 'BuenasLecturas/1.0 (contacto@buenaslecturas.app)',
          'Accept': 'application/json',
        },
      });

      if (res.ok) {
        const data = await res.json() as any;
        if (data && data.docs && data.docs.length > 0) {
          return data.docs.map((doc: any) => {
            const coverId = doc.cover_i;
            const thumbnail = coverId ? `https://covers.openlibrary.org/b/id/${coverId}-M.jpg` : null;
            const isbn = doc.isbn && doc.isbn.length > 0 ? doc.isbn[0] : null;

            return {
              googleId: doc.key?.replace('/works/', '') || `ol_${doc.cover_edition_key || Math.random()}`,
              title: doc.title || 'Sin título',
              subtitle: doc.subtitle,
              authors: doc.author_name || ['Autor desconocido'],
              description: doc.first_sentence ? doc.first_sentence[0] : (doc.subject ? `Temas: ${doc.subject.slice(0, 4).join(', ')}` : null),
              isbn: isbn,
              thumbnail: thumbnail,
              publishedDate: doc.first_publish_year?.toString(),
              averageRating: doc.ratings_average ? parseFloat(doc.ratings_average.toFixed(1)) : 4.5,
              pageCount: doc.number_of_pages_median > 0 ? doc.number_of_pages_median : null,
              categories: doc.subject ? doc.subject.slice(0, 3) : ['Literatura'],
              publisher: doc.publisher ? doc.publisher[0] : null,
              language: doc.language ? doc.language[0] : 'es',
              asin: null,
            };
          });
        }
      }
    } catch (error) {
      this.logger.error(`Error buscando libros en Open Library: ${error.message}`);
    }

    return [];
  }

  /**
   * Mapea un documento de Open Library (search.json o trending) al formato
   * de libro que usa la app.
   */
  private mapOpenLibraryDoc(doc: any) {
    const coverId = doc.cover_i ?? doc.cover_id;
    const thumbnail = coverId ? `https://covers.openlibrary.org/b/id/${coverId}-M.jpg` : null;
    const isbn = Array.isArray(doc.isbn) && doc.isbn.length > 0 ? doc.isbn[0] : null;

    return {
      googleId: doc.key?.replace('/works/', '') || `ol_${doc.cover_edition_key || Math.random()}`,
      title: doc.title || 'Sin título',
      subtitle: doc.subtitle,
      authors: doc.author_name || ['Autor desconocido'],
      description: Array.isArray(doc.first_sentence)
        ? doc.first_sentence[0]
        : (Array.isArray(doc.subject) ? `Temas: ${doc.subject.slice(0, 4).join(', ')}` : null),
      isbn,
      thumbnail,
      publishedDate: doc.first_publish_year?.toString(),
      averageRating: doc.ratings_average ? parseFloat(doc.ratings_average.toFixed(1)) : null,
      ratingsCount: doc.ratings_count ?? null,
      pageCount: doc.number_of_pages_median || null,
      categories: Array.isArray(doc.subject) ? doc.subject.slice(0, 3) : ['Literatura'],
      publisher: Array.isArray(doc.publisher) ? doc.publisher[0] : null,
      language: Array.isArray(doc.language) ? doc.language[0] : null,
      asin: null,
      // Señal de popularidad real (cuánta gente lo tiene en su estantería)
      readinglogCount: doc.readinglog_count ?? null,
      wantToReadCount: doc.want_to_read_count ?? null,
    };
  }

  /**
   * Completa `pageCount` en los libros que lleguen sin él, con una única
   * consulta a Open Library usando las claves de obra. Necesario porque el
   * endpoint `/trending` no devuelve `number_of_pages_median`.
   *
   * @param books   libros ya mapeados (se modifican in situ)
   * @param rawDocs documentos originales, para recuperar su `key`
   */
  private async enrichMissingPageCounts(books: any[], rawDocs: any[]) {
    // Índice de los que no tienen páginas, junto a su clave de obra
    const pending: { book: any; key: string }[] = [];
    books.forEach((b, i) => {
      if (b.pageCount) return;
      const key = rawDocs[i]?.key;
      if (typeof key === 'string' && key.startsWith('/works/')) {
        pending.push({ book: b, key });
      }
    });
    if (pending.length === 0) return;

    // Open Library admite un OR de claves en una sola búsqueda
    const keysQuery = pending.map(p => p.key).join(' OR ');
    const url =
      `https://openlibrary.org/search.json?q=key:(${encodeURIComponent(keysQuery)})` +
      `&fields=key,number_of_pages_median&limit=${pending.length}`;

    const data = await this.fetchOpenLibrary(url);
    if (!data?.docs?.length) return;

    const pagesByKey = new Map<string, number>();
    for (const doc of data.docs) {
      const n = doc?.number_of_pages_median;
      if (typeof doc?.key === 'string' && typeof n === 'number' && n > 0) {
        pagesByKey.set(doc.key, n);
      }
    }

    for (const { book, key } of pending) {
      const pages = pagesByKey.get(key);
      if (pages) book.pageCount = pages;
    }
  }

  private async fetchOpenLibrary(url: string): Promise<any | null> {
    try {
      const res = await fetch(url, {
        headers: {
          'User-Agent': 'BuenasLecturas/1.0 (contacto@buenaslecturas.app)',
          Accept: 'application/json',
        },
      });
      if (!res.ok) {
        this.logger.warn(`Open Library respondió ${res.status} para ${url}`);
        return null;
      }
      return await res.json();
    } catch (e) {
      this.logger.warn(`Error consultando Open Library: ${e.message}`);
      return null;
    }
  }

  /**
   * Tendencias literarias reales por región.
   *
   * A diferencia de una búsqueda de texto ("bestsellers 2026"), esto se apoya
   * en señales de popularidad de Open Library:
   *  - `/trending/{period}.json`: obras con más actividad reciente de lectores.
   *  - `search.json?sort=readinglog`: obras con más gente que las tiene en su
   *    estantería, filtrando por idioma para aproximar el mercado local.
   *
   * @param region 'ES' (literatura hispana) | 'GLOBAL' (todo el mundo)
   * @param period daily | weekly | monthly | yearly
   */
  async findTrending(
    region: 'ES' | 'GLOBAL' = 'ES',
    period: 'daily' | 'weekly' | 'monthly' | 'yearly' = 'weekly',
  ) {
    const limit = 24;

    if (region === 'GLOBAL') {
      return this.trendingGlobal(period, limit);
    }
    return this.trendingForES(period, limit);
  }

  /**
   * Tendencia mundial: ranking de Open Library sin filtrar por idioma ni país.
   * Refleja la actividad real de lectores de toda su comunidad.
   */
  private async trendingGlobal(period: string, limit: number) {
    const data = await this.fetchOpenLibrary(`https://openlibrary.org/trending/${period}.json?limit=60`);
    const works: any[] = data?.works ?? [];
    let mapped = works.map((w: any) => this.mapOpenLibraryDoc(w));

    if (mapped.length > 0) {
      mapped = mapped.slice(0, limit);
      // El endpoint /trending no devuelve number_of_pages_median, así que los
      // libros llegarían sin páginas. Lo completamos con una sola consulta.
      await this.enrichMissingPageCounts(mapped, works.slice(0, limit));
      return mapped;
    }

    // Red de seguridad: las obras con más lectores registrados, sin filtros
    const fallback = await this.fetchOpenLibrary(
      `https://openlibrary.org/search.json?q=*&sort=readinglog&limit=${limit}` +
        `&fields=key,title,subtitle,author_name,cover_i,first_publish_year,ratings_average,ratings_count,` +
        `number_of_pages_median,subject,publisher,language,isbn,readinglog_count,want_to_read_count`,
    );
    if (fallback?.docs?.length) {
      return fallback.docs.map((d: any) => this.mapOpenLibraryDoc(d));
    }
    return this.searchBooks('bestselling books');
  }

  /**
   * España / mercado en español.
   *
   * OJO: filtrar Open Library por `language:spa` NO sirve, porque marca como
   * "en español" cualquier obra con una traducción (el top sale lleno de
   * bestsellers anglosajones). Para aproximar el mercado español usamos
   * Google Books con `langRestrict=es` + `country=ES`, que devuelve el
   * catálogo que Google considera relevante en España, y ordenamos por las
   * señales de popularidad que trae cada volumen.
   */
  private async trendingForES(period: string, limit: number) {
    // Google Books NO sirve aquí: no tiene ranking de ventas ni popularidad,
    // es un buscador de texto. Consultar "libros más vendidos" devuelve obras
    // que contienen esas palabras (boletines de bibliotecas, libros de texto).
    // Además `langRestrict=es` está roto y devuelve siempre 0 resultados.
    //
    // Usamos Open Library, que sí expone popularidad real (`readinglog_count`
    // = cuántos lectores lo tienen en su estantería), acotando a literatura
    // del ámbito hispano para que no salga lo mismo que en EE. UU.
    const fields =
      'key,title,subtitle,author_name,cover_i,first_publish_year,ratings_average,ratings_count,' +
      'number_of_pages_median,subject,publisher,language,isbn,readinglog_count,want_to_read_count';

    const queries = [
      // Obras publicadas en España y en español: da autores españoles actuales
      'place%3ASpain+AND+language%3Aspa',
      // Clásicos y literatura hispana
      'subject%3A%22Spanish+literature%22',
      // Red de seguridad: cualquier obra disponible en español
      'language%3Aspa',
    ];

    const collected: any[] = [];
    const seen = new Set<string>();

    for (const q of queries) {
      const data = await this.fetchOpenLibrary(
        `https://openlibrary.org/search.json?q=${q}&sort=readinglog&limit=40&fields=${fields}`,
      );
      if (!data?.docs?.length) continue;

      for (const doc of data.docs) {
        // Nos quedamos solo con obras que tengan edición en español
        if (Array.isArray(doc.language) && !doc.language.includes('spa')) continue;

        const mapped = this.mapOpenLibraryDoc(doc);
        const key = (mapped.googleId || mapped.title || '').toString().toLowerCase();
        if (!key || seen.has(key)) continue;
        seen.add(key);
        collected.push(mapped);
      }

      // Con las dos primeras queries (las específicas de España) ya solemos
      // tener suficiente; solo caemos a la genérica si falta material.
      if (collected.length >= limit) break;
    }

    // Ordenamos por lectores reales
    collected.sort((a, b) => (b.readinglogCount ?? 0) - (a.readinglogCount ?? 0));

    if (collected.length > 0) return collected.slice(0, limit);
    return this.searchBooks('literatura española');
  }

  /**
   * Novedades publicadas en un año concreto.
   *
   * Usamos Open Library con `first_publish_year`, que es un dato real de
   * catálogo. Google Books NO sirve aquí: su `orderBy=newest` devuelve obras
   * de hace 20 años y sus búsquedas por texto ("nuevos libros 2026") traen
   * cualquier cosa que contenga esas palabras.
   *
   * @param year    año de publicación (por defecto, el actual)
   * @param region  'ES' (solo ediciones en español) | 'GLOBAL' (cualquier idioma)
   * @param sort    'readinglog' (más leídos) | 'new' (más recientes)
   * @param page    página 1..n
   * @param limit   resultados por página
   */
  async findNewReleases(
    year?: number,
    region: 'ES' | 'GLOBAL' = 'GLOBAL',
    sort: 'readinglog' | 'new' = 'readinglog',
    page = 1,
    limit = 24,
  ) {
    const y = year ?? new Date().getFullYear();
    const safePage = Math.max(1, page);
    const safeLimit = Math.min(Math.max(1, limit), 100);

    const fields =
      'key,title,subtitle,author_name,cover_i,first_publish_year,ratings_average,ratings_count,' +
      'number_of_pages_median,subject,publisher,language,isbn,readinglog_count,want_to_read_count';

    let q = `first_publish_year%3A${y}`;
    if (region === 'ES') {
      q += '+AND+language%3Aspa';
    }

    const url =
      `https://openlibrary.org/search.json?q=${q}&sort=${sort}` +
      `&page=${safePage}&limit=${safeLimit}&fields=${fields}`;

    const data = await this.fetchOpenLibrary(url);
    const docs: any[] = data?.docs ?? [];

    const books = docs
      // En modo ES nos aseguramos de que realmente haya edición en español
      .filter((d: any) => region !== 'ES' || !Array.isArray(d.language) || d.language.includes('spa'))
      .map((d: any) => this.mapOpenLibraryDoc(d));

    return {
      year: y,
      region,
      sort,
      page: safePage,
      limit: safeLimit,
      total: data?.numFound ?? books.length,
      hasMore: (data?.numFound ?? 0) > safePage * safeLimit,
      books,
    };
  }

  // Libros de la misma saga/serie que un libro dado
  async findBooksInSeries(bookRef: { title?: string; authors?: string[]; googleId?: string }) {
    const title = (bookRef.title || '').trim();
    if (!title) return [];

    // Heurística: nombre de la saga = texto antes de '(' o ':' o '#' o ' n° '
    // Ej. "The Fellowship of the Ring (The Lord of the Rings, #1)" → "The Lord of the Rings"
    let seriesName = '';
    const parenMatch = title.match(/\(([^)]+)\)/);
    if (parenMatch) {
      seriesName = parenMatch[1].split(',')[0].split('#')[0].trim();
    } else if (title.includes(':')) {
      seriesName = title.split(':')[0].trim();
    }
    const author = bookRef.authors && bookRef.authors.length > 0 ? bookRef.authors[0] : '';

    const tries: string[] = [];
    if (seriesName) {
      if (author) tries.push(`intitle:"${seriesName}"+inauthor:"${author}"`);
      tries.push(`intitle:"${seriesName}"`);
    }
    if (author) tries.push(`inauthor:"${author}"`);

    for (const q of tries) {
      const results = await this.searchBooks(q);
      const filtered = results.filter((b: any) => (b.googleId || '') !== bookRef.googleId);
      if (filtered.length >= 3) return filtered.slice(0, 15);
    }
    return [];
  }

  // Libros similares por categoría o autor, evitando el libro original
  async findSimilarBooks(googleId: string, category?: string, author?: string) {
    const queries: string[] = [];
    if (category && category.trim().length > 0) {
      queries.push(`subject:${category.trim()}`);
    }
    if (author && author.trim().length > 0) {
      queries.push(`inauthor:${author.trim()}`);
    }
    if (queries.length === 0) queries.push('bestsellers');

    for (const q of queries) {
      const results = await this.searchBooks(q);
      const filtered = results.filter((b: any) => (b.googleId || '') !== googleId).slice(0, 12);
      if (filtered.length > 0) return filtered;
    }
    return [];
  }
}
