import { ReadingStatus } from './entities/user-book.entity';

/** Lo mínimo de un libro de la biblioteca que necesitan las estadísticas. */
export interface StatsInput {
  status: ReadingStatus;
  rating: number | null;
  startedAt: Date | null;
  finishedAt: Date | null;
  book: {
    title: string;
    authors: string | null;
    categories: string | null;
    pageCount: number | null;
  } | null;
}

export interface ReadingStats {
  year: number;
  booksRead: number;
  pagesRead: number;
  /** Libros terminados sin número de páginas conocido (no suman páginas). */
  booksWithoutPages: number;
  averageRating: number | null;
  averagePagesPerBook: number | null;
  /** Media de días entre empezar y terminar, solo con ambas fechas. */
  averageDaysToFinish: number | null;
  byMonth: { month: number; books: number; pages: number }[];
  topGenres: { name: string; count: number }[];
  topAuthors: { name: string; count: number }[];
  /** Puntuaciones redondeadas a estrellas enteras: índice 0 = 1★. */
  ratingDistribution: number[];
  longestBook: { title: string; pages: number } | null;
  shortestBook: { title: string; pages: number } | null;
  /** Totales de toda la biblioteca, no solo del año. */
  statusCounts: { read: number; reading: number; wantToRead: number; abandoned: number };
  /** Años con algún libro terminado, del más reciente al más antiguo. */
  availableYears: number[];
}

/** Géneros demasiado genéricos para aportar algo en el ranking. */
const GENERIC_GENRES = new Set(['fiction', 'ficción', 'literatura', 'literature', 'general', 'novela']);

function top(counts: Map<string, { name: string; count: number }>, limit: number) {
  return [...counts.values()]
    .sort((a, b) => b.count - a.count || a.name.localeCompare(b.name))
    .slice(0, limit);
}

function bump(map: Map<string, { name: string; count: number }>, rawName: string) {
  const name = rawName.trim();
  if (!name) return;
  const key = name.toLowerCase();
  const entry = map.get(key) ?? { name, count: 0 };
  entry.count++;
  map.set(key, entry);
}

/** Calcula las estadísticas de lectura de un año a partir de la biblioteca. */
export function computeReadingStats(library: StatsInput[], year: number): ReadingStats {
  const finishedInYear = library.filter(
    ub => ub.status === ReadingStatus.READ && ub.finishedAt && new Date(ub.finishedAt).getUTCFullYear() === year,
  );

  const byMonth = Array.from({ length: 12 }, (_, i) => ({ month: i + 1, books: 0, pages: 0 }));
  const genres = new Map<string, { name: string; count: number }>();
  const authors = new Map<string, { name: string; count: number }>();
  const ratingDistribution = [0, 0, 0, 0, 0];

  let pagesRead = 0;
  let booksWithPages = 0;
  let ratingSum = 0;
  let ratingCount = 0;
  let daysSum = 0;
  let daysCount = 0;
  let longest: { title: string; pages: number } | null = null;
  let shortest: { title: string; pages: number } | null = null;

  for (const ub of finishedInYear) {
    const month = new Date(ub.finishedAt!).getUTCMonth();
    const pages = ub.book?.pageCount && ub.book.pageCount > 0 ? ub.book.pageCount : null;

    byMonth[month].books++;
    if (pages) {
      byMonth[month].pages += pages;
      pagesRead += pages;
      booksWithPages++;
      const title = ub.book!.title;
      if (!longest || pages > longest.pages) longest = { title, pages };
      if (!shortest || pages < shortest.pages) shortest = { title, pages };
    }

    if (ub.rating && ub.rating > 0) {
      ratingSum += ub.rating;
      ratingCount++;
      const stars = Math.min(5, Math.max(1, Math.round(ub.rating)));
      ratingDistribution[stars - 1]++;
    }

    if (ub.startedAt && ub.finishedAt) {
      const days = (new Date(ub.finishedAt).getTime() - new Date(ub.startedAt).getTime()) / 86_400_000;
      // Descartamos fechas incoherentes (terminado antes de empezar)
      if (days >= 0) {
        daysSum += days;
        daysCount++;
      }
    }

    for (const genre of (ub.book?.categories ?? '').split(',')) {
      if (!GENERIC_GENRES.has(genre.trim().toLowerCase())) bump(genres, genre);
    }
    for (const author of (ub.book?.authors ?? '').split(',')) {
      if (author.trim().toLowerCase() !== 'autor desconocido') bump(authors, author);
    }
  }

  const years = new Set<number>();
  const statusCounts = { read: 0, reading: 0, wantToRead: 0, abandoned: 0 };
  for (const ub of library) {
    if (ub.status === ReadingStatus.READ) {
      statusCounts.read++;
      if (ub.finishedAt) years.add(new Date(ub.finishedAt).getUTCFullYear());
    } else if (ub.status === ReadingStatus.READING) statusCounts.reading++;
    else if (ub.status === ReadingStatus.ABANDONED) statusCounts.abandoned++;
    else statusCounts.wantToRead++;
  }
  years.add(year);

  const round1 = (n: number) => Math.round(n * 10) / 10;

  return {
    year,
    booksRead: finishedInYear.length,
    pagesRead,
    booksWithoutPages: finishedInYear.length - booksWithPages,
    averageRating: ratingCount ? round1(ratingSum / ratingCount) : null,
    averagePagesPerBook: booksWithPages ? Math.round(pagesRead / booksWithPages) : null,
    averageDaysToFinish: daysCount ? Math.round(daysSum / daysCount) : null,
    byMonth,
    topGenres: top(genres, 6),
    topAuthors: top(authors, 5),
    ratingDistribution,
    longestBook: longest,
    shortestBook: shortest,
    statusCounts,
    availableYears: [...years].sort((a, b) => b - a),
  };
}
