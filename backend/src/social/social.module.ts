import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Quote } from './entities/quote.entity';
import { Recommendation } from './entities/recommendation.entity';
import { ActivityLike } from './entities/activity-like.entity';
import { ActivityComment } from './entities/activity-comment.entity';
import { CustomShelf } from './entities/custom-shelf.entity';
import { Activity } from '../user-books/entities/activity.entity';
import { UserBook } from '../user-books/entities/user-book.entity';
import { SocialService } from './social.service';
import { SocialController } from './social.controller';
import { BooksModule } from '../books/books.module';
import { FriendsModule } from '../friends/friends.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Quote, Recommendation, ActivityLike, ActivityComment, CustomShelf, Activity, UserBook]),
    BooksModule,
    FriendsModule,
  ],
  providers: [SocialService],
  controllers: [SocialController],
})
export class SocialModule {}
