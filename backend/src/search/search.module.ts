import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { SearchService } from './search.service';
import { SearchController } from './search.controller';
import { CoverRecognitionService } from './cover-recognition.service';

@Module({
  imports: [HttpModule],
  providers: [SearchService, CoverRecognitionService],
  controllers: [SearchController],
  exports: [SearchService],
})
export class SearchModule {}
