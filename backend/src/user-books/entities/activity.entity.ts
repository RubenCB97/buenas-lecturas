import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, CreateDateColumn } from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Book } from '../../books/entities/book.entity';

@Entity()
export class Activity {
  @PrimaryGeneratedColumn()
  id: number;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  user: User;

  @ManyToOne(() => Book)
  book: Book;

  @Column()
  action: string; // "ADDED", "UPDATED_STATUS", "RATED"

  @Column({ nullable: true })
  details: string;

  @CreateDateColumn()
  createdAt: Date;
}
