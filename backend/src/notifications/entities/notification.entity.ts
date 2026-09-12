import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, CreateDateColumn, Index } from 'typeorm';
import { User } from '../../users/entities/user.entity';

export enum NotificationType {
  CHALLENGE_INVITE = 'CHALLENGE_INVITE',
  CHALLENGE_CATEGORY_ADDED = 'CHALLENGE_CATEGORY_ADDED',
  CHALLENGE_BOOK_PICKED = 'CHALLENGE_BOOK_PICKED',
  CHALLENGE_BOOK_COMPLETED = 'CHALLENGE_BOOK_COMPLETED',
  CHALLENGE_REVIEWED = 'CHALLENGE_REVIEWED',
  CHALLENGE_NOTES_UPDATED = 'CHALLENGE_NOTES_UPDATED',
  CHALLENGE_MEMBER_JOINED = 'CHALLENGE_MEMBER_JOINED',
  FRIEND_REQUEST = 'FRIEND_REQUEST',
  FRIEND_ACCEPTED = 'FRIEND_ACCEPTED',
  RECOMMENDATION_RECEIVED = 'RECOMMENDATION_RECEIVED',
  GROUP_INVITE = 'GROUP_INVITE',
  GROUP_MESSAGE = 'GROUP_MESSAGE',
}

@Entity()
@Index(['user', 'read'])
export class Notification {
  @PrimaryGeneratedColumn()
  id: number;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  user: User;

  @ManyToOne(() => User, { eager: true, nullable: true, onDelete: 'SET NULL' })
  actor: User;

  @Column({ type: 'enum', enum: NotificationType })
  type: NotificationType;

  @Column()
  title: string;

  @Column({ type: 'text', nullable: true })
  body: string;

  @Column({ nullable: true })
  refType: string;

  @Column({ type: 'int', nullable: true })
  refId: number;

  @Column({ default: false })
  read: boolean;

  @CreateDateColumn()
  createdAt: Date;
}
