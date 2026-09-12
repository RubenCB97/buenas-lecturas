import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, CreateDateColumn } from 'typeorm';
import { ReadingChallenge } from './reading-challenge.entity';
import { User } from '../../users/entities/user.entity';

@Entity()
export class ChallengeCategory {
  @PrimaryGeneratedColumn()
  id: number;

  @ManyToOne(() => ReadingChallenge, { onDelete: 'CASCADE' })
  challenge: ReadingChallenge;

  @Column()
  name: string;

  @Column({ type: 'text', nullable: true })
  description: string;

  @Column({ default: '📖' })
  icon: string;

  @Column({ default: 0 })
  order: number;

  // Quién propuso la categoría (para trazabilidad; cualquiera del grupo puede crear)
  @ManyToOne(() => User, { eager: true, onDelete: 'SET NULL', nullable: true })
  createdBy: User;

  @CreateDateColumn()
  createdAt: Date;
}
