import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { BooksModule } from './books/books.module';
import { Book } from './books/entities/book.entity';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { User } from './users/entities/user.entity';
import { SearchModule } from './search/search.module';
import { UserBooksModule } from './user-books/user-books.module';
import { ReviewsModule } from './reviews/reviews.module';
import { ProxyModule } from './proxy/proxy.module';
import { FriendsModule } from './friends/friends.module';
import { GroupsModule } from './groups/groups.module';
import { SocialModule } from './social/social.module';
import { ChallengesModule } from './challenges/challenges.module';
import { NotificationsModule } from './notifications/notifications.module';
import { AuthorsModule } from './authors/authors.module';
import { DiscoverModule } from './discover/discover.module';
import { ImportModule } from './import/import.module';

import { UserBook } from './user-books/entities/user-book.entity';
import { DetailController } from './detail/detail.controller';
import { DetailService } from './detail/detail.service';
import { Review } from './reviews/entities/review.entity';
import { Activity } from './user-books/entities/activity.entity';
import { Friendship } from './friends/entities/friendship.entity';
import { ReadingGroup } from './groups/entities/reading-group.entity';
import { GroupMember } from './groups/entities/group-member.entity';
import { GroupBook } from './groups/entities/group-book.entity';
import { GroupMessage } from './groups/entities/group-message.entity';
import { Quote } from './social/entities/quote.entity';
import { Recommendation } from './social/entities/recommendation.entity';
import { ActivityLike } from './social/entities/activity-like.entity';
import { ActivityComment } from './social/entities/activity-comment.entity';
import { CustomShelf } from './social/entities/custom-shelf.entity';
import { ReadingChallenge } from './challenges/entities/reading-challenge.entity';
import { ChallengeParticipant } from './challenges/entities/challenge-participant.entity';
import { ChallengeCategory } from './challenges/entities/challenge-category.entity';
import { ChallengeEntry } from './challenges/entities/challenge-entry.entity';
import { Notification } from './notifications/entities/notification.entity';
import { DeviceToken } from './notifications/entities/device-token.entity';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: (configService: ConfigService) => ({
        type: 'postgres',
        host: configService.get<string>('DATABASE_HOST'),
        port: configService.get<number>('DATABASE_PORT'),
        username: configService.get<string>('DATABASE_USER'),
        password: configService.get<string>('DATABASE_PASSWORD'),
        database: configService.get<string>('DATABASE_NAME'),
        entities: [
          Book, User, UserBook, Review, Activity,
          Friendship,
          ReadingGroup, GroupMember, GroupBook, GroupMessage,
          Quote, Recommendation, ActivityLike, ActivityComment, CustomShelf,
          ReadingChallenge, ChallengeParticipant, ChallengeCategory, ChallengeEntry,
          Notification, DeviceToken,
        ],
        synchronize: true, // ¡Solo para desarrollo!
      }),
      inject: [ConfigService],
    }),
    BooksModule,
    AuthModule,
    UsersModule,
    SearchModule,
    UserBooksModule,
    ReviewsModule,
    ProxyModule,
    FriendsModule,
    GroupsModule,
    SocialModule,
    ChallengesModule,
    NotificationsModule,
    AuthorsModule,
    DiscoverModule,
    ImportModule,
  ],
  controllers: [DetailController],
  providers: [DetailService],
})
export class AppModule {}
