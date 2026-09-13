import { Controller, Get, NotFoundException, Param } from '@nestjs/common';
import { BooksService } from './books.service';
import { SearchService } from '../search/search.service';

@Controller('books')
export class BooksController {
  constructor(
    private readonly booksService: BooksService,
    private readonly searchService: SearchService,
  ) {}

  /**
   * Resuelve el libro de un enlace compartido (/libro/<id>). Público para que
   * funcione aunque quien lo abre no haya iniciado sesión todavía.
   */
  @Get('lookup/:id')
  async lookup(@Param('id') id: string) {
    const stored = await this.booksService.findByGoogleId(id);
    if (stored) return stored;
    const external = await this.searchService.lookupByExternalId(id);
    if (!external) throw new NotFoundException('No hemos encontrado ese libro');
    return external;
  }

  @Get()
  findAll() {
    return this.booksService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.booksService.findOne(+id);
  }
}
