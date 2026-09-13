import { Module } from '@nestjs/common';
import { DiscoverService } from './discover.service';
import { DiscoverController } from './discover.controller';
import { UserBooksModule } from '../user-books/user-books.module';
import { SearchModule } from '../search/search.module';

@Module({
  imports: [UserBooksModule, SearchModule],
  providers: [DiscoverService],
  controllers: [DiscoverController],
})
export class DiscoverModule {}
