import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ReadingChallenge } from './entities/reading-challenge.entity';
import { ChallengeParticipant } from './entities/challenge-participant.entity';
import { ChallengeCategory } from './entities/challenge-category.entity';
import { ChallengeEntry, ChallengeEntryStatus } from './entities/challenge-entry.entity';
import { User } from '../users/entities/user.entity';
import { BooksService } from '../books/books.service';
import { UserBooksService } from '../user-books/user-books.service';
import { ReadingStatus } from '../user-books/entities/user-book.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { NotificationType } from '../notifications/entities/notification.entity';

@Injectable()
export class ChallengesService {
  constructor(
    @InjectRepository(ReadingChallenge) private challengesRepo: Repository<ReadingChallenge>,
    @InjectRepository(ChallengeParticipant) private participantsRepo: Repository<ChallengeParticipant>,
    @InjectRepository(ChallengeCategory) private categoriesRepo: Repository<ChallengeCategory>,
    @InjectRepository(ChallengeEntry) private entriesRepo: Repository<ChallengeEntry>,
    private booksService: BooksService,
    private userBooksService: UserBooksService,
    private notificationsService: NotificationsService,
  ) {}

  private async participantUserIds(challengeId: number): Promise<number[]> {
    const list = await this.participantsRepo.find({ where: { challenge: { id: challengeId } } });
    return list.map(p => p.user.id);
  }

  private async actorName(userId: number): Promise<string> {
    // Nombre visible del actor a partir de un participante cualquiera con ese id
    const anyRow = await this.participantsRepo.findOne({ where: { user: { id: userId } } });
    return anyRow?.user?.firstName || 'Alguien';
  }

  private async challengeName(challengeId: number): Promise<string> {
    const c = await this.challengesRepo.findOne({ where: { id: challengeId } });
    return c?.name ?? 'un reto';
  }

  private async assertParticipant(userId: number, challengeId: number) {
    const p = await this.participantsRepo.findOne({
      where: { challenge: { id: challengeId }, user: { id: userId } },
    });
    if (!p) throw new ForbiddenException('No participas en este reto');
    return p;
  }

  async create(ownerId: number, data: { name: string; description?: string; coverColor?: string; startDate?: string; endDate?: string; initialParticipantIds?: number[]; initialCategories?: { name: string; icon?: string; description?: string }[] }) {
    const challenge = this.challengesRepo.create({
      name: data.name,
      description: data.description,
      coverColor: data.coverColor ?? '#C8602E',
      startDate: data.startDate ? new Date(data.startDate) : undefined,
      endDate: data.endDate ? new Date(data.endDate) : undefined,
      owner: { id: ownerId } as User,
    } as any);
    const saved = await this.challengesRepo.save(challenge) as any as ReadingChallenge;

    // Owner siempre es participante
    await this.participantsRepo.save(this.participantsRepo.create({
      challenge: saved,
      user: { id: ownerId } as User,
    }));
    // Añadir participantes iniciales
    if (data.initialParticipantIds && data.initialParticipantIds.length > 0) {
      for (const uid of data.initialParticipantIds) {
        if (uid === ownerId) continue;
        await this.participantsRepo.save(this.participantsRepo.create({
          challenge: saved,
          user: { id: uid } as User,
        }));
      }
    }
    // Categorías iniciales
    if (data.initialCategories && data.initialCategories.length > 0) {
      let order = 0;
      for (const c of data.initialCategories) {
        await this.categoriesRepo.save(this.categoriesRepo.create({
          challenge: saved,
          name: c.name,
          icon: c.icon ?? '📖',
          description: c.description,
          order: order++,
          createdBy: { id: ownerId } as User,
        } as any));
      }
    }
    return saved;
  }

  async listMyChallenges(userId: number) {
    // Un reto es "mío" si soy participante
    const participations = await this.participantsRepo.find({
      where: { user: { id: userId } },
      relations: { challenge: true },
    });
    const challenges = participations.map(p => p.challenge);
    // Contar participantes y categorías por reto
    const withCounts = await Promise.all(challenges.map(async c => {
      const participants = await this.participantsRepo.count({ where: { challenge: { id: c.id } } });
      const categories = await this.categoriesRepo.count({ where: { challenge: { id: c.id } } });
      const completed = await this.entriesRepo.count({ where: { challenge: { id: c.id }, user: { id: userId }, status: ChallengeEntryStatus.COMPLETED } });
      return { ...c, participantsCount: participants, categoriesCount: categories, myCompletedCount: completed };
    }));
    return withCounts;
  }

