import { ReadingStatus } from '../user-books/entities/user-book.entity';
import { csvToObjects } from './csv.util';
import {
  cleanGoodreadsIsbn,
  goodreadsHtmlToText,
  mapGoodreadsRow,
  parseGoodreadsDate,
  prettifyShelfName,
} from './goodreads.mapper';

// Cabecera real del export de Goodreads
const HEADER =
  'Book Id,Title,Author,Author l-f,Additional Authors,ISBN,ISBN13,My Rating,Average Rating,Publisher,' +
  'Binding,Number of Pages,Year Published,Original Publication Year,Date Read,Date Added,Bookshelves,' +
  'Bookshelves with positions,Exclusive Shelf,My Review,Spoiler,Private Notes,Read Count,Owned Copies';

describe('Goodreads mapper', () => {
  it('interpreta una fila leída, puntuada, favorita y con reseña', () => {
    const csv =
      HEADER +
      '\n234225,"Dune (Dune, #1)",Frank Herbert,"Herbert, Frank",,="0441172717",="9780441172719",5,4.28,Ace,' +
      'Paperback,688,2005,1965,2021/03/02,2020/12/24,"favorites, sci-fi","favorites (#3), sci-fi (#1)",read,' +
      '"Una obra maestra.<br/><br/>La <b>releería</b> sin dudar, de verdad.",,Leído en vacaciones,1,0';
    const entry = mapGoodreadsRow(csvToObjects(csv)[0])!;

    expect(entry.goodreadsId).toBe('234225');
    expect(entry.title).toBe('Dune (Dune, #1)');
    expect(entry.authors).toEqual(['Frank Herbert']);
    expect(entry.isbn).toBe('9780441172719');
    expect(entry.pageCount).toBe(688);
    expect(entry.publishedYear).toBe('1965');
    expect(entry.status).toBe(ReadingStatus.READ);
    expect(entry.rating).toBe(5);
    expect(entry.dateRead?.toISOString().slice(0, 10)).toBe('2021-03-02');
    expect(entry.review).toBe('Una obra maestra.\n\nLa releería sin dudar, de verdad.');
    expect(entry.notes).toBe('Leído en vacaciones');
    expect(entry.isFavorite).toBe(true);
    expect(entry.shelves).toEqual(['sci-fi']);
  });

  it('trata 0 estrellas como sin puntuar y mapea las estanterías de estado', () => {
    const csv =
      HEADER +
      '\n1,Libro A,Autora,,"Otra, Tercera",="",="",0,0,,,,,,,2024/01/05,,,currently-reading,,,,0,0' +
      '\n2,Libro B,Autora,,,="",="",0,0,,,,,,,2024/01/05,,,to-read,,,,0,0' +
      '\n3,Libro C,Autora,,,="",="",0,0,,,,,,,2024/01/05,,,releer,,,,0,0' +
      '\n4,Libro D,Autora,,,="",="",0,0,,,,,,,2024/01/05,did-not-finish,,did-not-finish,,,,0,0';
    const [a, b, c, d] = csvToObjects(csv).map(mapGoodreadsRow);

    expect(a!.status).toBe(ReadingStatus.READING);
    expect(a!.rating).toBeNull();
    expect(a!.isbn).toBeNull();
    expect(a!.authors).toEqual(['Autora', 'Otra', 'Tercera']);
    expect(b!.status).toBe(ReadingStatus.WANT_TO_READ);
    // Una estantería exclusiva desconocida se conserva como personalizada
    expect(c!.status).toBe(ReadingStatus.WANT_TO_READ);
    expect(c!.shelves).toEqual(['releer']);
    // "did-not-finish" pasa a ser el estado "No lo terminé", no una estantería
    expect(d!.status).toBe(ReadingStatus.ABANDONED);
    expect(d!.shelves).toEqual([]);
  });

  it('ignora filas sin título', () => {
    expect(mapGoodreadsRow({ Title: '  ' })).toBeNull();
  });

  it('limpia ISBN con formato de fórmula', () => {
    expect(cleanGoodreadsIsbn('="0439023483"')).toBe('0439023483');
    expect(cleanGoodreadsIsbn('=""')).toBeNull();
    expect(cleanGoodreadsIsbn('="123"')).toBeNull();
  });

  it('parsea fechas completas y parciales', () => {
    expect(parseGoodreadsDate('2023/05/14')?.toISOString().slice(0, 10)).toBe('2023-05-14');
    expect(parseGoodreadsDate('2023')?.toISOString().slice(0, 10)).toBe('2023-01-01');
    expect(parseGoodreadsDate('')).toBeNull();
    expect(parseGoodreadsDate('2023/13/01')).toBeNull();
  });

  it('convierte HTML básico y nombres de estantería', () => {
    expect(goodreadsHtmlToText('a &amp; b<br>c')).toBe('a & b\nc');
    expect(goodreadsHtmlToText('<br/>')).toBeNull();
    expect(prettifyShelfName('sci-fi_favorites')).toBe('Sci fi favorites');
  });
});
