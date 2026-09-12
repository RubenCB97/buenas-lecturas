import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

@Entity()
export class Book {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ unique: true, nullable: true })
  googleId: string;

  @Column()
  title: string;

  @Column({ nullable: true })
  subtitle: string;

  @Column({ nullable: true })
  authors: string;

  @Column('text', { nullable: true })
  description: string;

  @Column({ nullable: true })
  isbn: string;

  @Column({ nullable: true })
  publishedDate: string;

  @Column({ nullable: true })
  thumbnail: string;

  @Column({ nullable: true })
  pageCount: number;

  @Column({ nullable: true })
  categories: string;

  @Column('float', { nullable: true })
  averageRating: number;

  @Column({ nullable: true })
  publisher: string;

  @Column({ nullable: true })
  language: string;

  @Column({ nullable: true })
  asin: string;

  @Column('text', { nullable: true })
  awards: string;
}
