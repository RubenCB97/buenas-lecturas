import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { RATING_ACTIVITY_DELAY_MS, UserBooksService } from './user-books.service';
import { UserBook } from './entities/user-book.entity';
import { Activity } from './entities/activity.entity';
import { BooksService } from '../books/books.service';

describe('UserBooksService', () => {
  let service: UserBooksService;
  let userBook: any;
  const activities: any[] = [];

  beforeEach(async () => {
    jest.useFakeTimers();
    activities.length = 0;
    userBook = { id: 1, rating: null, user: { id: 7 }, book: { id: 42 } };

    const userBooksRepo = {
      findOne: jest.fn(async () => userBook),
      save: jest.fn(async (ub) => ub),
    };
    const activityRepo = {
      create: jest.fn((a) => a),
      save: jest.fn(async (a) => activities.push(a)),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UserBooksService,
        { provide: getRepositoryToken(UserBook), useValue: userBooksRepo },
        { provide: getRepositoryToken(Activity), useValue: activityRepo },
        { provide: BooksService, useValue: {} },
      ],
    }).compile();

    service = module.get<UserBooksService>(UserBooksService);
  });

  afterEach(() => {
    service.onModuleDestroy();
    jest.useRealTimers();
  });

  it('publica en Comunidad solo la última nota tras 5 s sin cambios', async () => {
    await service.updateBookRating(7, 42, 2);
    await service.updateBookRating(7, 42, 3.5);
    await jest.advanceTimersByTimeAsync(RATING_ACTIVITY_DELAY_MS - 1);
    await service.updateBookRating(7, 42, 4.5);
    await jest.advanceTimersByTimeAsync(RATING_ACTIVITY_DELAY_MS - 1);
    expect(activities).toHaveLength(0);

    await jest.advanceTimersByTimeAsync(1);
    expect(activities).toHaveLength(1);
    expect(activities[0]).toMatchObject({ action: 'RATED', details: 'Puntuación: 4,5 estrellas' });
  });

  it('no publica nada si la nota se quita antes de los 5 s', async () => {
    await service.updateBookRating(7, 42, 4);
    await service.updateBookRating(7, 42, 0);
    await jest.advanceTimersByTimeAsync(RATING_ACTIVITY_DELAY_MS);
    expect(activities).toHaveLength(0);
  });
});
