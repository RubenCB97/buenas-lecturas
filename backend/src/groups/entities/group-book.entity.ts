import { Entity, PrimaryGeneratedColumn, ManyToOne, Column, CreateDateColumn } from 'typeorm';
import { ReadingGroup } from './reading-group.entity';
import { Book } from '../../books/entities/book.entity';

export enum GroupBookStatus {
  UPCOMING = 'UPCOMING',
  CURRENT = 'CURRENT',
  FINISHED = 'FINISHED',
}

@Entity()
export class GroupBook {
  @PrimaryGeneratedColumn()
  id: number;

  @ManyToOne(() => ReadingGroup, { onDelete: 'CASCADE' })
  group: ReadingGroup;

  @ManyToOne(() => Book, { eager: true })
  book: Book;

  @Column({ type: 'timestamp', nullable: true })
  startDate: Date;

  @Column({ type: 'timestamp', nullable: true })
  targetEndDate: Date;

  @Column({ type: 'enum', enum: GroupBookStatus, default: GroupBookStatus.UPCOMING })
  status: GroupBookStatus;

  @CreateDateColumn()
  createdAt: Date;
}
