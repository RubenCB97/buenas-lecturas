import { ReadingStatus } from '../user-books/entities/user-book.entity';

/** Datos de un libro de la biblioteca para exportar. */
export interface ExportEntry {
  googleId: string | null;
  title: string;
  authors: string[];
  isbn: string | null;
  rating: number | null;
  averageRating: number | null;
  publisher: string | null;
  pageCount: number | null;
  publishedDate: string | null;
  finishedAt: Date | null;
  addedAt: Date | null;
  status: ReadingStatus;
  isFavorite: boolean;
  shelves: string[];
  review: string | null;
  notes: string | null;
}

/** Cabecera idéntica a la del "Export Library" de Goodreads. */
export const GOODREADS_HEADER = [
  'Book Id', 'Title', 'Author', 'Author l-f', 'Additional Authors', 'ISBN', 'ISBN13', 'My Rating',
  'Average Rating', 'Publisher', 'Binding', 'Number of Pages', 'Year Published', 'Original Publication Year',
  'Date Read', 'Date Added', 'Bookshelves', 'Bookshelves with positions', 'Exclusive Shelf', 'My Review',
  'Spoiler', 'Private Notes', 'Read Count', 'Owned Copies',
];

const EXCLUSIVE_SHELF: Record<ReadingStatus, string> = {
  [ReadingStatus.READ]: 'read',
  [ReadingStatus.READING]: 'currently-reading',
  [ReadingStatus.WANT_TO_READ]: 'to-read',
  [ReadingStatus.ABANDONED]: 'did-not-finish',
};

/** Escapa un campo según RFC 4180. */
export function csvField(value: unknown): string {
  const text = value === null || value === undefined ? '' : String(value);
  return /[",\r\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

/** "Sci fi favoritos" → "sci-fi-favoritos" (formato de estantería de Goodreads). */
export function shelfSlug(name: string): string {
  return name
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
}

function goodreadsDate(date: Date | null): string {
  if (!date) return '';
  const d = new Date(date);
  if (Number.isNaN(d.getTime())) return '';
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getUTCFullYear()}/${pad(d.getUTCMonth() + 1)}/${pad(d.getUTCDate())}`;
}

/** Goodreads escribe los ISBN como fórmula para conservar ceros a la izquierda. */
function formulaIsbn(isbn: string | null, length: 10 | 13): string {
  return isbn && isbn.length === length ? `="${isbn}"` : '=""';
}

/** "Frank Herbert" → "Herbert, Frank" */
function lastFirst(author: string): string {
  const parts = author.trim().split(/\s+/);
  if (parts.length < 2) return author.trim();
  const last = parts.pop();
  return `${last}, ${parts.join(' ')}`;
}

/**
 * Genera un CSV con el mismo formato que exporta Goodreads, para usarlo como
 * copia de seguridad, volver a importarlo aquí o subirlo a Goodreads.
 *
 * Goodreads solo admite puntuaciones enteras: las medias estrellas se
 * redondean hacia arriba (4,5 → 5).
 */
export function buildGoodreadsCsv(entries: ExportEntry[]): string {
  const lines = [GOODREADS_HEADER.join(',')];

  for (const e of entries) {
    const exclusive = EXCLUSIVE_SHELF[e.status] ?? 'to-read';
    const shelves = [
      ...(e.isFavorite ? ['favorites'] : []),
      ...e.shelves.map(shelfSlug).filter(Boolean),
    ];
    const bookshelves = [...new Set([...shelves, exclusive])];
    const year = (e.publishedDate ?? '').match(/\d{4}/)?.[0] ?? '';
    const [author = '', ...additional] = e.authors;
    const goodreadsId = e.googleId?.startsWith('gr_') && !e.googleId.startsWith('gr_custom_') ? e.googleId.slice(3) : '';

    const row = [
      goodreadsId,
      e.title,
      author,
      author ? lastFirst(author) : '',
      additional.join(', '),
      formulaIsbn(e.isbn, 10),
      formulaIsbn(e.isbn, 13),
      e.rating ? Math.round(e.rating) : 0,
      e.averageRating ?? '',
      e.publisher ?? '',
      '',
      e.pageCount ?? '',
      year,
      year,
      goodreadsDate(e.finishedAt),
      goodreadsDate(e.addedAt),
      bookshelves.join(', '),
      bookshelves.map((s, i) => `${s} (#${i + 1})`).join(', '),
      exclusive,
      // Goodreads guarda las reseñas en HTML
      (e.review ?? '').replace(/\r?\n/g, '<br/>'),
      '',
      e.notes ?? '',
      e.status === ReadingStatus.READ ? 1 : 0,
      0,
    ];
    lines.push(row.map(csvField).join(','));
  }

  return lines.join('\n') + '\n';
}
