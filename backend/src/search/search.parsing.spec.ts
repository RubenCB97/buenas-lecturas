import { SearchService } from './search.service';

const month = (y: number, m: number) => y * 12 + m;

describe('SearchService.parsePublishMonths', () => {
  it('entiende los formatos de fecha de Open Library', () => {
    const result = SearchService.parsePublishMonths([
      '2026-09-03',
      'September 8, 2026',
      '03 September 2026',
      '13 Oct 2026',
      'marzo de 2026',
    ]);
    expect([...result].sort()).toEqual([month(2026, 3), month(2026, 9), month(2026, 10)].sort());
  });

  it('ignora fechas sin mes o que no son texto', () => {
    expect(SearchService.parsePublishMonths(['2026', 42, null]).size).toBe(0);
    expect(SearchService.parsePublishMonths(undefined).size).toBe(0);
  });

  it('descarta meses imposibles en formato ISO', () => {
    expect(SearchService.parsePublishMonths(['2026-27-01']).size).toBe(0);
  });
});

describe('SearchService.toOpenLibraryQuery', () => {
  it('traduce la sintaxis de Google Books a la de Open Library', () => {
    expect(SearchService.toOpenLibraryQuery('inauthor:"Frank Herbert"+intitle:Dune'))
      .toBe('author:"Frank Herbert" title:Dune');
  });

  it('deja intactas las consultas de texto libre', () => {
    expect(SearchService.toOpenLibraryQuery('la sombra del viento')).toBe('la sombra del viento');
  });
});

describe('SearchService.normalizeIsbn', () => {
  it('acepta ISBN-13 e ISBN-10 válidos, con guiones o espacios', () => {
    expect(SearchService.normalizeIsbn('978-0-441-17271-9')).toBe('9780441172719');
    expect(SearchService.normalizeIsbn('0 441 17271 7')).toBe('0441172717');
    expect(SearchService.normalizeIsbn('080442957X')).toBe('080442957X');
  });

  it('rechaza dígito de control incorrecto o EAN que no es de libro', () => {
    expect(SearchService.normalizeIsbn('9780441172718')).toBeNull();
    expect(SearchService.normalizeIsbn('8410000000001')).toBeNull();
    expect(SearchService.normalizeIsbn('12345')).toBeNull();
  });
});
