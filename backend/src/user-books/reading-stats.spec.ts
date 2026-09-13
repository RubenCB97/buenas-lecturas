import { ReadingStatus } from './entities/user-book.entity';
import { computeReadingStats, StatsInput } from './reading-stats';

const d = (iso: string) => new Date(`${iso}T12:00:00Z`);
const book = (title: string, authors: string, categories: string, pageCount: number | null) =>
  ({ title, authors, categories, pageCount });

const library: StatsInput[] = [
  { status: ReadingStatus.READ, rating: 4.5, startedAt: d('2026-01-01'), finishedAt: d('2026-01-11'),
    book: book('Dune', 'Frank Herbert', 'Science Fiction, Fiction', 688) },
  { status: ReadingStatus.READ, rating: 3, startedAt: d('2026-03-01'), finishedAt: d('2026-03-05'),
    book: book('Marina', 'Carlos Ruiz Zafón', 'Misterio', 300) },
  { status: ReadingStatus.READ, rating: null, startedAt: null, finishedAt: d('2026-03-20'),
    book: book('Dune Messiah', 'Frank Herbert', 'Science Fiction', null) },
  { status: ReadingStatus.READ, rating: 5, startedAt: null, finishedAt: d('2025-06-01'),
    book: book('Otro año', 'Alguien', 'Poesía', 100) },
  { status: ReadingStatus.READING, rating: null, startedAt: d('2026-09-01'), finishedAt: null, book: book('A', 'X', '', 200) },
  { status: ReadingStatus.ABANDONED, rating: 2, startedAt: null, finishedAt: null, book: book('B', 'Y', '', 200) },
  { status: ReadingStatus.WANT_TO_READ, rating: null, startedAt: null, finishedAt: null, book: book('C', 'Z', '', 200) },
];

describe('computeReadingStats', () => {
  const stats = computeReadingStats(library, 2026);

  it('cuenta solo los libros terminados ese año', () => {
    expect(stats.booksRead).toBe(3);
    expect(stats.pagesRead).toBe(988);
    expect(stats.booksWithoutPages).toBe(1);
    expect(stats.averagePagesPerBook).toBe(494);
  });

  it('reparte por meses', () => {
    expect(stats.byMonth[0]).toEqual({ month: 1, books: 1, pages: 688 });
    expect(stats.byMonth[2]).toEqual({ month: 3, books: 2, pages: 300 });
    expect(stats.byMonth[5].books).toBe(0);
  });

  it('calcula notas, ritmo y extremos', () => {
    expect(stats.averageRating).toBe(3.8); // (4.5 + 3) / 2
    expect(stats.ratingDistribution).toEqual([0, 0, 1, 0, 1]); // 4.5 → 5★
    expect(stats.averageDaysToFinish).toBe(7); // (10 + 4) / 2
    expect(stats.longestBook).toEqual({ title: 'Dune', pages: 688 });
    expect(stats.shortestBook).toEqual({ title: 'Marina', pages: 300 });
  });

  it('ordena géneros y autores ignorando los genéricos', () => {
    expect(stats.topGenres).toEqual([{ name: 'Science Fiction', count: 2 }, { name: 'Misterio', count: 1 }]);
    expect(stats.topAuthors[0]).toEqual({ name: 'Frank Herbert', count: 2 });
  });

  it('da totales de toda la biblioteca y los años disponibles', () => {
    expect(stats.statusCounts).toEqual({ read: 4, reading: 1, wantToRead: 1, abandoned: 1 });
    expect(stats.availableYears).toEqual([2026, 2025]);
  });

  it('funciona con un año sin lecturas', () => {
    const empty = computeReadingStats(library, 2020);
    expect(empty).toMatchObject({ booksRead: 0, pagesRead: 0, averageRating: null, averageDaysToFinish: null, longestBook: null });
    expect(empty.availableYears).toEqual([2026, 2025, 2020]);
  });
});
