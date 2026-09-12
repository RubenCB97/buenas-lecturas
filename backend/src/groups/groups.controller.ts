import { Controller, Get, Post, Delete, Body, Param, Query, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { GroupsService } from './groups.service';
import { GroupBookStatus } from './entities/group-book.entity';

@Controller('groups')
@UseGuards(AuthGuard('jwt'))
export class GroupsController {
  constructor(private readonly groupsService: GroupsService) {}

  @Post()
  create(@Req() req, @Body() body: { name: string; description?: string; coverColor?: string; isPrivate?: boolean }) {
    return this.groupsService.createGroup(req.user.id, body);
  }

  @Get()
  myGroups(@Req() req) {
    return this.groupsService.listMyGroups(req.user.id);
  }

  @Get('discover')
  discover(@Req() req, @Query('q') q?: string) {
    return this.groupsService.discover(req.user.id, q);
  }

  @Get(':id')
  detail(@Req() req, @Param('id') id: string) {
    return this.groupsService.getGroup(+id, req.user.id);
  }

  @Post(':id/join')
  join(@Req() req, @Param('id') id: string) {
    return this.groupsService.joinGroup(req.user.id, +id);
  }

  @Post(':id/leave')
  leave(@Req() req, @Param('id') id: string) {
    return this.groupsService.leaveGroup(req.user.id, +id);
  }

  @Delete(':id')
  remove(@Req() req, @Param('id') id: string) {
    return this.groupsService.deleteGroup(req.user.id, +id);
  }

  @Post(':id/books')
  addBook(@Req() req, @Param('id') id: string, @Body() body: { book: any; startDate?: string; targetEndDate?: string; status?: GroupBookStatus }) {
    return this.groupsService.addBookToGroup(req.user.id, +id, body.book, {
      startDate: body.startDate,
      targetEndDate: body.targetEndDate,
      status: body.status,
    });
  }

  @Post('books/:groupBookId/status')
  updateBookStatus(@Req() req, @Param('groupBookId') gbId: string, @Body() body: { status: GroupBookStatus }) {
    return this.groupsService.setBookStatus(req.user.id, +gbId, body.status);
  }

  @Get(':id/ranking')
  ranking(@Req() req, @Param('id') id: string) {
    return this.groupsService.getProgressRanking(req.user.id, +id);
  }

  @Get(':id/messages')
  messages(@Req() req, @Param('id') id: string, @Query('bookId') bookId?: string, @Query('chapter') chapter?: string) {
    return this.groupsService.listMessages(req.user.id, +id, bookId ? +bookId : undefined, chapter != null ? +chapter : undefined);
  }

  @Post(':id/messages')
  send(@Req() req, @Param('id') id: string, @Body() body: { content: string; bookId?: number; chapterNumber?: number }) {
    return this.groupsService.postMessage(req.user.id, +id, body.content, body.bookId, body.chapterNumber);
  }
}
