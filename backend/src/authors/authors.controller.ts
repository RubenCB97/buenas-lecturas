import { Controller, Get, Param, Query } from '@nestjs/common';
import { AuthorsService } from './authors.service';

@Controller('authors')
export class AuthorsController {
  constructor(private readonly authorsService: AuthorsService) {}

  /** Buscar autores por nombre. */
  @Get('search')
  search(@Query('q') q: string) {
    return this.authorsService.searchAuthors(q ?? '');
  }

  /** Solo los libros de un autor. */
  @Get('books')
  books(@Query('name') name: string) {
    return this.authorsService.getAuthorBooks(name ?? '');
  }

  /** Ficha completa del autor (bio + foto + libros). */
  @Get(':name')
  detail(@Param('name') name: string) {
    return this.authorsService.getAuthorDetail(decodeURIComponent(name ?? ''));
  }
}
