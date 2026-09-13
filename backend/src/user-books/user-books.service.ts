import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UserBook, ReadingStatus } from './entities/user-book.entity';
import { Activity } from './entities/activity.entity';
import { BooksService } from '../books/books.service';
import { Book } from '../books/entities/book.entity';
import { User } from '../users/entities/user.entity';
import { computeReadingStats, ReadingStats } from './reading-stats';

@Injectable()
export class UserBooksService {
  private readonly logger = new Logger(UserBooksService.name);

  constructor(
    @InjectRepository(UserBook)
    private userBooksRepository: Repository<UserBook>,
    @InjectRepository(Activity)
    private activityRepository: Repository<Activity>,
    private booksService: BooksService,
  ) {}

  private async logActivity(user: { id: number }, book: any, action: string, details?: string) {
    try {
      const activity = this.activityRepository.create({
        user: { id: user.id } as User,
        book: { id: book.id } as Book,
        action,
        details
      });
      await this.activityRepository.save(activity);
    } catch (e) {
      this.logger.error(`Error logging activity: ${e.message}`);
    }
  }

  // Aplica reglas al cambio de estado (fechas y páginas al estilo Goodreads)
  private applyStatusSideEffects(userBook: UserBook, newStatus: ReadingStatus) {
    const now = new Date();
    if (newStatus === ReadingStatus.READING && !userBook.startedAt) {
      userBook.startedAt = now;
    }
    if (newStatus === ReadingStatus.READ) {
      if (!userBook.startedAt) userBook.startedAt = now;
      userBook.finishedAt = now;
      // Marcar como completo en páginas si conocemos el total
      const total = userBook.book?.pageCount;
      if (total && (!userBook.currentPage || userBook.currentPage < total)) {
        userBook.currentPage = total;
      }
    }
    if (newStatus === ReadingStatus.WANT_TO_READ) {
      userBook.currentPage = null as any;
    }
    // Abandonado: conservamos hasta dónde llegó y cuándo empezó, pero no
    // cuenta como terminado
    if (newStatus === ReadingStatus.ABANDONED) {
      userBook.finishedAt = null as any;
    }
    userBook.status = newStatus;
  }

  async addBookToUser(user: { id: number }, bookData: any, status: ReadingStatus = ReadingStatus.WANT_TO_READ) {
    try {
      this.logger.log(`addBookToUser called with user: ${JSON.stringify(user)}, book id: ${bookData?.googleId ?? bookData?.id}`);
      const book = await this.booksService.findOrCreateByGoogleId(bookData);

      let userBook = await this.userBooksRepository.findOne({
        where: { user: { id: user.id }, book: { id: book.id } },
        relations: { user: true, book: true },
      });

      if (userBook) {
        this.applyStatusSideEffects(userBook, status);
      } else {
        userBook = this.userBooksRepository.create({
          user: { id: user.id } as User,
          book,
          status,
        });
        this.applyStatusSideEffects(userBook, status);
      }

      const saved = await this.userBooksRepository.save(userBook);
      await this.logActivity(user, book, 'ADDED', `Añadido: ${book.title}`);
      return saved;
    } catch (e) {
      this.logger.error(`Error in addBookToUser: ${e.message}`, e.stack);
      throw e;
    }
  }

  async getUserLibrary(userId: number) {
    return this.userBooksRepository.find({
      where: { user: { id: userId } },
      relations: { book: true },
      order: { updatedAt: 'DESC' }
    });
  }

  async getUserBookByBookId(userId: number, bookId: number) {
    const userBook = await this.userBooksRepository.findOne({
      where: { user: { id: userId }, book: { id: bookId } },
      relations: { user: true, book: true }
    });
    if (!userBook) throw new NotFoundException('Libro no encontrado en tu biblioteca');
    return userBook;
  }

  async updateBookStatus(userId: number, bookId: number, status: ReadingStatus) {
    const userBook = await this.getUserBookByBookId(userId, bookId);
    this.applyStatusSideEffects(userBook, status);
    await this.logActivity(userBook.user, userBook.book, 'UPDATED_STATUS', `Cambio de estado: ${status}`);
    return this.userBooksRepository.save(userBook);
  }

  async updateBookRating(userId: number, bookId: number, rating: number) {
    const userBook = await this.getUserBookByBookId(userId, bookId);
    // Admite medios puntos: 0.5, 1.0, 1.5, ..., 5.0
    const clamped = Math.max(0, Math.min(5, Number(rating)));
    userBook.rating = Math.round(clamped * 2) / 2;
    await this.logActivity(userBook.user, userBook.book, 'RATED', `Puntuación: ${userBook.rating} estrellas`);
    return this.userBooksRepository.save(userBook);
  }