  async getFullChallenge(challengeId: number, userId: number) {
    const challenge = await this.challengesRepo.findOne({ where: { id: challengeId } });
    if (!challenge) throw new NotFoundException('Reto no encontrado');

    const participants = await this.participantsRepo.find({
      where: { challenge: { id: challengeId } },
      order: { joinedAt: 'ASC' },
    });
    const categories = await this.categoriesRepo.find({
      where: { challenge: { id: challengeId } },
      order: { order: 'ASC', createdAt: 'ASC' },
    });
    const entries = await this.entriesRepo.find({
      where: { challenge: { id: challengeId } },
      relations: { category: true, user: true, book: true },
    });

    const isMine = participants.some(p => p.user.id === userId);
    return {
      challenge,
      participants,
      categories,
      entries,
      isParticipant: isMine,
      isOwner: challenge.owner.id === userId,
    };
  }

  async join(userId: number, challengeId: number) {
    const c = await this.challengesRepo.findOne({ where: { id: challengeId } });
    if (!c) throw new NotFoundException('Reto no encontrado');
    const existing = await this.participantsRepo.findOne({
      where: { challenge: { id: challengeId }, user: { id: userId } },
    });
    if (existing) return existing;
    return this.participantsRepo.save(this.participantsRepo.create({
      challenge: { id: challengeId } as ReadingChallenge,
      user: { id: userId } as User,
    }));
  }

  async invite(ownerId: number, challengeId: number, userIds: number[]) {
    const c = await this.challengesRepo.findOne({ where: { id: challengeId } });
    if (!c) throw new NotFoundException('Reto no encontrado');
    if (c.owner.id !== ownerId) throw new ForbiddenException('Solo el propietario puede invitar');
    const results: ChallengeParticipant[] = [];
    const invitedUserIds: number[] = [];
    for (const uid of userIds) {
      const existing = await this.participantsRepo.findOne({
        where: { challenge: { id: challengeId }, user: { id: uid } },
      });
      if (existing) { results.push(existing); continue; }
      const p = await this.participantsRepo.save(this.participantsRepo.create({
        challenge: { id: challengeId } as ReadingChallenge,
        user: { id: uid } as User,
      }));
      results.push(p);
      invitedUserIds.push(uid);
    }
    // Notificar a los invitados nuevos
    if (invitedUserIds.length > 0) {
      await this.notificationsService.notifyUsers(invitedUserIds, {
        actorUserId: ownerId,
        type: NotificationType.CHALLENGE_INVITE,
        title: `Te han añadido al reto "${c.name}"`,
        body: `${await this.actorName(ownerId)} te ha invitado a participar.`,
        refType: 'challenge',
        refId: challengeId,
      });
    }
    return results;
  }

  async leave(userId: number, challengeId: number) {
    const c = await this.challengesRepo.findOne({ where: { id: challengeId } });
    if (!c) throw new NotFoundException('Reto no encontrado');
    if (c.owner.id === userId) throw new ForbiddenException('El propietario no puede salir; elimina el reto');
    const p = await this.participantsRepo.findOne({
      where: { challenge: { id: challengeId }, user: { id: userId } },
    });
    if (!p) return { removed: false };
    await this.participantsRepo.remove(p);
    // También borrar sus entradas
    await this.entriesRepo.delete({ challenge: { id: challengeId } as any, user: { id: userId } as any });
    return { removed: true };
  }

  async delete(userId: number, challengeId: number) {
    const c = await this.challengesRepo.findOne({ where: { id: challengeId } });
    if (!c) throw new NotFoundException('Reto no encontrado');
    if (c.owner.id !== userId) throw new ForbiddenException('Solo el propietario puede eliminar el reto');
    await this.challengesRepo.remove(c);
    return { removed: true };
  }

  // ------- Categorías (columnas) -------
  async addCategory(userId: number, challengeId: number, data: { name: string; icon?: string; description?: string }) {
    await this.assertParticipant(userId, challengeId);
    if (!data.name || data.name.trim().length === 0) throw new BadRequestException('Nombre requerido');
    const count = await this.categoriesRepo.count({ where: { challenge: { id: challengeId } } });
    const saved = await this.categoriesRepo.save(this.categoriesRepo.create({
      challenge: { id: challengeId } as ReadingChallenge,
      name: data.name.trim(),
      icon: data.icon ?? '📖',
      description: data.description,
      order: count,
      createdBy: { id: userId } as User,
    } as any));
    // Avisar al resto de participantes
    const cName = await this.challengeName(challengeId);
    const aName = await this.actorName(userId);
    await this.notificationsService.notifyUsers(await this.participantUserIds(challengeId), {
      actorUserId: userId,
      type: NotificationType.CHALLENGE_CATEGORY_ADDED,
      title: `Nueva categoría en "${cName}"`,
      body: `${aName} ha añadido la categoría "${data.name.trim()}".`,
      refType: 'challenge',
      refId: challengeId,
    });
    return saved;
  }

