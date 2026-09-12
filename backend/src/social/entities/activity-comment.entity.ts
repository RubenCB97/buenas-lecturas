import { Entity, PrimaryGeneratedColumn, ManyToOne, Column, CreateDateColumn } from 'typeorm';
import { Activity } from '../../user-books/entities/activity.entity';
import { User } from '../../users/entities/user.entity';

@Entity()
export class ActivityComment {
  @PrimaryGeneratedColumn()
  id: number;

  @ManyToOne(() => Activity, { onDelete: 'CASCADE' })
  activity: Activity;

  @ManyToOne(() => User, { eager: true, onDelete: 'CASCADE' })
  user: User;

  @Column('text')
  content: string;

  @CreateDateColumn()
  createdAt: Date;
}
