import { Entity, PrimaryGeneratedColumn, ManyToOne, Unique, CreateDateColumn, Column } from 'typeorm';
import { ReadingChallenge } from './reading-challenge.entity';
import { User } from '../../users/entities/user.entity';

@Entity()
@Unique(['challenge', 'user'])
export class ChallengeParticipant {
  @PrimaryGeneratedColumn()
  id: number;

  @ManyToOne(() => ReadingChallenge, { onDelete: 'CASCADE' })
  challenge: ReadingChallenge;

  @ManyToOne(() => User, { eager: true, onDelete: 'CASCADE' })
  user: User;

  // Notas globales del participante en la última columna "Notas" del reto
  @Column({ type: 'text', nullable: true })
  notes: string;

  @CreateDateColumn()
  joinedAt: Date;
}
