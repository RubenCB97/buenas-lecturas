import { Controller, Get, Post, Delete, Body, Param, Query, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { SocialService } from './social.service';

@Controller('social')
@UseGuards(AuthGuard('jwt'))
export class SocialController {
  constructor(private readonly socialService: SocialService) {}

  // ---------------- Feed social ----------------
  @Get('feed')
  feed(@Req() req) {
    return this.socialService.friendsFeed(req.user.id);
  }

  @Post('activity/:id/like')
  toggleLike(@Req() req, @Param('id') id: string) {
    return this.socialService.toggleLike(req.user.id, +id);
  }

  @Get('activity/:id/comments')
  listComments(@Param('id') id: string) {
    return this.socialService.listComments(+id);
  }

  @Post('activity/:id/comments')
  addComment(@Req() req, @Param('id') id: string, @Body() body: { content: string }) {
    return this.socialService.addComment(req.user.id, +id, body.content);
  }

  @Delete('comments/:id')
  deleteComment(@Req() req, @Param('id') id: string) {
    return this.socialService.deleteComment(req.user.id, +id);
  }

  // ---------------- Citas ----------------
  @Post('quotes')
  createQuote(@Req() req, @Body() body: { book: any; text: string; page?: number }) {
    return this.socialService.addQuote(req.user.id, body.book, body.text, body.page);
  }

  @Get('quotes/book/:googleId')
  bookQuotes(@Param('googleId') googleId: string) {
    return this.socialService.listQuotesForBook(googleId);
  }

  @Get('quotes/mine')
  myQuotes(@Req() req) {
    return this.socialService.listMyQuotes(req.user.id);
  }

  @Get('quotes/feed')
  quotesFeed(@Req() req) {
    return this.socialService.friendsQuotesFeed(req.user.id);
  }

  @Delete('quotes/:id')
  deleteQuote(@Req() req, @Param('id') id: string) {
    return this.socialService.deleteQuote(req.user.id, +id);
  }

  // ---------------- Recomendaciones ----------------
  @Post('recommend/:toUserId')
  recommend(@Req() req, @Param('toUserId') toUserId: string, @Body() body: { book: any; note?: string }) {
    return this.socialService.sendRecommendation(req.user.id, +toUserId, body.book, body.note);
  }

  @Get('recommendations')
  myRecommendations(@Req() req) {
    return this.socialService.myRecommendations(req.user.id);
  }

  @Post('recommendations/:id/seen')
  markSeen(@Req() req, @Param('id') id: string) {
    return this.socialService.markRecommendationSeen(req.user.id, +id);
  }

  // ---------------- Estanterías ----------------
  @Post('shelves')
  createShelf(@Req() req, @Body() body: { name: string; icon?: string }) {
    return this.socialService.createShelf(req.user.id, body.name, body.icon);
  }

  @Get('shelves')
  myShelves(@Req() req) {
    return this.socialService.myShelves(req.user.id);
  }

  @Post('shelves/:id/add')
  addToShelf(@Req() req, @Param('id') id: string, @Body() body: { book: any }) {
    return this.socialService.addBookToShelf(req.user.id, +id, body.book);
  }

  @Delete('shelves/:id/books/:bookId')
  removeFromShelf(@Req() req, @Param('id') id: string, @Param('bookId') bookId: string) {
    return this.socialService.removeBookFromShelf(req.user.id, +id, +bookId);
  }

  @Delete('shelves/:id')
  deleteShelf(@Req() req, @Param('id') id: string) {
    return this.socialService.deleteShelf(req.user.id, +id);
  }

  // ---------------- Perfiles / comparativa ----------------
  @Get('users/:id/profile')
  publicProfile(@Req() req, @Param('id') id: string) {
    return this.socialService.publicProfile(req.user.id, +id);
  }

  @Get('users/:id/compare')
  compare(@Req() req, @Param('id') id: string) {
    return this.socialService.compareWith(req.user.id, +id);
  }
}
