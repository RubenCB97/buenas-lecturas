import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom } from 'rxjs';

/** Lanzamientos recientes y la ventana de meses que se usó para obtenerlos. */
export interface RecentReleases {
  books: any[];
  /** 1 = este mes, 3 = últimos 3 meses, 6 = últimos 6 meses. */
  windowMonths: number;
  /** Primer mes incluido, formato "YYYY-MM". */
  since: string;
}

@Injectable()
export class SearchService implements OnModuleInit {
  private readonly logger = new Logger(SearchService.name);

  /** Las tendencias cambian poco: 30 min de caché es de sobra. */
  private static readonly TRENDING_TTL_MS = 30 * 60 * 1000;
  /** Tiempo máximo por llamada a Open Library antes de abandonarla. */
  private static readonly OPEN_LIBRARY_TIMEOUT_MS = 10_000;

  private readonly trendingCache = new Map<string, { books: any[]; fetchedAt: number }>();
  private readonly trendingInFlight = new Map<string, Promise<any[]>>();

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
      const openLibQuery = SearchService.toOpenLibraryQuery(query);
      const openLibUrl = `https://openlibrary.org/search.json?q=${encodeURIComponent(openLibQuery)}&limit=20`;
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
   * Traduce la sintaxis de búsqueda de Google Books a la de Open Library.
   *
   * El fallback a Open Library recibía tal cual consultas como
   * `inauthor:"Frank Herbert"`, que Open Library no entiende y devuelven 0
   * resultados; así, cuando Google Books daba 503, autores, sagas y
   * recomendaciones se quedaban vacíos.
   */
  static toOpenLibraryQuery(query: string): string {
    return query
      .replace(/\binauthor:/gi, 'author:')
      .replace(/\bintitle:/gi, 'title:')
      .replace(/\bisbn:/gi, 'isbn:')
      .replace(/\binpublisher:/gi, 'publisher:')
      .replace(/\+/g, ' ');
  }

  /**
   * Temas de Open Library de una obra, buscándola por título y autor.
   * Sirve para recomendar parecidos a libros que no traen categoría.
   */
  async findSubjectsFor(title: string, author?: string): Promise<string[]> {
    if (!title?.trim()) return [];
    let q = `title:"${title.trim()}"`;
    if (author?.trim()) q += ` author:"${author.trim()}"`;
    const data = await this.fetchOpenLibrary(
      `https://openlibrary.org/search.json?q=${encodeURIComponent(q)}&limit=3&fields=key,title,subject`,
    );

    const titleWords = title
      .toLowerCase()
      .split(/[^a-záéíóúñü0-9]+/)
      .filter(w => w.length > 3);
    const genre = /fiction|ficci|fantas|romance|romant|thriller|mystery|misterio|horror|terror|histor|poet|poes|biograf|memoir|crime|crimen|detective|adventure|aventura|dystop|distop|suspense|humor|drama|novel/i;

    // puntuación = veces que aparece + bonus si es un género
    const scores = new Map<string, { label: string; score: number }>();
    for (const doc of data?.docs ?? []) {
      for (const subj of (doc.subject ?? []).slice(0, 20)) {
        const label = String(subj).trim();
        const lower = label.toLowerCase();
        if (!label || label.length > 40) continue;
        // Etiquetas internas (nyt:..., award:...) y genéricas que no ayudan
        if (/[:=]/.test(label)) continue;
        if (/accessible book|protected daisy|in library|large type|open library|bestseller|reviewed|translations/i.test(label)) continue;
        // Lugares y personajes ficticios: apuntan a la propia saga
        if (/\((imaginary|fictitious)/i.test(label)) continue;
        // Temas que contienen el título (p. ej. "Dune (Imaginary place)")
        if (titleWords.some(w => lower.includes(w))) continue;
        if (/^(fiction|ficción|literature|literatura)$/i.test(label)) continue;

        const key = lower.replace(/[-\s]+/g, ' ');
        const entry = scores.get(key) ?? { label, score: 0 };
        entry.score += 1 + (genre.test(label) ? 2 : 0);
        scores.set(key, entry);
      }
    }
    return [...scores.values()].sort((a, b) => b.score - a.score).map(e => e.label).slice(0, 3);
  }

  /** Obras más leídas de un tema en Open Library. */
  async findPopularBySubject(subject: string, limit = 20): Promise<any[]> {
    if (!subject?.trim()) return [];
    const fields =
      'key,title,subtitle,author_name,cover_i,first_publish_year,ratings_average,ratings_count,' +
      'number_of_pages_median,subject,publisher,language,isbn,readinglog_count';
    // `subject_key` busca el tema exacto. Con `subject:"…"` Open Library hace
    // una coincidencia difusa y para "Science fiction" devolvía Crepúsculo o
    // Harry Potter, que solo comparten la palabra "fiction".
    const key = subject
      .trim()
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/[^a-z0-9]+/g, '_')
      .replace(/^_|_$/g, '');
    if (!key) return [];
    const data = await this.fetchOpenLibrary(
      `https://openlibrary.org/search.json?q=subject_key%3A${encodeURIComponent(key)}` +
        `&sort=readinglog&limit=${limit}&fields=${fields}`,
    );
    return (data?.docs ?? []).map((d: any) => this.mapOpenLibraryDoc(d));
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
        // Sin esto una consulta colgada bloquea la respuesta indefinidamente
        signal: AbortSignal.timeout(SearchService.OPEN_LIBRARY_TIMEOUT_MS),
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
    const key = `${region}:${period}`;
    const cached = this.trendingCache.get(key);
    const now = Date.now();

    if (cached) {
      // Stale-while-revalidate: si está caducado devolvemos igualmente lo que
      // hay y refrescamos en segundo plano. Open Library tarda 3-5 s por
      // consulta y no queremos que el usuario espere al cambiar de pestaña.
      if (now - cached.fetchedAt > SearchService.TRENDING_TTL_MS) {
        void this.refreshTrending(region, period);
      }
      return cached.books;
    }

    // Primera vez: esperamos al cálculo (compartido si ya hay uno en curso)
    return this.refreshTrending(region, period);
  }

