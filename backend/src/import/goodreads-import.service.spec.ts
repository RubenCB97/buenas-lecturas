import { GoodreadsImportService } from './goodreads-import.service';
import { ReadingStatus } from '../user-books/entities/user-book.entity';

/** Repositorio en memoria con lo mínimo que usa el servicio. */
function fakeRepo<T extends { id?: number }>(match: (item: T, where: any) => boolean) {
  const items: T[] = [];
  let seq = 1;
  return {
    items,
    create: (data: Partial<T>) => ({ ...data }) as T,
    save: async (entity: T) => {
      if (!entity.id) {
        entity.id = seq++;
        items.push(entity);
      }
      return entity;
    },
    find: async ({ where }: any) => items.filter(i => match(i, where)),
    findOne: async ({ where }: any) => items.find(i => match(i, where)) ?? null,
  };
}

const HEADER =
  'Book Id,Title,Author,Author l-f,Additional Authors,ISBN,ISBN13,My Rating,Average Rating,Publisher,' +
  'Binding,Number of Pages,Year Published,Original Publication Year,Date Read,Date Added,Bookshelves,' +
  'Bookshelves with positions,Exclusive Shelf,My Review,Spoiler,Private Notes,Read Count,Owned Copies';

const CSV =
  HEADER +
  '\n1,Dune,Frank Herbert,,,="",="9780441172719",5,4.3,Ace,,688,2005,1965,2021/03/02,2020/12/24,"favorites, sci-fi",,read,"Genial",,Nota GR,1,0' +
  '\n2,Marina,Carlos Ruiz Zafón,,,="",="",0,4,,,,,,,2024/01/05,sci-fi,,to-read,,,,0,0' +
  '\n3,,Sin título,,,="",="",0,0,,,,,,,,,,read,,,,0,0';

function setup() {
  const books = fakeRepo<any>((b, w) => (w.isbn ? b.isbn === w.isbn : b.googleId === w.googleId));
  const userBooks = fakeRepo<any>((ub, w) => ub.user.id === w.user.id);
  const reviews = fakeRepo<any>((r, w) => r.user.id === w.user.id && r.book.id === w.book.id);
  const shelves = fakeRepo<any>((s, w) => s.user.id === w.user.id);
  const activity = fakeRepo<any>(() => true);
  const service = new GoodreadsImportService(
    books as any, userBooks as any, reviews as any, shelves as any, activity as any,
  );
  return { service, books, userBooks, reviews, shelves, activity };
}

describe('GoodreadsImportService', () => {
  it('importa libros, estados, reseñas y estanterías', async () => {
    const { service, books, userBooks, reviews, shelves, activity } = setup();
    const summary = await service.importCsv(7, CSV);

    expect(summary).toMatchObject({ totalRows: 3, imported: 2, updated: 0, skipped: 1, reviews: 1, shelvesCreated: 1 });
    expect(books.items).toHaveLength(2);

    const dune = userBooks.items.find(ub => ub.book.title === 'Dune');
    expect(dune).toMatchObject({ status: ReadingStatus.READ, rating: 5, isFavorite: true, currentPage: 688, notes: 'Nota GR' });
    expect(dune.finishedAt.toISOString().slice(0, 10)).toBe('2021-03-02');
    expect(books.items.find(b => b.title === 'Dune').thumbnail).toContain('covers.openlibrary.org/b/isbn/9780441172719');

    const marina = userBooks.items.find(ub => ub.book.title === 'Marina');
    expect(marina.status).toBe(ReadingStatus.WANT_TO_READ);
    expect(marina.rating).toBeUndefined();

    expect(reviews.items).toHaveLength(1);
    expect(shelves.items).toHaveLength(1);
    expect(shelves.items[0].name).toBe('Sci fi');
    expect(shelves.items[0].books.map(b => b.title).sort()).toEqual(['Dune', 'Marina']);
    expect(activity.items).toHaveLength(1);
  });

  it('reimportar no duplica nada y no pisa las notas del usuario', async () => {
    const { service, books, userBooks, reviews, shelves } = setup();
    await service.importCsv(7, CSV);
    userBooks.items.find(ub => ub.book.title === 'Dune').notes = 'Mi nota en la app';

    const summary = await service.importCsv(7, CSV);

    expect(summary).toMatchObject({ imported: 0, updated: 2, reviews: 0, shelvesCreated: 0 });
    expect(books.items).toHaveLength(2);
    expect(userBooks.items).toHaveLength(2);
    expect(reviews.items).toHaveLength(1);
    expect(shelves.items[0].books).toHaveLength(2);
    expect(userBooks.items.find(ub => ub.book.title === 'Dune').notes).toBe('Mi nota en la app');
  });

  it('rechaza un CSV que no es de Goodreads', async () => {
    const { service } = setup();
    await expect(service.importCsv(7, 'nombre,apellido\nAna,López')).rejects.toThrow(/Goodreads/);
    await expect(service.importCsv(7, '')).rejects.toThrow(/vacío/);
  });
});
