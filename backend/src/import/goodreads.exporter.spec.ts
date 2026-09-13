import { ReadingStatus } from '../user-books/entities/user-book.entity';
import { csvToObjects } from './csv.util';
import { buildGoodreadsCsv, csvField, ExportEntry, shelfSlug } from './goodreads.exporter';
import { mapGoodreadsRow } from './goodreads.mapper';

const base: ExportEntry = {
  googleId: 'gr_234225',
  title: 'Dune (Dune, #1)',
  authors: ['Frank Herbert', 'Brian Herbert'],
  isbn: '9780441172719',
  rating: 4.5,
  averageRating: 4.28,
  publisher: 'Ace',
  pageCount: 688,
  publishedDate: '1965-08-01',
  finishedAt: new Date(Date.UTC(2021, 2, 2, 12)),
  addedAt: new Date(Date.UTC(2020, 11, 24, 12)),
  status: ReadingStatus.READ,
  isFavorite: true,
  shelves: ['Ciencia ficción'],
  review: 'Genial, "de verdad".\nLo releería.',
  notes: 'Nota privada',
};

describe('Goodreads exporter', () => {
  it('escapa campos con comas, comillas y saltos de línea', () => {
    expect(csvField('a,b')).toBe('"a,b"');
    expect(csvField('di "hola"')).toBe('"di ""hola"""');
    expect(csvField(null)).toBe('');
    expect(csvField(5)).toBe('5');
  });

  it('convierte nombres de estantería al formato de Goodreads', () => {
    expect(shelfSlug('Ciencia ficción')).toBe('ciencia-ficcion');
  });

  it('se puede volver a importar sin perder datos', () => {
    const csv = buildGoodreadsCsv([
      base,
      { ...base, googleId: 'XYZ', title: 'Marina', authors: ['Carlos Ruiz Zafón'], isbn: null, rating: null,
        status: ReadingStatus.ABANDONED, isFavorite: false, shelves: [], review: null, notes: null, finishedAt: null },
    ]);
    const [dune, marina] = csvToObjects(csv).map(mapGoodreadsRow);

    expect(dune).toMatchObject({
      goodreadsId: '234225',
      title: 'Dune (Dune, #1)',
      authors: ['Frank Herbert', 'Brian Herbert'],
      isbn: '9780441172719',
      rating: 5, // Goodreads solo admite enteros
      pageCount: 688,
      publishedYear: '1965',
      status: ReadingStatus.READ,
      isFavorite: true,
      shelves: ['ciencia-ficcion'],
      review: 'Genial, "de verdad".\nLo releería.',
      notes: 'Nota privada',
    });
    expect(dune!.dateRead?.toISOString().slice(0, 10)).toBe('2021-03-02');
    expect(dune!.dateAdded?.toISOString().slice(0, 10)).toBe('2020-12-24');

    expect(marina).toMatchObject({ goodreadsId: '', status: ReadingStatus.ABANDONED, isbn: null, rating: null, shelves: [] });
  });
});