  async deleteCategory(userId: number, categoryId: number) {
    const cat = await this.categoriesRepo.findOne({ where: { id: categoryId }, relations: { challenge: true } });
    if (!cat) throw new NotFoundException('Categoría no encontrada');
    const isOwner = cat.challenge.owner.id === userId;
    const isCreator = cat.createdBy?.id === userId;
    if (!isOwner && !isCreator) throw new ForbiddenException('Solo el creador de la categoría o el propietario pueden borrarla');
    await this.categoriesRepo.remove(cat);
    return { removed: true };
  }

  // ------- Entradas (celdas) -------
  async setBookForCell(userId: number, challengeId: number, categoryId: number, bookData: any) {
    await this.assertParticipant(userId, challengeId);
    // Validar que la categoría pertenece al reto (para invocaciones desde fuera)
    const category = await this.categoriesRepo.findOne({ where: { id: categoryId }, relations: { challenge: true } });
    if (!category || category.challenge.id !== challengeId) throw new NotFoundException('Categoría no encontrada en este reto');

    const book = await this.booksService.findOrCreateByGoogleId(bookData);
    let entry = await this.entriesRepo.findOne({
      where: { challenge: { id: challengeId }, user: { id: userId }, category: { id: categoryId } },
    });
    if (entry) {
      entry.book = book;
      if (entry.status === ChallengeEntryStatus.COMPLETED) {
        entry.status = ChallengeEntryStatus.READING;
        entry.completedAt = null as any;
      } else if (entry.status === ChallengeEntryStatus.NOT_STARTED) {
        entry.status = ChallengeEntryStatus.READING;
      }
    } else {
      entry = this.entriesRepo.create({
        challenge: { id: challengeId } as ReadingChallenge,
        category: { id: categoryId } as ChallengeCategory,
        user: { id: userId } as User,
        book,
        status: ChallengeEntryStatus.READING,
      });
    }
    const saved = await this.entriesRepo.save(entry);

    // Añadir automáticamente a la biblioteca del usuario como "Quiero leer"
    // si aún no lo tiene (no toca el estado si ya existe).
    try {
      await this.userBooksService.addBookToUser({ id: userId }, bookData, ReadingStatus.WANT_TO_READ);
    } catch (e) {
      // No bloqueamos la escritura del reto si falla lo de la biblioteca
    }

    // Notificar al resto de participantes
    const cName = await this.challengeName(challengeId);
    const aName = await this.actorName(userId);
    await this.notificationsService.notifyUsers(await this.participantUserIds(challengeId), {
      actorUserId: userId,
      type: NotificationType.CHALLENGE_BOOK_PICKED,
      title: `Nuevo libro en "${cName}"`,
      body: `${aName} eligió "${book.title}" para "${category.name}".`,
      refType: 'challenge',
      refId: challengeId,
    });
    return saved;
  }

  // ------- Categorías vacías para el sheet "Añadir a reto" -------
  async listOpenCategories(userId: number, challengeId: number) {
    await this.assertParticipant(userId, challengeId);
    const categories = await this.categoriesRepo.find({
      where: { challenge: { id: challengeId } },
      order: { order: 'ASC', createdAt: 'ASC' },
    });
    const entries = await this.entriesRepo.find({
      where: { challenge: { id: challengeId }, user: { id: userId } },
      relations: { category: true, book: true },
    });
    const busy = new Map<number, { entryId: number; bookTitle: string }>();
    for (const e of entries) {
      if (e.book) busy.set(e.category.id, { entryId: e.id, bookTitle: e.book.title });
    }
    return categories.map(c => ({
      id: c.id,
      name: c.name,
      icon: c.icon,
      empty: !busy.has(c.id),
      currentBookTitle: busy.get(c.id)?.bookTitle,
    }));
  }

  async clearCell(userId: number, challengeId: number, categoryId: number) {
    const entry = await this.entriesRepo.findOne({
      where: { challenge: { id: challengeId }, user: { id: userId }, category: { id: categoryId } },
    });
    if (!entry) return { removed: false };
    await this.entriesRepo.remove(entry);
    return { removed: true };
  }

