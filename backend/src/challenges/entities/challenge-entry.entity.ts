import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, Unique, CreateDateColumn, UpdateDateColumn } from 'typeorm';
import { ReadingChallenge } from './reading-challenge.entity';
import { ChallengeCategory } from './challenge-category.entity';
import { User } from '../../users/entities/user.entity';
import { Book } from '../../books/entities/book.entity';

export enum ChallengeEntryStatus {
  NOT_STARTED = 'NOT_STARTED',
  READING = 'READING',
  COMPLETED = 'COMPLETED',
}

/**
 * Una celda (usuario x categoría) del reto lector: qué libro ha elegido ese
 * usuario para esa categoría y en qué estado va.
 */
@Entity()
@Unique(['challenge', 'user', 'category'])
export class ChallengeEntry {
  @PrimaryGeneratedColumn()
  id: number;

  @ManyToOne(() => ReadingChallenge, { onDelete: 'CASCADE' })
  challenge: ReadingChallenge;

  @ManyToOne(() => ChallengeCategory, { onDelete: 'CASCADE' })
  category: ChallengeCategory;

  @ManyToOne(() => User, { eager: true, onDelete: 'CASCADE' })
  user: User;

  @ManyToOne(() => Book, { eager: true, nullable: true, onDelete: 'SET NULL' })
  book: Book;

  @Column({ type: 'enum', enum: ChallengeEntryStatus, default: ChallengeEntryStatus.NOT_STARTED })
  status: ChallengeEntryStatus;

  @Column({ type: 'timestamp', nullable: true })
  completedAt: Date;

  // Puntuación 0.5-5.0 (medios puntos permitidos) que el lector da a este libro
  @Column({ type: 'float', nullable: true })
  rating: number;

  // Comentario breve mostrado en la propia celda
  @Column({ type: 'text', nullable: true })
  comment: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
