import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { ReadingGroup } from './entities/reading-group.entity';
import { GroupMember, GroupRole } from './entities/group-member.entity';
import { GroupBook, GroupBookStatus } from './entities/group-book.entity';
import { GroupMessage } from './entities/group-message.entity';
import { User } from '../users/entities/user.entity';
import { Book } from '../books/entities/book.entity';
import { UserBook } from '../user-books/entities/user-book.entity';
import { BooksService } from '../books/books.service';
import { NotificationsService } from '../notifications/notifications.service';
import { NotificationType } from '../notifications/entities/notification.entity';

@Injectable()
export class GroupsService {
  constructor(
    @InjectRepository(ReadingGroup)
    private groupsRepo: Repository<ReadingGroup>,
    @InjectRepository(GroupMember)
    private membersRepo: Repository<GroupMember>,
    @InjectRepository(GroupBook)
    private groupBooksRepo: Repository<GroupBook>,
    @InjectRepository(GroupMessage)
    private messagesRepo: Repository<GroupMessage>,
    @InjectRepository(UserBook)
    private userBooksRepo: Repository<UserBook>,
    private booksService: BooksService,
    private notificationsService: NotificationsService,
  ) {}

  async createGroup(ownerId: number, data: { name: string; description?: string; coverColor?: string; isPrivate?: boolean }) {
    const group = this.groupsRepo.create({
      name: data.name,
      description: data.description,
      coverColor: data.coverColor ?? '#C8602E',
      isPrivate: data.isPrivate ?? false,
      owner: { id: ownerId } as User,
    });
    const saved = await this.groupsRepo.save(group);
    await this.membersRepo.save(this.membersRepo.create({
      group: saved,
      user: { id: ownerId } as User,
      role: GroupRole.OWNER,
    }));
    return saved;
  }

  async listMyGroups(userId: number) {
    const memberships = await this.membersRepo.find({
      where: { user: { id: userId } },
      relations: { group: true },
      order: { joinedAt: 'DESC' },
    });
    return memberships.map(m => ({ ...m.group, myRole: m.role }));
  }

  async getGroup(groupId: number, userId: number) {
    const group = await this.groupsRepo.findOne({ where: { id: groupId } });
    if (!group) throw new NotFoundException('Grupo no encontrado');
    const membership = await this.membersRepo.findOne({ where: { group: { id: groupId }, user: { id: userId } } });
    if (group.isPrivate && !membership) throw new ForbiddenException('Este grupo es privado');
    const members = await this.membersRepo.find({ where: { group: { id: groupId } }, order: { joinedAt: 'ASC' } });
    const books = await this.groupBooksRepo.find({ where: { group: { id: groupId } }, order: { createdAt: 'DESC' } });
    return { ...group, myRole: membership?.role ?? null, members, books };
  }

  async joinGroup(userId: number, groupId: number) {
    const group = await this.groupsRepo.findOne({ where: { id: groupId } });
    if (!group) throw new NotFoundException('Grupo no encontrado');
    const existing = await this.membersRepo.findOne({ where: { group: { id: groupId }, user: { id: userId } } });
    if (existing) return existing;
    return this.membersRepo.save(this.membersRepo.create({
      group,
      user: { id: userId } as User,
      role: GroupRole.MEMBER,
    }));
  }

  async leaveGroup(userId: number, groupId: number) {
    const member = await this.membersRepo.findOne({ where: { group: { id: groupId }, user: { id: userId } } });
    if (!member) return { removed: false };
    if (member.role === GroupRole.OWNER) throw new ForbiddenException('El propietario no puede salirse; elimina el grupo o cede la propiedad.');
    await this.membersRepo.remove(member);
    return { removed: true };
  }

  async deleteGroup(userId: number, groupId: number) {
    const group = await this.groupsRepo.findOne({ where: { id: groupId } });
    if (!group) throw new NotFoundException('Grupo no encontrado');
    if (group.owner.id !== userId) throw new ForbiddenException('Solo el propietario puede eliminar el grupo');
    await this.groupsRepo.remove(group);
    return { removed: true };
  }

  async addBookToGroup(userId: number, groupId: number, bookData: any, dates?: { startDate?: string; targetEndDate?: string; status?: GroupBookStatus }) {
    await this.assertMember(userId, groupId);
    const book = await this.booksService.findOrCreateByGoogleId(bookData);
    // Si viene como CURRENT, degradar los anteriores CURRENT a FINISHED
    if (dates?.status === GroupBookStatus.CURRENT) {
      await this.groupBooksRepo.update({ group: { id: groupId }, status: GroupBookStatus.CURRENT }, { status: GroupBookStatus.FINISHED });
    }
    const gb = this.groupBooksRepo.create({
      group: { id: groupId } as ReadingGroup,
      book,
      startDate: dates?.startDate ? new Date(dates.startDate) : undefined,
      targetEndDate: dates?.targetEndDate ? new Date(dates.targetEndDate) : undefined,
      status: dates?.status ?? GroupBookStatus.CURRENT,
    } as any);
    return this.groupBooksRepo.save(gb);
  }

