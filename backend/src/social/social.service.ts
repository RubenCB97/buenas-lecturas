import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { Quote } from './entities/quote.entity';
import { Recommendation } from './entities/recommendation.entity';
import { ActivityLike } from './entities/activity-like.entity';
import { ActivityComment } from './entities/activity-comment.entity';
import { CustomShelf } from './entities/custom-shelf.entity';
import { Activity } from '../user-books/entities/activity.entity';
import { UserBook } from '../user-books/entities/user-book.entity';
import { User } from '../users/entities/user.entity';
import { Book } from '../books/entities/book.entity';
import { BooksService } from '../books/books.service';
import { FriendsService } from '../friends/friends.service';
import { NotificationsService } from '../notifications/notifications.service';
import { NotificationType } from '../notifications/entities/notification.entity';

@Injectable()
export class SocialService {
  constructor(
    @InjectRepository(Quote) private quotesRepo: Repository<Quote>,
    @InjectRepository(Recommendation) private recRepo: Repository<Recommendation>,
    @InjectRepository(ActivityLike) private likesRepo: Repository<ActivityLike>,
    @InjectRepository(ActivityComment) private commentsRepo: Repository<ActivityComment>,
    @InjectRepository(CustomShelf) private shelvesRepo: Repository<CustomShelf>,
    @InjectRepository(Activity) private activityRepo: Repository<Activity>,
    @InjectRepository(UserBook) private userBooksRepo: Repository<UserBook>,
    private booksService: BooksService,
    private friendsService: FriendsService,
    private notificationsService: NotificationsService,
  ) {}

  // ---------------- Feed de amigos ----------------
  async friendsFeed(userId: number, limit = 40) {
    const friendIds = await this.friendsService.friendIds(userId);
    const userIds = [userId, ...friendIds];
    const activities = await this.activityRepo.find({
      where: { user: { id: In(userIds) } },
      relations: { user: true, book: true },
      order: { createdAt: 'DESC' },
      take: limit,
    });

    // Anotar con nº de likes / comentarios y si yo he dado like
    const ids = activities.map(a => a.id);
    let likes: any[] = [];
    let myLikes: any[] = [];
    let comments: any[] = [];
    if (ids.length > 0) {
      likes = await this.likesRepo
        .createQueryBuilder('l')
        .select('l."activityId"', 'aid')
        .addSelect('COUNT(*)', 'count')
        .where('l."activityId" IN (:...ids)', { ids })
        .groupBy('l."activityId"')
        .getRawMany();
      myLikes = await this.likesRepo.find({
        where: { activity: { id: In(ids) }, user: { id: userId } },
        relations: { activity: true },
      });
      comments = await this.commentsRepo
        .createQueryBuilder('c')
        .select('c."activityId"', 'aid')
        .addSelect('COUNT(*)', 'count')
        .where('c."activityId" IN (:...ids)', { ids })
        .groupBy('c."activityId"')
        .getRawMany();
    }
    const likeMap = new Map(likes.map((l: any) => [Number(l.aid), Number(l.count)]));
    const commentMap = new Map(comments.map((c: any) => [Number(c.aid), Number(c.count)]));
    const myLikeSet = new Set(myLikes.map((l: any) => l.activity.id));

    return activities.map(a => ({
      ...a,
      likesCount: likeMap.get(a.id) || 0,
      commentsCount: commentMap.get(a.id) || 0,
      likedByMe: myLikeSet.has(a.id),
    }));
  }

  async toggleLike(userId: number, activityId: number) {
    const existing = await this.likesRepo.findOne({ where: { activity: { id: activityId }, user: { id: userId } } });
    if (existing) {
      await this.likesRepo.remove(existing);
      return { liked: false };
    }
    await this.likesRepo.save(this.likesRepo.create({ activity: { id: activityId } as Activity, user: { id: userId } as User }));
    return { liked: true };
  }

  async listComments(activityId: number) {
    return this.commentsRepo.find({ where: { activity: { id: activityId } }, order: { createdAt: 'ASC' } });
  }

  async addComment(userId: number, activityId: number, content: string) {
    return this.commentsRepo.save(this.commentsRepo.create({
      activity: { id: activityId } as Activity,
      user: { id: userId } as User,
      content,
    }));
  }

  async deleteComment(userId: number, commentId: number) {
    const c = await this.commentsRepo.findOne({ where: { id: commentId } });
    if (!c) throw new NotFoundException('Comentario no encontrado');
    if (c.user.id !== userId) throw new ForbiddenException('No puedes borrar comentarios ajenos');
    await this.commentsRepo.remove(c);
    return { removed: true };
  }

  // ---------------- Citas ----------------
  async addQuote(userId: number, bookData: any, text: string, page?: number) {
    const book = await this.booksService.findOrCreateByGoogleId(bookData);
    const q = this.quotesRepo.create({
      user: { id: userId } as User,
      book,
      text,
      page: page ?? undefined,
    } as any);
    return this.quotesRepo.save(q);
  }

  async listQuotesForBook(googleId: string) {
    return this.quotesRepo.find({
      where: { book: { googleId } },
      order: { createdAt: 'DESC' },
    });
  }

  async listMyQuotes(userId: number) {
    return this.quotesRepo.find({
      where: { user: { id: userId } },
      order: { createdAt: 'DESC' },
    });
  }