  // Progreso de lectura (página actual)
  async updateBookProgress(userId: number, bookId: number, currentPage: number) {
    const userBook = await this.getUserBookByBookId(userId, bookId);
    userBook.currentPage = Math.max(0, currentPage);

    // Si aún no está en "READING" al añadir progreso, pasarlo automáticamente
    if (userBook.status === ReadingStatus.WANT_TO_READ && currentPage > 0) {
      this.applyStatusSideEffects(userBook, ReadingStatus.READING);
    }

    // Si alcanza (o supera) las páginas totales, marcar como READ
    const total = userBook.book?.pageCount;
    if (total && currentPage >= total) {
      this.applyStatusSideEffects(userBook, ReadingStatus.READ);
    }

    await this.logActivity(
      userBook.user,
      userBook.book,
      'PROGRESS',
      `Progreso: página ${currentPage}${total ? ` de ${total}` : ''}`,
    );
    return this.userBooksRepository.save(userBook);
  }

  // Notas privadas del lector
  async updateBookNotes(userId: number, bookId: number, notes: string) {
    const userBook = await this.getUserBookByBookId(userId, bookId);
    userBook.notes = notes;
    return this.userBooksRepository.save(userBook);
  }

  // Alternar favorito
  async toggleFavorite(userId: number, bookId: number) {
    const userBook = await this.getUserBookByBookId(userId, bookId);
    userBook.isFavorite = !userBook.isFavorite;
    if (userBook.isFavorite) {
      await this.logActivity(userBook.user, userBook.book, 'FAVORITED', `Añadido a favoritos: ${userBook.book.title}`);
    }
    return this.userBooksRepository.save(userBook);
  }

  async getUserActivities(userId: number) {
    try {
      return await this.activityRepository.find({
        where: { user: { id: userId } },
        order: { createdAt: 'DESC' },
        relations: { book: true },
        take: 50,
      });
    } catch (e) {
      this.logger.error(`Error in getUserActivities: ${e.message}`, e.stack);
      return [];
    }
  }

  async removeBookFromUser(userId: number, bookId: number) {
    try {
      const userBook = await this.userBooksRepository.findOne({
        where: { user: { id: userId }, book: { id: bookId } },
        relations: { user: true, book: true }
      });
      if (!userBook) throw new NotFoundException('Libro no encontrado en tu biblioteca');

      const bookTitle = userBook.book.title;
      await this.logActivity(userBook.user, userBook.book, 'REMOVED', `Eliminado: ${bookTitle}`);

      return await this.userBooksRepository.delete(userBook.id);
    } catch (error) {
      this.logger.error(`Error deleting book: ${error.message}`);
      throw error;
    }
  }

  /** Estadísticas detalladas de lectura de un año (pantalla Estadísticas). */
  async getDetailedStats(userId: number, year?: number): Promise<ReadingStats> {
    const library = await this.userBooksRepository.find({
      where: { user: { id: userId } },
      relations: { book: true },
    });
    return computeReadingStats(library as any, year ?? new Date().getFullYear());
  }

  // Estadísticas agregadas del año en curso para "Mi Año Literario"
  async getYearStats(userId: number, year?: number) {
    const target = year ?? new Date().getFullYear();
    const start = new Date(`${target}-01-01T00:00:00Z`);
    const end = new Date(`${target + 1}-01-01T00:00:00Z`);

    const finished = await this.userBooksRepository
      .createQueryBuilder('ub')
      .leftJoinAndSelect('ub.book', 'book')
      .where('ub.userId = :uid', { uid: userId })
      .andWhere('ub.finishedAt >= :start AND ub.finishedAt < :end', { start, end })
      .getMany();

    const totalPages = finished.reduce((acc, ub) => acc + (ub.book?.pageCount || 0), 0);
    const ratings = finished.filter(ub => ub.rating != null && ub.rating > 0).map(ub => ub.rating!);
    const avgRating = ratings.length > 0 ? ratings.reduce((a, b) => a + b, 0) / ratings.length : 0;

    // Género más leído
    const genreCounts = new Map<string, number>();
    for (const ub of finished) {
      const cats = (ub.book?.categories || '').split(',').map(s => s.trim()).filter(Boolean);
      for (const c of cats) {
        genreCounts.set(c, (genreCounts.get(c) || 0) + 1);
      }
    }
    let topGenre: string | null = null;
    let topGenreCount = 0;
    for (const [g, n] of genreCounts.entries()) {
      if (n > topGenreCount) { topGenre = g; topGenreCount = n; }
    }

    return {
      year: target,
      booksRead: finished.length,
      totalPages,
      avgRating: Number(avgRating.toFixed(2)),
      topGenre,
    };
  }
}
