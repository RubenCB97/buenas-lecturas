import { Controller, Get, Post, Body, Param, Delete, UseGuards, Req, Query } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { UserBooksService } from './user-books.service';
import { ReadingStatus } from './entities/user-book.entity';

@Controller('library')
@UseGuards(AuthGuard('jwt'))
export class UserBooksController {
  constructor(private readonly userBooksService: UserBooksService) {}

  @Post('add')
  async add(@Req() req, @Body() body: { book: any, status?: ReadingStatus }) {
    try {
      return await this.userBooksService.addBookToUser(req.user, body.book, body.status);
    } catch (e) {
      console.error('CONTROLLER ADD ERROR:', e);
      throw e;
    }
  }

  @Get()
  async getMyLibrary(@Req() req) {
    return this.userBooksService.getUserLibrary(req.user.id);
  }

  @Get('activities')
  async getMyActivities(@Req() req) {
    return this.userBooksService.getUserActivities(req.user.id);
  }

  @Get('stats/detailed')
  async getDetailedStats(@Req() req, @Query('year') year?: string) {
    const parsed = year ? parseInt(year, 10) : NaN;
    return this.userBooksService.getDetailedStats(req.user.id, Number.isFinite(parsed) ? parsed : undefined);
  }

  @Get('stats/year')
  async getYearStats(@Req() req, @Query('year') year?: string) {
    return this.userBooksService.getYearStats(req.user.id, year ? +year : undefined);
  }

  @Delete(':bookId')
  async remove(@Req() req, @Param('bookId') bookId: string) {
    return this.userBooksService.removeBookFromUser(req.user.id, +bookId);
  }

  @Post(':bookId/status')
  async updateStatus(@Req() req, @Param('bookId') bookId: string, @Body() body: { status: ReadingStatus }) {
    return this.userBooksService.updateBookStatus(req.user.id, +bookId, body.status);
  }

  @Post(':bookId/rating')
  async updateRating(@Req() req, @Param('bookId') bookId: string, @Body() body: { rating: number }) {
    return this.userBooksService.updateBookRating(req.user.id, +bookId, body.rating);
  }

  // Actualizar progreso de lectura (página actual)
  @Post(':bookId/progress')
  async updateProgress(@Req() req, @Param('bookId') bookId: string, @Body() body: { currentPage: number }) {
    return this.userBooksService.updateBookProgress(req.user.id, +bookId, body.currentPage);
  }

  // Guardar notas privadas del lector
  @Post(':bookId/notes')
  async updateNotes(@Req() req, @Param('bookId') bookId: string, @Body() body: { notes: string }) {
    return this.userBooksService.updateBookNotes(req.user.id, +bookId, body.notes ?? '');
  }

  // Marcar/desmarcar favorito
  @Post(':bookId/favorite')
  async toggleFavorite(@Req() req, @Param('bookId') bookId: string) {
    return this.userBooksService.toggleFavorite(req.user.id, +bookId);
  }
}
