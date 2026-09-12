import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, ManyToMany, JoinTable, CreateDateColumn } from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Book } from '../../books/entities/book.entity';

@Entity()
export class CustomShelf {
  @PrimaryGeneratedColumn()
  id: number;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  user: User;

  @Column()
  name: string;

  @Column({ default: '📚' })
  icon: string;

  @ManyToMany(() => Book, { eager: true })
  @JoinTable()
  books: Book[];

  @CreateDateColumn()
  createdAt: Date;
}
