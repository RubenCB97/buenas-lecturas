import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In, Not } from 'typeorm';
import { Friendship, FriendshipStatus } from './entities/friendship.entity';
import { User } from '../users/entities/user.entity';

@Injectable()
export class FriendsService {
  constructor(
    @InjectRepository(Friendship)
    private friendsRepository: Repository<Friendship>,
    @InjectRepository(User)
    private usersRepository: Repository<User>,
  ) {}

  async searchUsers(query: string, excludeUserId: number) {
    if (!query || query.trim().length < 2) return [];
    return this.usersRepository
      .createQueryBuilder('u')
      .where('u.id != :id', { id: excludeUserId })
      .andWhere('(LOWER(u.firstName) LIKE :q OR LOWER(u.lastName) LIKE :q OR LOWER(u.email) LIKE :q)', {
        q: `%${query.toLowerCase().trim()}%`,
      })
      .limit(25)
      .getMany();
  }

  private orderPair(a: number, b: number) {
    return a < b ? [a, b] : [b, a];
  }

  async sendRequest(fromUserId: number, toUserId: number) {
    if (fromUserId === toUserId) throw new BadRequestException('No puedes seguirte a ti mismo');
    const existing = await this.friendsRepository.findOne({
      where: [
        { requester: { id: fromUserId }, recipient: { id: toUserId } },
        { requester: { id: toUserId }, recipient: { id: fromUserId } },
      ],
    });
    if (existing) {
      if (existing.status === FriendshipStatus.PENDING && existing.recipient.id === fromUserId) {
        existing.status = FriendshipStatus.ACCEPTED;
        return this.friendsRepository.save(existing);
      }
      return existing;
    }
    const fs = this.friendsRepository.create({
      requester: { id: fromUserId } as User,
      recipient: { id: toUserId } as User,
      status: FriendshipStatus.PENDING,
    });
    return this.friendsRepository.save(fs);
  }

  async respondRequest(userId: number, friendshipId: number, accept: boolean) {
    const fs = await this.friendsRepository.findOne({ where: { id: friendshipId } });
    if (!fs) throw new NotFoundException('Solicitud no encontrada');
    if (fs.recipient.id !== userId) throw new ForbiddenException('No puedes responder esta solicitud');
    if (accept) {
      fs.status = FriendshipStatus.ACCEPTED;
      return this.friendsRepository.save(fs);
    }
    await this.friendsRepository.remove(fs);
    return { removed: true };
  }

  async removeFriend(userId: number, otherUserId: number) {
    const fs = await this.friendsRepository.findOne({
      where: [
        { requester: { id: userId }, recipient: { id: otherUserId } },
        { requester: { id: otherUserId }, recipient: { id: userId } },
      ],
    });
    if (!fs) return { removed: false };
    await this.friendsRepository.remove(fs);
    return { removed: true };
  }

  async listFriends(userId: number) {
    const rows = await this.friendsRepository.find({
      where: [
        { requester: { id: userId }, status: FriendshipStatus.ACCEPTED },
        { recipient: { id: userId }, status: FriendshipStatus.ACCEPTED },
      ],
    });
    return rows.map(r => (r.requester.id === userId ? r.recipient : r.requester));
  }

  async listIncoming(userId: number) {
    return this.friendsRepository.find({
      where: { recipient: { id: userId }, status: FriendshipStatus.PENDING },
      order: { createdAt: 'DESC' },
    });
  }

  async listOutgoing(userId: number) {
    return this.friendsRepository.find({
      where: { requester: { id: userId }, status: FriendshipStatus.PENDING },
      order: { createdAt: 'DESC' },
    });
  }

  async friendIds(userId: number): Promise<number[]> {
    const rows = await this.friendsRepository.find({
      where: [
        { requester: { id: userId }, status: FriendshipStatus.ACCEPTED },
        { recipient: { id: userId }, status: FriendshipStatus.ACCEPTED },
      ],
    });
    return rows.map(r => (r.requester.id === userId ? r.recipient.id : r.requester.id));
  }

  async statusBetween(userId: number, otherId: number) {
    const fs = await this.friendsRepository.findOne({
      where: [
        { requester: { id: userId }, recipient: { id: otherId } },
        { requester: { id: otherId }, recipient: { id: userId } },
      ],
    });
    if (!fs) return { status: 'NONE' };
    if (fs.status === FriendshipStatus.ACCEPTED) return { status: 'FRIENDS', id: fs.id };
    if (fs.requester.id === userId) return { status: 'PENDING_OUT', id: fs.id };
    return { status: 'PENDING_IN', id: fs.id };
  }
}