  async setCellStatus(userId: number, entryId: number, status: ChallengeEntryStatus) {
    const entry = await this.entriesRepo.findOne({ where: { id: entryId }, relations: { challenge: true, category: true, book: true } });
    if (!entry) throw new NotFoundException('Entrada no encontrada');
    if (entry.user.id !== userId) throw new ForbiddenException('Solo puedes modificar tus celdas');
    entry.status = status;
    if (status === ChallengeEntryStatus.COMPLETED) {
      entry.completedAt = new Date();
    } else {
      entry.completedAt = null as any;
    }
    const saved = await this.entriesRepo.save(entry);

    // Reflejar el cambio en la biblioteca del usuario si hay libro
    if (entry.book) {
      try {
        const mapped = status === ChallengeEntryStatus.COMPLETED
          ? ReadingStatus.READ
          : (status === ChallengeEntryStatus.READING ? ReadingStatus.READING : ReadingStatus.WANT_TO_READ);
        await this.userBooksService.addBookToUser({ id: userId }, entry.book, mapped);
      } catch (_) { /* nada */ }
    }

    // Notificar solo si se completó (o si supone un hito social)
    if (status === ChallengeEntryStatus.COMPLETED && entry.book) {
      const aName = await this.actorName(userId);
      await this.notificationsService.notifyUsers(await this.participantUserIds(entry.challenge.id), {
        actorUserId: userId,
        type: NotificationType.CHALLENGE_BOOK_COMPLETED,
        title: `${aName} completó una categoría 🎉`,
        body: `Terminó "${entry.book.title}" en "${entry.category.name}".`,
        refType: 'challenge',
        refId: entry.challenge.id,
      });
    }

    return saved;
  }

  // Actualizar la reseña de una celda (puntuación + comentario) - solo el dueño de la celda
  async reviewCell(userId: number, entryId: number, data: { rating?: number | null; comment?: string | null }) {
    const entry = await this.entriesRepo.findOne({ where: { id: entryId }, relations: { challenge: true, category: true, book: true } });
    if (!entry) throw new NotFoundException('Entrada no encontrada');
    if (entry.user.id !== userId) throw new ForbiddenException('Solo puedes puntuar tus celdas');
    if (data.rating !== undefined) {
      if (data.rating === null) {
        entry.rating = null as any;
      } else {
        // Permitimos medios puntos: redondeo al 0.5 más cercano en el rango 0..5
        const clamped = Math.max(0, Math.min(5, Number(data.rating)));
        const halfStep = Math.round(clamped * 2) / 2;
        entry.rating = halfStep === 0 ? (null as any) : halfStep;
      }
    }
    if (data.comment !== undefined) {
      entry.comment = (data.comment ?? '').toString().trim() || (null as any);
    }
    const saved = await this.entriesRepo.save(entry);

    // Notificar reseña visible al resto
    if ((entry.rating != null || (entry.comment && entry.comment.length > 0)) && entry.book) {
      const aName = await this.actorName(userId);
      await this.notificationsService.notifyUsers(await this.participantUserIds(entry.challenge.id), {
        actorUserId: userId,
        type: NotificationType.CHALLENGE_REVIEWED,
        title: `${aName} ha reseñado un libro del reto`,
        body: `${entry.book.title} · ${entry.rating != null ? `${entry.rating}★` : ''} ${entry.comment ? `"${entry.comment}"` : ''}`.trim(),
        refType: 'challenge',
        refId: entry.challenge.id,
      });
    }
    return saved;
  }

  // Notas globales del participante en la columna "Notas"
  async updateParticipantNotes(userId: number, challengeId: number, notes: string) {
    const participant = await this.participantsRepo.findOne({
      where: { challenge: { id: challengeId }, user: { id: userId } },
    });
    if (!participant) throw new ForbiddenException('No participas en este reto');
    const clean = (notes ?? '').trim();
    participant.notes = clean || (null as any);
    const saved = await this.participantsRepo.save(participant);
    if (clean.length > 0) {
      const cName = await this.challengeName(challengeId);
      const aName = await this.actorName(userId);
      await this.notificationsService.notifyUsers(await this.participantUserIds(challengeId), {
        actorUserId: userId,
        type: NotificationType.CHALLENGE_NOTES_UPDATED,
        title: `${aName} actualizó sus notas en "${cName}"`,
        refType: 'challenge',
        refId: challengeId,
      });
    }
    return saved;
  }

  // ------- Ranking de participantes por completado -------
  async ranking(challengeId: number) {
    const participants = await this.participantsRepo.find({ where: { challenge: { id: challengeId } } });
    const totalCategories = await this.categoriesRepo.count({ where: { challenge: { id: challengeId } } });
    const rows = await Promise.all(participants.map(async p => {
      const completed = await this.entriesRepo.count({
        where: { challenge: { id: challengeId }, user: { id: p.user.id }, status: ChallengeEntryStatus.COMPLETED },
      });
      const reading = await this.entriesRepo.count({
        where: { challenge: { id: challengeId }, user: { id: p.user.id }, status: ChallengeEntryStatus.READING },
      });
      const pct = totalCategories > 0 ? completed / totalCategories : 0;
      return {
        user: p.user,
        completed,
        reading,
        total: totalCategories,
        percentage: Number((pct * 100).toFixed(1)),
      };
    }));
    rows.sort((a, b) => b.percentage - a.percentage);
    return { totalCategories, ranking: rows };
  }
}
