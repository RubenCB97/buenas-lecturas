import { Controller, Get, Post, Delete, Body, Param, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ChallengesService } from './challenges.service';
import { ChallengeEntryStatus } from './entities/challenge-entry.entity';

@Controller('challenges')
@UseGuards(AuthGuard('jwt'))
export class ChallengesController {
  constructor(private readonly challengesService: ChallengesService) {}

  @Post()
  create(@Req() req, @Body() body: {
    name: string;
    description?: string;
    coverColor?: string;
    startDate?: string;
    endDate?: string;
    initialParticipantIds?: number[];
    initialCategories?: { name: string; icon?: string; description?: string }[];
  }) {
    return this.challengesService.create(req.user.id, body);
  }

  @Get()
  list(@Req() req) {
    return this.challengesService.listMyChallenges(req.user.id);
  }

  @Get(':id')
  detail(@Req() req, @Param('id') id: string) {
    return this.challengesService.getFullChallenge(+id, req.user.id);
  }

  @Get(':id/ranking')
  ranking(@Param('id') id: string) {
    return this.challengesService.ranking(+id);
  }

  // Categorías del reto con flag de "vacía" para el usuario actual — sirve
  // al sheet "Añadir a reto" desde la ficha del libro.
  @Get(':id/my-slots')
  mySlots(@Req() req, @Param('id') id: string) {
    return this.challengesService.listOpenCategories(req.user.id, +id);
  }

  @Post(':id/join')
  join(@Req() req, @Param('id') id: string) {
    return this.challengesService.join(req.user.id, +id);
  }

  @Post(':id/invite')
  invite(@Req() req, @Param('id') id: string, @Body() body: { userIds: number[] }) {
    return this.challengesService.invite(req.user.id, +id, body.userIds ?? []);
  }

  @Post(':id/leave')
  leave(@Req() req, @Param('id') id: string) {
    return this.challengesService.leave(req.user.id, +id);
  }

  @Delete(':id')
  remove(@Req() req, @Param('id') id: string) {
    return this.challengesService.delete(req.user.id, +id);
  }

  // ---- Categorías ----
  @Post(':id/categories')
  addCategory(@Req() req, @Param('id') id: string, @Body() body: { name: string; icon?: string; description?: string }) {
    return this.challengesService.addCategory(req.user.id, +id, body);
  }

  @Delete('categories/:categoryId')
  removeCategory(@Req() req, @Param('categoryId') categoryId: string) {
    return this.challengesService.deleteCategory(req.user.id, +categoryId);
  }

  // ---- Celdas (usuario x categoría) ----
  @Post(':id/entries/:categoryId')
  setBook(@Req() req, @Param('id') id: string, @Param('categoryId') categoryId: string, @Body() body: { book: any }) {
    return this.challengesService.setBookForCell(req.user.id, +id, +categoryId, body.book);
  }

  @Delete(':id/entries/:categoryId')
  clearCell(@Req() req, @Param('id') id: string, @Param('categoryId') categoryId: string) {
    return this.challengesService.clearCell(req.user.id, +id, +categoryId);
  }

  @Post('entries/:entryId/status')
  updateStatus(@Req() req, @Param('entryId') entryId: string, @Body() body: { status: ChallengeEntryStatus }) {
    return this.challengesService.setCellStatus(req.user.id, +entryId, body.status);
  }

  // Puntuación + comentario en la celda
  @Post('entries/:entryId/review')
  reviewEntry(@Req() req, @Param('entryId') entryId: string, @Body() body: { rating?: number | null; comment?: string | null }) {
    return this.challengesService.reviewCell(req.user.id, +entryId, body);
  }

  // Notas globales del participante en la columna "Notas"
  @Post(':id/notes')
  updateMyNotes(@Req() req, @Param('id') id: string, @Body() body: { notes: string }) {
    return this.challengesService.updateParticipantNotes(req.user.id, +id, body.notes ?? '');
  }
}
