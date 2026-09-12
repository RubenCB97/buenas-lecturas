import { Entity, PrimaryGeneratedColumn, ManyToOne, Column, CreateDateColumn } from 'typeorm';
import { ReadingGroup } from './reading-group.entity';
import { User } from '../../users/entities/user.entity';
import { Book } from '../../books/entities/book.entity';

@Entity()
export class GroupMessage {
  @PrimaryGeneratedColumn()
  id: number;

  @ManyToOne(() => ReadingGroup, { onDelete: 'CASCADE' })
  group: ReadingGroup;

  @ManyToOne(() => User, { eager: true, onDelete: 'CASCADE' })
  user: User;

  // Opcional: si es un mensaje asociado a un libro concreto del grupo
  @ManyToOne(() => Book, { nullable: true })
  book: Book;

  // Opcional: capítulo del libro sobre el que se comenta (para hilos por capítulo)
  @Column({ type: 'int', nullable: true })
  chapterNumber: number;

  @Column('text')
  content: string;

  @CreateDateColumn()
  createdAt: Date;
}
