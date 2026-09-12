import { Controller, Get, Post, Body, Param, UseGuards, Req } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ReviewsService } from './reviews.service';

@Controller('reviews')
export class ReviewsController {
  constructor(private readonly reviewsService: ReviewsService) {}

  @Post()
  @UseGuards(AuthGuard('jwt'))
  async create(@Req() req, @Body() body: { book: any, content: string, rating: number }) {
    return this.reviewsService.create(req.user, body.book, body.content, body.rating);
  }

  @Get(':googleId')
  async findAllByBook(@Param('googleId') googleId: string) {
    return this.reviewsService.findAllByBook(googleId);
  }
}
