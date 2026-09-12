import { Entity, PrimaryGeneratedColumn, ManyToOne, Unique, CreateDateColumn } from 'typeorm';
import { Activity } from '../../user-books/entities/activity.entity';
import { User } from '../../users/entities/user.entity';

@Entity()
@Unique(['activity', 'user'])
export class ActivityLike {
  @PrimaryGeneratedColumn()
  id: number;

  @ManyToOne(() => Activity, { onDelete: 'CASCADE' })
  activity: Activity;

  @ManyToOne(() => User, { eager: true, onDelete: 'CASCADE' })
  user: User;

  @CreateDateColumn()
  createdAt: Date;
}
