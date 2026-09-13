import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, Unique, CreateDateColumn, UpdateDateColumn } from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Book } from '../../books/entities/book.entity';

export enum ReadingStatus {
  WANT_TO_READ = 'WANT_TO_READ',
  READING = 'READING',
  READ = 'READ',
  /** Empezado y dejado sin terminar («No lo terminé»). */
  ABANDONED = 'ABANDONED',
}

@Entity()
@Unique(['user', 'book'])
export class UserBook {
  @PrimaryGeneratedColumn()
  id: number;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  user: User;

  @ManyToOne(() => Book, { eager: true })
  book: Book;

  @Column({
    type: 'enum',
    enum: ReadingStatus,
    default: ReadingStatus.WANT_TO_READ,
  })
  status: ReadingStatus;

  // Permite medios puntos (3.5, 4.5…)
  @Column({ type: 'float', nullable: true })
  rating: number;

  @Column({ type: 'text', nullable: true })
  review: string;

  // Página actual (progreso de lectura, estilo Goodreads)
  @Column({ type: 'int', nullable: true })
  currentPage: number;

  // Fecha en la que se empezó a leer el libro
  @Column({ type: 'timestamp', nullable: true })
  startedAt: Date;

  // Fecha en la que se terminó el libro
  @Column({ type: 'timestamp', nullable: true })
  finishedAt: Date;

  // Notas privadas del lector (no visibles públicamente)
  @Column({ type: 'text', nullable: true })
  notes: string;

  // Marcar como favorito (estilo Goodreads Favourites)
  @Column({ type: 'boolean', default: false })
  isFavorite: boolean;

  @CreateDateColumn()
  addedAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
