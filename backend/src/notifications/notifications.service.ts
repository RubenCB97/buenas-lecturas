import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Notification, NotificationType } from './entities/notification.entity';
import { User } from '../users/entities/user.entity';

interface NotifyOptions {
  actorUserId?: number | null;
  type: NotificationType;
  title: string;
  body?: string;
  refType?: string;
  refId?: number;
}

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    @InjectRepository(Notification)
    private readonly notificationsRepo: Repository<Notification>,
  ) {}

  /** Notifica a varios usuarios excluyendo al propio actor si viene indicado. */
  async notifyUsers(userIds: number[], opts: NotifyOptions) {
    const targets = Array.from(new Set(userIds)).filter(uid => uid && uid !== opts.actorUserId);
    if (targets.length === 0) return [];
    try {
      const rows: Notification[] = [];
      for (const uid of targets) {
        const n = this.notificationsRepo.create({
          user: { id: uid } as User,
          actor: opts.actorUserId ? ({ id: opts.actorUserId } as User) : undefined,
          type: opts.type,
          title: opts.title,
          body: opts.body ?? undefined,
          refType: opts.refType ?? undefined,
          refId: opts.refId ?? undefined,
        } as any) as any as Notification;
        rows.push(await this.notificationsRepo.save(n));
      }
      return rows;
    } catch (e) {
      this.logger.error(`Error creando notificaciones: ${e.message}`);
      return [];
    }
  }

  async listMine(userId: number, limit = 60) {
    return this.notificationsRepo.find({
      where: { user: { id: userId } } as any,
      order: { createdAt: 'DESC' },
      take: limit,
    });
  }

  async unreadCount(userId: number) {
    const c = await this.notificationsRepo.count({ where: { user: { id: userId }, read: false } as any });
    return { count: c };
  }

  async markRead(userId: number, id: number) {
    const n = await this.notificationsRepo.findOne({ where: { id }, relations: { user: true } });
    if (!n) return { updated: false };
    if (n.user?.id !== userId) return { updated: false };
    n.read = true;
    await this.notificationsRepo.save(n);
    return { updated: true };
  }

  async markAllRead(userId: number) {
    await this.notificationsRepo.update({ user: { id: userId }, read: false } as any, { read: true });
    return { updated: true };
  }

  async remove(userId: number, id: number) {
    const n = await this.notificationsRepo.findOne({ where: { id }, relations: { user: true } });
    if (!n || n.user?.id !== userId) return { removed: false };
    await this.notificationsRepo.remove(n);
    return { removed: true };
  }
}