  async friendsQuotesFeed(userId: number) {
    const friendIds = await this.friendsService.friendIds(userId);
    const ids = [userId, ...friendIds];
    return this.quotesRepo.find({
      where: { user: { id: In(ids) } },
      order: { createdAt: 'DESC' },
      take: 60,
    });
  }

  async deleteQuote(userId: number, quoteId: number) {
    const q = await this.quotesRepo.findOne({ where: { id: quoteId } });
    if (!q) throw new NotFoundException('Cita no encontrada');
    if (q.user.id !== userId) throw new ForbiddenException('No puedes borrar citas ajenas');
    await this.quotesRepo.remove(q);
    return { removed: true };
  }

  // ---------------- Recomendaciones ----------------
  async sendRecommendation(fromUserId: number, toUserId: number, bookData: any, note?: string) {
    const book = await this.booksService.findOrCreateByGoogleId(bookData);
    const rec = this.recRepo.create({
      fromUser: { id: fromUserId } as User,
      toUser: { id: toUserId } as User,
      book,
      note: note ?? undefined,
    } as any);
    const saved = await this.recRepo.save(rec);
    const name = await this.notificationsService.displayName(fromUserId);
    await this.notificationsService.notifyUsers([toUserId], {
      actorUserId: fromUserId,
      type: NotificationType.RECOMMENDATION_RECEIVED,
      title: `${name} te recomienda «${book.title}»`,
      body: note?.trim() ? note.trim().slice(0, 140) : undefined,
      refType: 'recommendation',
      refId: (saved as any).id,
    });
    return saved;
  }

  async myRecommendations(userId: number) {
    return this.recRepo.find({
      where: { toUser: { id: userId } },
      order: { createdAt: 'DESC' },
    });
  }

  async markRecommendationSeen(userId: number, recId: number) {
    const rec = await this.recRepo.findOne({ where: { id: recId } });
    if (!rec) throw new NotFoundException('Recomendación no encontrada');
    if (rec.toUser.id !== userId) throw new ForbiddenException('No puedes marcar recomendaciones ajenas');
    rec.seen = true;
    return this.recRepo.save(rec);
  }

  // ---------------- Estanterías personalizadas ----------------
  async createShelf(userId: number, name: string, icon?: string) {
    const s = this.shelvesRepo.create({
      user: { id: userId } as User,
      name,
      icon: icon ?? '📚',
      books: [],
    });
    return this.shelvesRepo.save(s);
  }

  async myShelves(userId: number) {
    return this.shelvesRepo.find({ where: { user: { id: userId } }, order: { createdAt: 'ASC' } });
  }

  async addBookToShelf(userId: number, shelfId: number, bookData: any) {
    const shelf = await this.shelvesRepo.findOne({ where: { id: shelfId }, relations: { user: true, books: true } });
    if (!shelf) throw new NotFoundException('Estantería no encontrada');
    if (shelf.user.id !== userId) throw new ForbiddenException('Estantería ajena');
    const book = await this.booksService.findOrCreateByGoogleId(bookData);
    if (!shelf.books.find(b => b.id === book.id)) {
      shelf.books.push(book);
    }
    return this.shelvesRepo.save(shelf);
  }

  async removeBookFromShelf(userId: number, shelfId: number, bookId: number) {
    const shelf = await this.shelvesRepo.findOne({ where: { id: shelfId }, relations: { user: true, books: true } });
    if (!shelf) throw new NotFoundException('Estantería no encontrada');
    if (shelf.user.id !== userId) throw new ForbiddenException('Estantería ajena');
    shelf.books = shelf.books.filter(b => b.id !== bookId);
    return this.shelvesRepo.save(shelf);
  }

  async deleteShelf(userId: number, shelfId: number) {
    const shelf = await this.shelvesRepo.findOne({ where: { id: shelfId }, relations: { user: true } });
    if (!shelf) throw new NotFoundException('Estantería no encontrada');
    if (shelf.user.id !== userId) throw new ForbiddenException('Estantería ajena');
    await this.shelvesRepo.remove(shelf);
    return { removed: true };
  }

  // ---------------- Perfil público de otro usuario ----------------
  async publicProfile(currentUserId: number, otherUserId: number) {
    const user = await this.recRepo.manager.getRepository(User).findOne({ where: { id: otherUserId } });
    if (!user) throw new NotFoundException('Usuario no encontrado');
    const library = await this.userBooksRepo.find({
      where: { user: { id: otherUserId } },
      relations: { book: true },
      take: 60,
      order: { updatedAt: 'DESC' },
    });
    const status = await this.friendsService.statusBetween(currentUserId, otherUserId);
    return { user, library, friendship: status };
  }

  // ---------------- Comparativa 1-a-1 ----------------
  async compareWith(userId: number, otherId: number) {
    const [mine, theirs] = await Promise.all([
      this.userBooksRepo.find({ where: { user: { id: userId } }, relations: { book: true } }),
      this.userBooksRepo.find({ where: { user: { id: otherId } }, relations: { book: true } }),
    ]);
    const mineByBookId = new Map(mine.map(m => [m.book.id, m]));
    const shared: any[] = [];
    for (const t of theirs) {
      const m = mineByBookId.get(t.book.id);
      if (m) shared.push({
        book: t.book,
        myRating: m.rating,
        theirRating: t.rating,
        myStatus: m.status,
        theirStatus: t.status,
      });
    }
    return {
      totalMine: mine.length,
      totalTheirs: theirs.length,
      shared,
      sharedCount: shared.length,
    };
  }
}
