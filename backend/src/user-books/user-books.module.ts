import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UserBooksService } from './user-books.service';
import { UserBooksController } from './user-books.controller';
import { UserBook } from './entities/user-book.entity';
import { Activity } from './entities/activity.entity';
import { BooksModule } from '../books/books.module';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([UserBook, Activity]),
    BooksModule,
    UsersModule,
  ],
  controllers: [UserBooksController],
  providers: [UserBooksService],
  exports: [UserBooksService, TypeOrmModule],
})
export class UserBooksModule {}
