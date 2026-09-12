import { Controller, Get, Post, Delete, Param, Query, Req, UseGuards, Body } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { FriendsService } from './friends.service';

@Controller('friends')
@UseGuards(AuthGuard('jwt'))
export class FriendsController {
  constructor(private readonly friendsService: FriendsService) {}

  @Get('search')
  search(@Req() req, @Query('q') q: string) {
    return this.friendsService.searchUsers(q ?? '', req.user.id);
  }

  @Get()
  list(@Req() req) {
    return this.friendsService.listFriends(req.user.id);
  }

  @Get('requests/incoming')
  incoming(@Req() req) {
    return this.friendsService.listIncoming(req.user.id);
  }

  @Get('requests/outgoing')
  outgoing(@Req() req) {
    return this.friendsService.listOutgoing(req.user.id);
  }

  @Get('status/:userId')
  status(@Req() req, @Param('userId') userId: string) {
    return this.friendsService.statusBetween(req.user.id, +userId);
  }

  @Post('request/:userId')
  request(@Req() req, @Param('userId') userId: string) {
    return this.friendsService.sendRequest(req.user.id, +userId);
  }

  @Post('respond/:id')
  respond(@Req() req, @Param('id') id: string, @Body() body: { accept: boolean }) {
    return this.friendsService.respondRequest(req.user.id, +id, body.accept);
  }

  @Delete(':userId')
  remove(@Req() req, @Param('userId') userId: string) {
    return this.friendsService.removeFriend(req.user.id, +userId);
  }
}
