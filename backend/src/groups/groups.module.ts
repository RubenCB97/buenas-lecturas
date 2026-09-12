import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ReadingGroup } from './entities/reading-group.entity';
import { GroupMember } from './entities/group-member.entity';
import { GroupBook } from './entities/group-book.entity';
import { GroupMessage } from './entities/group-message.entity';
import { UserBook } from '../user-books/entities/user-book.entity';
import { GroupsService } from './groups.service';
import { GroupsController } from './groups.controller';
import { BooksModule } from '../books/books.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([ReadingGroup, GroupMember, GroupBook, GroupMessage, UserBook]),
    BooksModule,
  ],
  providers: [GroupsService],
  controllers: [GroupsController],
})
export class GroupsModule {}