  /**
   * Recalcula las tendencias y actualiza la caché. Si ya hay un cálculo en
   * marcha para la misma clave, se reutiliza en vez de lanzar otro.
   */
  private refreshTrending(region: 'ES' | 'GLOBAL', period: 'daily' | 'weekly' | 'monthly' | 'yearly'): Promise<any[]> {
    const key = `${region}:${period}`;
    const running = this.trendingInFlight.get(key);
    if (running) return running;

    const limit = 24;
    const task = (region === 'GLOBAL' ? this.trendingGlobal(period, limit) : this.trendingForES(period, limit))
      .then(books => {
        // No machacamos una caché buena con un resultado vacío por un fallo puntual
        if (books.length > 0 || !this.trendingCache.has(key)) {
          this.trendingCache.set(key, { books, fetchedAt: Date.now() });
        }
        return books.length > 0 ? books : (this.trendingCache.get(key)?.books ?? []);
      })
      .catch(e => {
        this.logger.warn(`Error calculando tendencias ${key}: ${e.message}`);
        return this.trendingCache.get(key)?.books ?? [];
      })
      .finally(() => this.trendingInFlight.delete(key));

    this.trendingInFlight.set(key, task);
    return task;
  }

  /** Precalcula las dos regiones al arrancar y las refresca periódicamente. */
  onModuleInit() {
    const warm = () => {
      void this.refreshTrending('ES', 'weekly');
      void this.refreshTrending('GLOBAL', 'weekly');
      void this.refreshRecent('ES');
      void this.refreshRecent('GLOBAL');
    };
    warm();
    const timer = setInterval(warm, SearchService.TRENDING_TTL_MS);
    // No impedimos que el proceso termine por este temporizador
    timer.unref?.();
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

    // Las tres consultas en paralelo: en serie sumaban 12-15 s.
    const responses = await Promise.all(
      queries.map(q =>
        this.fetchOpenLibrary(`https://openlibrary.org/search.json?q=${q}&sort=readinglog&limit=40&fields=${fields}`),
      ),
    );

    // Se procesan en orden de prioridad (primero lo específico de España)
    for (const data of responses) {
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

  // ---------------------------------------------------------------------------
  // Lanzamientos recientes (pestaña Descubrir)
  // ---------------------------------------------------------------------------

  private static readonly RECENT_TTL_MS = 6 * 60 * 60 * 1000;
  private readonly recentCache = new Map<string, { value: RecentReleases; fetchedAt: number }>();
  private readonly recentInFlight = new Map<string, Promise<RecentReleases>>();

  private static readonly MONTHS: Record<string, number> = {
    january: 1, february: 2, march: 3, april: 4, may: 5, june: 6, july: 7, august: 8,
    september: 9, october: 10, november: 11, december: 12,
    jan: 1, feb: 2, mar: 3, apr: 4, jun: 6, jul: 7, aug: 8, sep: 9, sept: 9, oct: 10, nov: 11, dec: 12,
    enero: 1, febrero: 2, marzo: 3, abril: 4, mayo: 5, junio: 6, julio: 7, agosto: 8,
    septiembre: 9, setiembre: 9, octubre: 10, noviembre: 11, diciembre: 12,
  };

  /**
   * Meses (formato año*12+mes) en los que Open Library dice que se publicó
   * alguna edición. Las fechas llegan en formatos muy variados:
   * "2026-09-03", "September 8, 2026", "03 September 2026", "13 Oct 2026".
   */
  static parsePublishMonths(publishDates: unknown): Set<number> {
    const out = new Set<number>();
    if (!Array.isArray(publishDates)) return out;
    for (const raw of publishDates) {
      if (typeof raw !== 'string') continue;
      const s = raw.toLowerCase();
      const iso = s.match(/\b(\d{4})-(\d{1,2})\b/);
      if (iso) {
        const m = +iso[2];
        if (m >= 1 && m <= 12) out.add(+iso[1] * 12 + m);
        continue;
      }
      const year = s.match(/\b(\d{4})\b/);
      if (!year) continue;
      for (const word of s.match(/[a-záéíóú]+/g) ?? []) {
        const m = SearchService.MONTHS[word];
        if (m) {
          out.add(+year[1] * 12 + m);
          break;
        }
      }
    }
    return out;
  }

  /**
   * Libros publicados recientemente, ordenados por lectores.
   *
   * Open Library cataloga con retraso lo más reciente (de los 1.000 libros de
   * 2026 más leídos, a mediados de septiembre solo 3 eran de ese mes), y Google
   * Books tampoco sirve (`orderBy=newest` devuelve obras de hace 20 años). Por
   * eso probamos ventanas crecientes —este mes, 3 meses, 6 meses— y devolvemos
   * la primera con suficiente material, indicando cuál se usó para que la app
   * titule la sección con honestidad.
   */
  async findRecentReleases(region: 'ES' | 'GLOBAL' = 'GLOBAL'): Promise<RecentReleases> {
    const key = `recent:${region}`;
    const cached = this.recentCache.get(key);
    if (cached) {
      if (Date.now() - cached.fetchedAt > SearchService.RECENT_TTL_MS) void this.refreshRecent(region);
      return cached.value;
    }
    return this.refreshRecent(region);
  }

  private refreshRecent(region: 'ES' | 'GLOBAL'): Promise<RecentReleases> {
    const key = `recent:${region}`;
    const running = this.recentInFlight.get(key);
    if (running) return running;

    const task = this.computeRecentReleases(region)
      .then(value => {
        if (value.books.length > 0 || !this.recentCache.has(key)) {
          this.recentCache.set(key, { value, fetchedAt: Date.now() });
        }
        return value.books.length > 0 ? value : (this.recentCache.get(key)?.value ?? value);
      })
      .catch(e => {
        this.logger.warn(`Error calculando lanzamientos recientes ${key}: ${e.message}`);
        return this.recentCache.get(key)?.value ?? { books: [], windowMonths: 0, since: '' };
      })
      .finally(() => this.recentInFlight.delete(key));

    this.recentInFlight.set(key, task);
    return task;
  }

  private async computeRecentReleases(region: 'ES' | 'GLOBAL'): Promise<RecentReleases> {
    const now = new Date();
    const current = now.getFullYear() * 12 + (now.getMonth() + 1);
    const windows = [1, 3, 6];
    const minBooks = 8;
    const limit = 24;

    // Años que cubre la ventana más amplia (en enero-junio incluye el anterior)
    const oldest = current - (windows[windows.length - 1] - 1);
    const years = new Set([Math.floor((oldest - 1) / 12), Math.floor((current - 1) / 12)]);

    const fields =
      'key,title,subtitle,author_name,cover_i,first_publish_year,ratings_average,ratings_count,' +
      'number_of_pages_median,subject,publisher,language,isbn,readinglog_count,want_to_read_count,publish_date';

    const responses = await Promise.all(
      [...years].map(y => {
        let q = `first_publish_year%3A${y}`;
        if (region === 'ES') q += '+AND+language%3Aspa';
        return this.fetchOpenLibrary(
          `https://openlibrary.org/search.json?q=${q}&sort=readinglog&limit=1000&fields=${fields}`,
        );
      }),
    );

    // Cada libro con el mes más reciente en que se publicó (dentro de lo actual)
    const candidates: { doc: any; month: number }[] = [];
    const seen = new Set<string>();
    for (const data of responses) {
      for (const doc of data?.docs ?? []) {
        const months = [...SearchService.parsePublishMonths(doc.publish_date)].filter(m => m <= current);
        if (months.length === 0) continue;
        const key = (doc.key ?? doc.title ?? '').toString();
        if (!key || seen.has(key)) continue;
        seen.add(key);
        candidates.push({ doc, month: Math.max(...months) });
      }
    }

    const toResult = (windowMonths: number): RecentReleases => {
      const from = current - (windowMonths - 1);
      const books = candidates
        .filter(c => c.month >= from)
        // Priorizamos los que tienen portada y luego por lectores
        .sort((a, b) =>
          Number(!!b.doc.cover_i) - Number(!!a.doc.cover_i) ||
          (b.doc.readinglog_count ?? 0) - (a.doc.readinglog_count ?? 0))
        .slice(0, limit)
        .map(c => this.mapOpenLibraryDoc(c.doc));
      const fromYear = Math.floor((from - 1) / 12);
      const fromMonth = from - fromYear * 12;
      return { books, windowMonths, since: `${fromYear}-${String(fromMonth).padStart(2, '0')}` };
    };

    for (const w of windows) {
      const result = toResult(w);
      if (result.books.length >= minBooks) return result;
    }
    return toResult(windows[windows.length - 1]);
  }

  // ---------------------------------------------------------------------------
  // Búsqueda por ISBN (escáner de código de barras)
  // ---------------------------------------------------------------------------

  private readonly isbnCache = new Map<string, { value: any | null; fetchedAt: number }>();

  /**
   * Limpia un ISBN leído o tecleado y comprueba su dígito de control.
   * Acepta ISBN-10 e ISBN-13 (EAN 978/979). Devuelve `null` si no es válido.
   */
  static normalizeIsbn(raw: string): string | null {
    const clean = String(raw ?? '').toUpperCase().replace(/[^0-9X]/g, '');

    if (/^\d{13}$/.test(clean)) {
      if (!clean.startsWith('978') && !clean.startsWith('979')) return null;
      const sum = clean
        .slice(0, 12)
        .split('')
        .reduce((acc, d, i) => acc + Number(d) * (i % 2 === 0 ? 1 : 3), 0);
      const check = (10 - (sum % 10)) % 10;
      return check === Number(clean[12]) ? clean : null;
    }

    if (/^\d{9}[\dX]$/.test(clean)) {
      const sum = clean
        .split('')
        .reduce((acc, d, i) => acc + (d === 'X' ? 10 : Number(d)) * (10 - i), 0);
      return sum % 11 === 0 ? clean : null;
    }

    return null;
  }

  /**
   * Busca un libro por ISBN combinando Google Books y Open Library: Google
   * suele tener mejor descripción, pero no encuentra muchos libros españoles
   * y a veces da 0 páginas o ninguna portada, que Open Library sí tiene.
   */
  async lookupByIsbn(isbn: string): Promise<any | null> {
    const cached = this.isbnCache.get(isbn);
    if (cached && Date.now() - cached.fetchedAt < 24 * 60 * 60 * 1000) return cached.value;

    const apiKey = this.configService.get<string>('GOOGLE_BOOKS_API_KEY');
    const fields =
      'key,title,subtitle,author_name,cover_i,first_publish_year,ratings_average,ratings_count,' +
      'number_of_pages_median,subject,publisher,language,isbn';

    const [googleRes, olData] = await Promise.all([
      this.fetchWithRetry(
        `https://www.googleapis.com/books/v1/volumes?q=isbn:${isbn}${apiKey ? `&key=${apiKey}` : ''}`,
        1,
      ).catch(() => null),
      this.fetchOpenLibrary(
        `https://openlibrary.org/search.json?q=isbn%3A${isbn}&limit=1&fields=${fields}`,
      ),
    ]);

    let google: any = null;
    if (googleRes) {
      try {
        const data: any = await googleRes.json();
        const item = data?.items?.[0];
        if (item) {
          const v = item.volumeInfo ?? {};
          google = {
            googleId: item.id,
            title: v.title,
            subtitle: v.subtitle,
            authors: v.authors,
            description: v.description,
            thumbnail: v.imageLinks?.thumbnail || v.imageLinks?.smallThumbnail || null,
            publishedDate: v.publishedDate,
            averageRating: v.averageRating ?? null,
            ratingsCount: v.ratingsCount ?? null,
            pageCount: v.pageCount > 0 ? v.pageCount : null,
            categories: v.categories,
            publisher: v.publisher,
            language: v.language,
          };
        }
      } catch {
        google = null;
      }
    }

    const olDoc = olData?.docs?.[0];
    const openLibrary = olDoc ? this.mapOpenLibraryDoc(olDoc) : null;

    if (!google && !openLibrary) {
      this.isbnCache.set(isbn, { value: null, fetchedAt: Date.now() });
      return null;
    }

    // Google como base; Open Library rellena lo que falte
    const base = google ?? openLibrary;
    const fill = google ? openLibrary : null;
    const book = {
      ...base,
      isbn,
      authors: base.authors?.length ? base.authors : (fill?.authors ?? ['Autor desconocido']),
      pageCount: base.pageCount || fill?.pageCount || null,
      thumbnail: base.thumbnail || fill?.thumbnail || null,
      publisher: base.publisher || fill?.publisher || null,
      categories: base.categories?.length ? base.categories : (fill?.categories ?? []),
      description: base.description || fill?.description || null,
    };

    this.isbnCache.set(isbn, { value: book, fetchedAt: Date.now() });
    return book;
  }

  /**
   * Busca un libro por el id de su catálogo de origen, para abrir los enlaces
   * compartidos de libros que nunca se guardaron en la base de datos:
   * obras de Open Library ("OL123W") o volúmenes de Google Books.
   */
  async lookupByExternalId(id: string): Promise<any | null> {
    const clean = (id ?? '').trim();
    if (!clean || clean.length > 64 || !/^[\w-]+$/.test(clean)) return null;

    if (/^OL\d+W$/.test(clean)) {
      const fields =
        'key,title,subtitle,author_name,cover_i,first_publish_year,ratings_average,ratings_count,' +
        'number_of_pages_median,subject,publisher,language,isbn';
      const data = await this.fetchOpenLibrary(
        `https://openlibrary.org/search.json?q=key%3A%2Fworks%2F${clean}&limit=1&fields=${fields}`,
      );
      const doc = data?.docs?.[0];
      return doc ? this.mapOpenLibraryDoc(doc) : null;
    }

    const apiKey = this.configService.get<string>('GOOGLE_BOOKS_API_KEY');
    const res = await this.fetchWithRetry(
      `https://www.googleapis.com/books/v1/volumes/${encodeURIComponent(clean)}${apiKey ? `?key=${apiKey}` : ''}`,
      1,
    ).catch(() => null);
    if (!res) return null;
    try {
      const item: any = await res.json();
      const v = item?.volumeInfo;
      if (!v?.title) return null;
      return {
        googleId: item.id,
        title: v.title,
        subtitle: v.subtitle,
        authors: v.authors ?? ['Autor desconocido'],
        description: v.description,
        isbn:
          v.industryIdentifiers?.find((i: any) => i.type === 'ISBN_13')?.identifier ||
          v.industryIdentifiers?.find((i: any) => i.type === 'ISBN_10')?.identifier,
        thumbnail: v.imageLinks?.thumbnail || v.imageLinks?.smallThumbnail || null,
        publishedDate: v.publishedDate,
        averageRating: v.averageRating ?? null,
        ratingsCount: v.ratingsCount ?? null,
        pageCount: v.pageCount > 0 ? v.pageCount : null,
        categories: v.categories,
        publisher: v.publisher,
        language: v.language,
      };
    } catch {
      return null;
    }
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
