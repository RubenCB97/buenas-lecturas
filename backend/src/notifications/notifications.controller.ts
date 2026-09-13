import { BadRequestException, Body, Controller, Get, Post, Delete, Param, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { NotificationsService } from './notifications.service';
import { PushService } from './push.service';

@Controller('notifications')
@UseGuards(AuthGuard('jwt'))
export class NotificationsController {
  constructor(
    private readonly notificationsService: NotificationsService,
    private readonly pushService: PushService,
  ) {}

  /** Registra el móvil (token de Firebase) para recibir notificaciones push. */
  @Post('devices')
  registerDevice(@Req() req, @Body() body: { token?: string; platform?: string }) {
    if (!body?.token || typeof body.token !== 'string' || body.token.length > 4096) {
      throw new BadRequestException('Token de dispositivo no válido');
    }
    return this.pushService.registerDevice(req.user.id, body.token, body.platform ?? 'android');
  }

  /** Deja de enviar notificaciones a este móvil (al cerrar sesión). */
  @Post('devices/remove')
  unregisterDevice(@Req() req, @Body() body: { token?: string }) {
    if (!body?.token || typeof body.token !== 'string') throw new BadRequestException('Falta el token');
    return this.pushService.unregisterDevice(req.user.id, body.token);
  }

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
