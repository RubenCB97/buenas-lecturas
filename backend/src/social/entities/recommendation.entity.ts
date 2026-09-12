import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, CreateDateColumn } from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Book } from '../../books/entities/book.entity';

@Entity()
export class Recommendation {
  @PrimaryGeneratedColumn()
  id: number;

  @ManyToOne(() => User, { eager: true, onDelete: 'CASCADE' })
  fromUser: User;

  @ManyToOne(() => User, { eager: true, onDelete: 'CASCADE' })
  toUser: User;

  @ManyToOne(() => Book, { eager: true, onDelete: 'CASCADE' })
  book: Book;

  @Column({ type: 'text', nullable: true })
  note: string;

  @Column({ default: false })
  seen: boolean;

  @CreateDateColumn()
  createdAt: Date;
}
