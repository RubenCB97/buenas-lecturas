import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Book } from '../books/entities/book.entity';
import { UserBook, ReadingStatus } from '../user-books/entities/user-book.entity';
import { Activity } from '../user-books/entities/activity.entity';
import { Review } from '../reviews/entities/review.entity';
import { CustomShelf } from '../social/entities/custom-shelf.entity';
import { User } from '../users/entities/user.entity';
import { csvToObjects } from './csv.util';
import { buildGoodreadsCsv, ExportEntry } from './goodreads.exporter';
import {
  GoodreadsEntry,
  mapGoodreadsRow,
  prettifyShelfName,
  REQUIRED_GOODREADS_COLUMNS,
} from './goodreads.mapper';

export interface ImportSummary {
  totalRows: number;
  /** Libros nuevos en la biblioteca. */
  imported: number;
  /** Libros que ya estaban y se han actualizado. */
  updated: number;
  skipped: number;
  reviews: number;
  shelvesCreated: number;
  errors: { row: number; title: string; message: string }[];
}

const MAX_ROWS = 10_000;
const MAX_REPORTED_ERRORS = 20;

@Injectable()
export class GoodreadsImportService {
  private readonly logger = new Logger(GoodreadsImportService.name);

  constructor(
    @InjectRepository(Book) private readonly booksRepo: Repository<Book>,
    @InjectRepository(UserBook) private readonly userBooksRepo: Repository<UserBook>,
    @InjectRepository(Review) private readonly reviewsRepo: Repository<Review>,
    @InjectRepository(CustomShelf) private readonly shelvesRepo: Repository<CustomShelf>,
    @InjectRepository(Activity) private readonly activityRepo: Repository<Activity>,
  ) {}

  /**
   * Importa el CSV de "Export Library" de Goodreads.
   *
   * Es idempotente: si vuelves a importar, los libros que ya tenías se
   * actualizan en vez de duplicarse. Nunca borra datos que ya existían (notas,
   * favoritos, puntuaciones) cuando Goodreads no trae ese dato.
   */
  async importCsv(userId: number, csvText: string): Promise<ImportSummary> {
    const rows = csvToObjects(csvText);
    if (rows.length === 0) {
      throw new BadRequestException('El archivo está vacío o no es un CSV válido');
    }
    const missing = REQUIRED_GOODREADS_COLUMNS.filter(c => !(c in rows[0]));
    if (missing.length > 0) {
      throw new BadRequestException(
        'Este archivo no parece la exportación de Goodreads (faltan las columnas: ' + missing.join(', ') + ')',
      );
    }
    if (rows.length > MAX_ROWS) {
      throw new BadRequestException(`El archivo tiene más de ${MAX_ROWS} libros`);
    }

    const summary: ImportSummary = {
      totalRows: rows.length,
      imported: 0,
      updated: 0,
      skipped: 0,
      reviews: 0,
      shelvesCreated: 0,
      errors: [],
    };

    // Precargamos la biblioteca y las estanterías del usuario para no hacer
    // una consulta por libro
    const library = await this.userBooksRepo.find({
      where: { user: { id: userId } },
      relations: { book: true },
    });
    const userBookByBookId = new Map(library.map(ub => [ub.book.id, ub]));

    const shelves = await this.shelvesRepo.find({
      where: { user: { id: userId } },
      relations: { books: true },
    });
    const shelfByName = new Map(shelves.map(s => [s.name.toLowerCase(), s]));
    const touchedShelves = new Set<CustomShelf>();

    for (let i = 0; i < rows.length; i++) {
      const rowNumber = i + 2; // +1 cabecera, +1 base 1
      const entry = mapGoodreadsRow(rows[i]);
      if (!entry) {
        summary.skipped++;
        continue;
      }

      try {
        const book = await this.findOrCreateBook(entry);

        const existing = userBookByBookId.get(book.id);
        const userBook = existing ?? this.userBooksRepo.create({ user: { id: userId } as User, book });
        this.applyEntry(userBook, entry, book, !existing);
        const saved = await this.userBooksRepo.save(userBook);
        userBookByBookId.set(book.id, saved);
        existing ? summary.updated++ : summary.imported++;

        if (entry.review && (await this.importReview(userId, book, entry))) {
          summary.reviews++;
        }

        for (const shelfKey of entry.shelves) {
          const name = prettifyShelfName(shelfKey);
          let shelf = shelfByName.get(name.toLowerCase());
          if (!shelf) {
            shelf = this.shelvesRepo.create({ user: { id: userId } as User, name, icon: '📚', books: [] });
            shelfByName.set(name.toLowerCase(), shelf);
            summary.shelvesCreated++;
          }
          if (!shelf.books.some(b => b.id === book.id)) {
            shelf.books.push(book);
            touchedShelves.add(shelf);
          }
        }
      } catch (e) {
        this.logger.warn(`Fila ${rowNumber} ("${entry.title}"): ${e.message}`);
        if (summary.errors.length < MAX_REPORTED_ERRORS) {
          summary.errors.push({ row: rowNumber, title: entry.title, message: 'No se pudo importar' });
        }
        summary.skipped++;
      }
    }

    for (const shelf of touchedShelves) {
      await this.shelvesRepo.save(shelf);
    }

    // Una sola entrada en la actividad, en vez de una por libro, para no
    // inundar el feed ni las notificaciones de los amigos
    const total = summary.imported + summary.updated;
    if (total > 0) {
      await this.activityRepo
        .save(
          this.activityRepo.create({
            user: { id: userId } as User,
            action: 'IMPORTED',
            details: `Importó ${total} libro${total === 1 ? '' : 's'} desde Goodreads`,
          }),
        )
        .catch(e => this.logger.warn(`No se pudo registrar la actividad: ${e.message}`));
    }

    return summary;
  }

