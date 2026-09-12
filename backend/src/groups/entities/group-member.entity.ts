import { Entity, PrimaryGeneratedColumn, ManyToOne, Column, Unique, CreateDateColumn } from 'typeorm';
import { ReadingGroup } from './reading-group.entity';
import { User } from '../../users/entities/user.entity';

export enum GroupRole {
  OWNER = 'OWNER',
  ADMIN = 'ADMIN',
  MEMBER = 'MEMBER',
}

@Entity()
@Unique(['group', 'user'])
export class GroupMember {
  @PrimaryGeneratedColumn()
  id: number;

  @ManyToOne(() => ReadingGroup, { onDelete: 'CASCADE' })
  group: ReadingGroup;

  @ManyToOne(() => User, { eager: true, onDelete: 'CASCADE' })
  user: User;

  @Column({ type: 'enum', enum: GroupRole, default: GroupRole.MEMBER })
  role: GroupRole;

  @CreateDateColumn()
  joinedAt: Date;
}
