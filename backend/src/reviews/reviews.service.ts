import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Review } from './entities/review.entity';
import { User } from '../users/entities/user.entity';
import { BooksService } from '../books/books.service';

@Injectable()
export class ReviewsService {
  constructor(
    @InjectRepository(Review)
    private reviewsRepository: Repository<Review>,
    private booksService: BooksService,
  ) {}

  async create(user: User, bookData: any, content: string, rating: number) {
    const book = await this.booksService.findOrCreateByGoogleId(bookData);
    const review = this.reviewsRepository.create({ user, book, content, rating });
    return this.reviewsRepository.save(review);
  }

  async findAllByBook(googleId: string) {
    return this.reviewsRepository.find({
      where: { book: { googleId } },
      relations: { user: true },
      order: { createdAt: 'DESC' }
    });
  }
}
