import { Controller, Get, Post, Delete, Param, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { NotificationsService } from './notifications.service';

@Controller('notifications')
@UseGuards(AuthGuard('jwt'))
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Get()
  list(@Req() req) {
    return this.notificationsService.listMine(req.user.id);
  }

  @Get('unread-count')
  unread(@Req() req) {
    return this.notificationsService.unreadCount(req.user.id);
  }

  @Post(':id/read')
  markRead(@Req() req, @Param('id') id: string) {
    return this.notificationsService.markRead(req.user.id, +id);
  }

  @Post('read-all')
  markAllRead(@Req() req) {
    return this.notificationsService.markAllRead(req.user.id);
  }

  @Delete(':id')
  remove(@Req() req, @Param('id') id: string) {
    return this.notificationsService.remove(req.user.id, +id);
  }
}
