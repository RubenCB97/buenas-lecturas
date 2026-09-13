import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UserBook, ReadingStatus } from '../user-books/entities/user-book.entity';
import { SearchService } from '../search/search.service';

/** Motivo por el que un libro de la biblioteca sirve de semilla. */
export type SeedReason = 'rated' | 'favorite' | 'read';

export interface ForYouSection {
  /** Libro de la biblioteca en el que se basan las recomendaciones. */
  seed: any;
  reason: SeedReason;
  rating: number | null;
  books: any[];
}

export interface ForYouResponse {
  /** Si el usuario tiene algún libro que sirva de base. */
  hasSeeds: boolean;
  sections: ForYouSection[];
}

@Injectable()
export class DiscoverService {
  private readonly logger = new Logger(DiscoverService.name);

  private static readonly TTL_MS = 60 * 60 * 1000;
  private static readonly MAX_SEEDS = 3;
  private static readonly BOOKS_PER_SEED = 12;

  /** Caché por usuario; la clave incluye las semillas para invalidarse sola. */
  private readonly cache = new Map<string, { value: ForYouResponse; fetchedAt: number }>();

  constructor(
    @InjectRepository(UserBook)
    private readonly userBooksRepo: Repository<UserBook>,
    private readonly searchService: SearchService,
  ) {}

  /**
   * "Porque te gustó X": libros parecidos a los que el usuario valoró bien.
   *
   * Semillas, por prioridad: puntuados con 4★ o más, favoritos y, si no hay
   * ninguno, los últimos leídos. Se excluye todo lo que ya tiene en su
   * biblioteca para no recomendarle lo que ya conoce.
   */
  async forYou(userId: number): Promise<ForYouResponse> {
    const library = await this.userBooksRepo.find({
      where: { user: { id: userId } },
      relations: { book: true },
    });

    const byRecent = (a: UserBook, b: UserBook) =>
      new Date(b.updatedAt ?? 0).getTime() - new Date(a.updatedAt ?? 0).getTime();

    let seeds: { ub: UserBook; reason: SeedReason }[] = library
      .filter(ub => (ub.rating ?? 0) >= 4 || ub.isFavorite)
      .sort((a, b) => (b.rating ?? 0) - (a.rating ?? 0) || byRecent(a, b))
      .map(ub => ({ ub, reason: ((ub.rating ?? 0) >= 4 ? 'rated' : 'favorite') as SeedReason }));

    if (seeds.length === 0) {
      seeds = library
        .filter(ub => ub.status === ReadingStatus.READ)
        .sort(byRecent)
        .map(ub => ({ ub, reason: 'read' as SeedReason }));
    }
    seeds = seeds.filter(s => s.ub.book).slice(0, DiscoverService.MAX_SEEDS);

    if (seeds.length === 0) return { hasSeeds: false, sections: [] };

    const cacheKey = `${userId}:${seeds.map(s => s.ub.book.id).join(',')}`;
    const cached = this.cache.get(cacheKey);
    if (cached && Date.now() - cached.fetchedAt < DiscoverService.TTL_MS) {
      return cached.value;
    }

    // Lo que ya tiene el usuario, por id y por título
    const owned = new Set<string>();
    for (const ub of library) {
      if (ub.book?.googleId) owned.add(ub.book.googleId);
      if (ub.book?.title) owned.add(DiscoverService.normTitle(ub.book.title));
    }

    const sections = await Promise.all(
      seeds.map(async ({ ub, reason }): Promise<ForYouSection> => {
        const books = await this.similarTo(ub.book, owned);
        return { seed: ub.book, reason, rating: ub.rating ?? null, books };
      }),
    );

    const value: ForYouResponse = {
      hasSeeds: true,
      sections: sections.filter(s => s.books.length > 0),
    };
    this.cache.set(cacheKey, { value, fetchedAt: Date.now() });
    return value;
  }
  /** Normaliza un título para comparar ediciones: sin subtítulo ni paréntesis. */
  private static normTitle(title: unknown): string {
    return String(title ?? '')
      .toLowerCase()
      .replace(/\(.*?\)|\[.*?\]/g, '')
      .split(/[:.]/)[0]
      .replace(/\s+/g, ' ')
      .trim();
  }

  /**
   * Libros parecidos a uno dado, mezclando dos señales:
   *  - Mismo tema, ordenados por lectores (la base, estilo "a otros lectores
   *    también les gustó"). Si el libro no tiene categoría, se obtienen sus
   *    temas en Open Library.
   *  - Mismo autor, como mucho 4, para no llenar la fila con una sola saga.
   */
  private async similarTo(book: any, owned: Set<string>): Promise<any[]> {
    const author = (book.authors ?? '').split(',')[0]?.trim();
    const hasAuthor = !!author && author.toLowerCase() !== 'autor desconocido';
    const category = (book.categories ?? '').split(',')[0]?.trim();

    const [authorBooks, subjects] = await Promise.all([
      hasAuthor
        ? this.searchService.searchBooks(`inauthor:"${author}"`).catch(() => [])
        : Promise.resolve([]),
      category
        ? Promise.resolve([category])
        : this.searchService.findSubjectsFor(book.title, hasAuthor ? author : undefined).catch(() => []),
    ]);

    let subjectBooks: any[] = [];
    for (const subject of subjects.slice(0, 3)) {
      const found = await this.searchService.findPopularBySubject(subject).catch(() => []);
      subjectBooks.push(...found);
      if (subjectBooks.length >= DiscoverService.BOOKS_PER_SEED * 2) break;
    }

    const seedTitle = DiscoverService.normTitle(book.title);
    const seedRaw = String(book.title ?? '').trim().toLowerCase();
    const seen = new Set<string>();
    const accept = (b: any) => {
      const id = (b.googleId ?? '').toString();
      const title = DiscoverService.normTitle(b.title);
      if (!title || title === seedTitle || owned.has(id) || owned.has(title) || seen.has(title)) return false;
      // Traducciones que citan el original: "Romper el círculo (It Ends with Us)"
      if (seedRaw.length > 4 && String(b.title ?? '').toLowerCase().includes(`(${seedRaw}`)) return false;
      seen.add(title);
      return true;
    };

    const fromSubject = subjectBooks.filter(accept);
    const fromAuthor = authorBooks.filter(accept);

    // Intercalamos dos del tema por cada uno del autor, con un tope global de
    // libros del mismo autor que el de partida (el tema también puede
    // traerlos) para que la fila no se llene con una sola saga.
    const MAX_SAME_AUTHOR = 4;
    const authorKey = hasAuthor ? author.toLowerCase() : null;
    let sameAuthor = 0;
    const mixed: any[] = [];
    const push = (b: any) => {
      const isSame = !!authorKey && (b.authors ?? []).some((x: string) => String(x).toLowerCase() === authorKey);
      if (isSame) {
        if (sameAuthor >= MAX_SAME_AUTHOR) return;
        sameAuthor++;
      }
      mixed.push(b);
    };
    let a = 0;
    let t = 0;
    while (mixed.length < DiscoverService.BOOKS_PER_SEED && (t < fromSubject.length || a < fromAuthor.length)) {
      for (let k = 0; k < 2 && t < fromSubject.length; k++) push(fromSubject[t++]);
      if (a < fromAuthor.length) push(fromAuthor[a++]);
    }
    return mixed.slice(0, DiscoverService.BOOKS_PER_SEED);
  }
}
