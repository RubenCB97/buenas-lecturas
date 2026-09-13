import { ReadingStatus } from '../user-books/entities/user-book.entity';

/** Una fila del export de Goodreads ya interpretada. */
export interface GoodreadsEntry {
  goodreadsId: string;
  title: string;
  authors: string[];
  isbn: string | null;
  pageCount: number | null;
  publishedYear: string | null;
  publisher: string | null;
  status: ReadingStatus;
  rating: number | null;
  dateRead: Date | null;
  dateAdded: Date | null;
  review: string | null;
  notes: string | null;
  isFavorite: boolean;
  /** Estanterías personalizadas (sin las de estado ni favoritos). */
  shelves: string[];
}

/** Estanterías de Goodreads que en la app son estados de lectura. */
const STATUS_SHELVES: Record<string, ReadingStatus> = {
  read: ReadingStatus.READ,
  'currently-reading': ReadingStatus.READING,
  'to-read': ReadingStatus.WANT_TO_READ,
};

const FAVORITE_SHELVES = new Set(['favorites', 'favourites', 'favoritos', 'favorite', 'favourite']);

/** Columnas mínimas para reconocer un export de Goodreads. */
export const REQUIRED_GOODREADS_COLUMNS = ['Title', 'Exclusive Shelf'];

/**
 * Goodreads exporta los ISBN como fórmula de Excel para que no pierdan los
 * ceros a la izquierda: `="0439023483"` o `=""` si no hay.
 */
export function cleanGoodreadsIsbn(raw: string | undefined): string | null {
  const digits = String(raw ?? '').replace(/^="?|"$/g, '').replace(/[^0-9Xx]/g, '').toUpperCase();
  return digits.length === 10 || digits.length === 13 ? digits : null;
}

/** Fechas de Goodreads: "2023/05/14" (a veces "2023/05" o "2023"). */
export function parseGoodreadsDate(raw: string | undefined): Date | null {
  const m = String(raw ?? '').trim().match(/^(\d{4})(?:[/-](\d{1,2}))?(?:[/-](\d{1,2}))?$/);
  if (!m) return null;
  const [year, month = 1, day = 1] = [+m[1], m[2] ? +m[2] : 1, m[3] ? +m[3] : 1];
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  // Mediodía UTC para que la zona horaria no cambie el día
  const date = new Date(Date.UTC(year, month - 1, day, 12));
  return Number.isNaN(date.getTime()) ? null : date;
}

/** Las reseñas vienen con HTML básico (<br/>, <b>, <i>...). */
export function goodreadsHtmlToText(raw: string | undefined): string | null {
  const text = String(raw ?? '')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>\s*<p>/gi, '\n\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/\n{3,}/g, '\n\n')
    .trim();
  return text.length > 0 ? text : null;
}

/** "sci-fi-favorites" → "Sci fi favorites" */
export function prettifyShelfName(shelf: string): string {
  const text = shelf.replace(/[-_]+/g, ' ').trim();
  return text.charAt(0).toUpperCase() + text.slice(1);
}

/** Interpreta una fila. Devuelve `null` si no tiene título. */
export function mapGoodreadsRow(row: Record<string, string>): GoodreadsEntry | null {
  const title = (row['Title'] ?? '').trim();
  if (!title) return null;

  const authors = [row['Author'], ...(row['Additional Authors'] ?? '').split(',')]
    .map(a => (a ?? '').trim())
    .filter(Boolean);

  const exclusive = (row['Exclusive Shelf'] ?? '').trim().toLowerCase();
  const status = STATUS_SHELVES[exclusive] ?? ReadingStatus.WANT_TO_READ;

  const allShelves = (row['Bookshelves'] ?? '')
    .split(',')
    .map(s => s.trim().toLowerCase())
    .filter(Boolean);

  // Estanterías exclusivas no estándar (p. ej. "did-not-finish") se conservan
  // como estantería personalizada para no perder esa información.
  if (exclusive && !STATUS_SHELVES[exclusive] && !allShelves.includes(exclusive)) {
    allShelves.push(exclusive);
  }

  const isFavorite = allShelves.some(s => FAVORITE_SHELVES.has(s));
  const shelves = [
    ...new Set(allShelves.filter(s => !STATUS_SHELVES[s] && !FAVORITE_SHELVES.has(s))),
  ];

  const ratingNum = Number(row['My Rating']);
  const pagesNum = Number(row['Number of Pages']);

  return {
    goodreadsId: (row['Book Id'] ?? '').trim(),
    title,
    authors: authors.length ? authors : ['Autor desconocido'],
    isbn: cleanGoodreadsIsbn(row['ISBN13']) ?? cleanGoodreadsIsbn(row['ISBN']),
    pageCount: Number.isFinite(pagesNum) && pagesNum > 0 ? Math.round(pagesNum) : null,
    publishedYear: (row['Original Publication Year'] || row['Year Published'] || '').trim() || null,
    publisher: (row['Publisher'] ?? '').trim() || null,
    status,
    // Goodreads usa 0 para "sin puntuar"
    rating: Number.isFinite(ratingNum) && ratingNum >= 1 && ratingNum <= 5 ? ratingNum : null,
    dateRead: parseGoodreadsDate(row['Date Read']),
    dateAdded: parseGoodreadsDate(row['Date Added']),
    review: goodreadsHtmlToText(row['My Review']),
    notes: (row['Private Notes'] ?? '').trim() || null,
    isFavorite,
    shelves,
  };
}