  async setBookStatus(userId: number, groupBookId: number, status: GroupBookStatus) {
    const gb = await this.groupBooksRepo.findOne({ where: { id: groupBookId }, relations: { group: true } });
    if (!gb) throw new NotFoundException('Libro de grupo no encontrado');
    await this.assertMember(userId, gb.group.id);
    if (status === GroupBookStatus.CURRENT) {
      await this.groupBooksRepo.update({ group: { id: gb.group.id }, status: GroupBookStatus.CURRENT }, { status: GroupBookStatus.FINISHED });
    }
    gb.status = status;
    return this.groupBooksRepo.save(gb);
  }

  // Ranking de progreso: qué % lleva cada miembro del libro CURRENT del grupo
  async getProgressRanking(userId: number, groupId: number) {
    await this.assertMember(userId, groupId);
    const current = await this.groupBooksRepo.findOne({
      where: { group: { id: groupId }, status: GroupBookStatus.CURRENT },
      order: { createdAt: 'DESC' },
    });
    if (!current) return { book: null, ranking: [] };

    const members = await this.membersRepo.find({ where: { group: { id: groupId } } });
    const memberIds = members.map(m => m.user.id);
    if (memberIds.length === 0) return { book: current.book, ranking: [] };

    const userBooks = await this.userBooksRepo.find({
      where: { user: { id: In(memberIds) }, book: { id: current.book.id } },
      relations: { user: true },
    });

    const total = current.book.pageCount || 0;
    const ranking = members.map(m => {
      const ub = userBooks.find(u => u.user.id === m.user.id);
      const cp = ub?.currentPage ?? 0;
      // Progreso real: terminado = 100%; sin páginas registradas = 0%.
      // Antes se inventaba un 30% para quien estuviera "leyendo" sin datos.
      // Sin total conocido estimamos 300 págs, igual que la app, para que el
      // porcentaje del club coincida con el que ve cada lector.
      const pct = ub?.status === 'READ'
        ? 1
        : (cp > 0 ? Math.min(1, cp / (total > 0 ? total : 300)) : 0);
      return {
        user: m.user,
        role: m.role,
        currentPage: cp,
        totalPages: total,
        percentage: Number((pct * 100).toFixed(1)),
        status: ub?.status ?? 'NOT_STARTED',
        finishedAt: ub?.finishedAt ?? null,
      };
    }).sort((a, b) => b.percentage - a.percentage);

    return { book: current.book, groupBookId: current.id, targetEndDate: current.targetEndDate, ranking };
  }

  // Chat / discusión
  async postMessage(userId: number, groupId: number, content: string, bookId?: number, chapterNumber?: number) {
    await this.assertMember(userId, groupId);
    const msg = this.messagesRepo.create({
      group: { id: groupId } as ReadingGroup,
      user: { id: userId } as User,
      content,
      book: bookId ? ({ id: bookId } as Book) : undefined,
      chapterNumber: chapterNumber ?? undefined,
    } as any);
    const saved = await this.messagesRepo.save(msg);
    void this.notifyGroupMessage(userId, groupId, content);
    return saved;
  }

  private async notifyGroupMessage(authorId: number, groupId: number, content: string) {
    try {
      const [group, members, name] = await Promise.all([
        this.groupsRepo.findOne({ where: { id: groupId } }),
        this.membersRepo.find({ where: { group: { id: groupId } } }),
        this.notificationsService.displayName(authorId),
      ]);
      const text = content.trim();
      await this.notificationsService.notifyUsers(members.map((m) => m.user.id), {
        actorUserId: authorId,
        type: NotificationType.GROUP_MESSAGE,
        title: `${name} en ${group?.name ?? 'tu club'}`,
        body: text.length > 140 ? `${text.slice(0, 137)}…` : text,
        refType: 'group',
        refId: groupId,
      });
    } catch {
      // Una notificación fallida no debe afectar al mensaje ya publicado
    }
  }

  async listMessages(userId: number, groupId: number, bookId?: number, chapter?: number, limit = 100) {
    await this.assertMember(userId, groupId);
    const qb = this.messagesRepo.createQueryBuilder('m')
      .leftJoinAndSelect('m.user', 'u')
      .leftJoinAndSelect('m.book', 'b')
      .where('m."groupId" = :gid', { gid: groupId });
    if (bookId) qb.andWhere('m."bookId" = :bid', { bid: bookId });
    if (chapter != null) qb.andWhere('m."chapterNumber" = :ch', { ch: chapter });
    qb.orderBy('m.createdAt', 'ASC').take(limit);
    return qb.getMany();
  }

  // Buscar grupos públicos (Discover)
  async discover(userId: number, query?: string) {
    const qb = this.groupsRepo.createQueryBuilder('g')
      .where('g."isPrivate" = false');
    if (query && query.trim().length > 0) {
      qb.andWhere('(LOWER(g.name) LIKE :q OR LOWER(g.description) LIKE :q)', { q: `%${query.toLowerCase()}%` });
    }
    qb.orderBy('g.createdAt', 'DESC').take(30);
    return qb.getMany();
  }

  private async assertMember(userId: number, groupId: number) {
    const m = await this.membersRepo.findOne({ where: { group: { id: groupId }, user: { id: userId } } });
    if (!m) throw new ForbiddenException('No perteneces a este grupo');
    return m;
  }
}
