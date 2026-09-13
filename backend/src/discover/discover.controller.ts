import { Controller, Get, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { DiscoverService } from './discover.service';

@Controller('discover')
@UseGuards(AuthGuard('jwt'))
export class DiscoverController {
  constructor(private readonly discoverService: DiscoverService) {}

  /** Recomendaciones "Porque te gustó X" para el usuario actual. */
  @Get('for-you')
  forYou(@Req() req) {
    return this.discoverService.forYou(req.user.id);
  }
}