  /**
   * Exporta la biblioteca del usuario en el formato CSV de Goodreads, con
   * estados, puntuaciones, fechas, reseñas, notas, favoritos y estanterías.
   */
  async exportCsv(userId: number): Promise<{ csv: string; count: number }> {
    const [library, reviews, shelves] = await Promise.all([
      this.userBooksRepo.find({ where: { user: { id: userId } }, relations: { book: true }, order: { addedAt: 'ASC' } }),
      this.reviewsRepo.find({ where: { user: { id: userId } }, relations: { book: true } }),
      this.shelvesRepo.find({ where: { user: { id: userId } }, relations: { books: true } }),
    ]);

    const reviewByBook = new Map(reviews.filter(r => r.book).map(r => [r.book.id, r.content]));
    const shelvesByBook = new Map<number, string[]>();
    for (const shelf of shelves) {
      for (const book of shelf.books ?? []) {
        shelvesByBook.set(book.id, [...(shelvesByBook.get(book.id) ?? []), shelf.name]);
      }
    }

    const entries: ExportEntry[] = library
      .filter(ub => ub.book)
      .map(ub => ({
        googleId: ub.book.googleId ?? null,
        title: ub.book.title,
        authors: (ub.book.authors ?? '').split(',').map(a => a.trim()).filter(Boolean),
        isbn: ub.book.isbn ?? null,
        rating: ub.rating ?? null,
        averageRating: ub.book.averageRating ?? null,
        publisher: ub.book.publisher ?? null,
        pageCount: ub.book.pageCount ?? null,
        publishedDate: ub.book.publishedDate ?? null,
        finishedAt: ub.finishedAt ?? null,
        addedAt: ub.addedAt ?? null,
        status: ub.status,
        isFavorite: !!ub.isFavorite,
        shelves: shelvesByBook.get(ub.book.id) ?? [],
        review: reviewByBook.get(ub.book.id) ?? null,
        notes: ub.notes ?? null,
      }));

    return { csv: buildGoodreadsCsv(entries), count: entries.length };
  }

  /**
   * Busca el libro por ISBN o por su id de Goodreads; si no existe lo crea con
   * los datos del CSV, sin llamar a APIs externas por cada fila (con cientos
   * de libros agotaría la cuota de Google Books y tardaría minutos).
   */
  private async findOrCreateBook(entry: GoodreadsEntry): Promise<Book> {
    const goodreadsKey = entry.goodreadsId ? `gr_${entry.goodreadsId}` : null;

    let book: Book | null = null;
    if (entry.isbn) book = await this.booksRepo.findOne({ where: { isbn: entry.isbn } });
    if (!book && goodreadsKey) book = await this.booksRepo.findOne({ where: { googleId: goodreadsKey } });

    if (book) {
      // Completamos huecos sin pisar lo que ya tenía
      let changed = false;
      if (!book.pageCount && entry.pageCount) {
        book.pageCount = entry.pageCount;
        changed = true;
      }
      if (!book.isbn && entry.isbn) {
        book.isbn = entry.isbn;
        changed = true;
      }
      return changed ? this.booksRepo.save(book) : book;
    }

    return this.booksRepo.save(
      this.booksRepo.create({
        googleId: goodreadsKey ?? `gr_custom_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
        title: entry.title,
        authors: entry.authors.join(', '),
        isbn: entry.isbn ?? undefined,
        pageCount: entry.pageCount ?? undefined,
        publishedDate: entry.publishedYear ?? undefined,
        publisher: entry.publisher ?? undefined,
        // Portada de Open Library por ISBN; `default=false` hace que responda
        // 404 si no la tiene, y la app muestra su placeholder
        thumbnail: entry.isbn
          ? `https://covers.openlibrary.org/b/isbn/${entry.isbn}-M.jpg?default=false`
          : undefined,
      } as Partial<Book>),
    );
  }

  private applyEntry(userBook: UserBook, entry: GoodreadsEntry, book: Book, isNew: boolean) {
    userBook.status = entry.status;

    if (entry.rating) userBook.rating = entry.rating;
    if (entry.isFavorite) userBook.isFavorite = true;
    if (entry.notes && !userBook.notes) userBook.notes = entry.notes;

    if (entry.status === ReadingStatus.READ) {
      if (entry.dateRead) userBook.finishedAt = entry.dateRead;
      const pages = book.pageCount || entry.pageCount;
      if (pages) userBook.currentPage = pages;
    }

    // Conservamos la fecha en que se añadió en Goodreads
    if (isNew && entry.dateAdded) userBook.addedAt = entry.dateAdded;
  }

  /** Crea la reseña si el usuario aún no tenía una de ese libro. */
  private async importReview(userId: number, book: Book, entry: GoodreadsEntry): Promise<boolean> {
    const existing = await this.reviewsRepo.findOne({
      where: { user: { id: userId }, book: { id: book.id } },
    });
    if (existing) return false;

    await this.reviewsRepo.save(
      this.reviewsRepo.create({
        user: { id: userId } as User,
        book,
        content: entry.review!,
        rating: entry.rating ?? 0,
        createdAt: entry.dateRead ?? entry.dateAdded ?? new Date(),
      }),
    );
    return true;
  }
}
