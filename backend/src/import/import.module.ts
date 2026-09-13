import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Book } from '../books/entities/book.entity';
import { UserBook } from '../user-books/entities/user-book.entity';
import { Activity } from '../user-books/entities/activity.entity';
import { Review } from '../reviews/entities/review.entity';
import { CustomShelf } from '../social/entities/custom-shelf.entity';
import { GoodreadsImportService } from './goodreads-import.service';
import { ImportController } from './import.controller';

@Module({
  imports: [TypeOrmModule.forFeature([Book, UserBook, Review, CustomShelf, Activity])],
  providers: [GoodreadsImportService],
  controllers: [ImportController],
})
export class ImportModule {}
