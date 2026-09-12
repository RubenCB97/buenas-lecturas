import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ReadingChallenge } from './entities/reading-challenge.entity';
import { ChallengeParticipant } from './entities/challenge-participant.entity';
import { ChallengeCategory } from './entities/challenge-category.entity';
import { ChallengeEntry } from './entities/challenge-entry.entity';
import { ChallengesService } from './challenges.service';
import { ChallengesController } from './challenges.controller';
import { BooksModule } from '../books/books.module';
import { UserBooksModule } from '../user-books/user-books.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([ReadingChallenge, ChallengeParticipant, ChallengeCategory, ChallengeEntry]),
    BooksModule,
    UserBooksModule,
    NotificationsModule,
  ],
  providers: [ChallengesService],
  controllers: [ChallengesController],
})
export class ChallengesModule {}
