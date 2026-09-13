import 'package:flutter_test/flutter_test.dart';
import 'package:buenas_lecturas_app/screens/profile/reading_stats_screen.dart';

void main() {
  test('ReadingStats parsea la respuesta del backend', () {
    final s = ReadingStats.fromJson({
      'year': 2026,
      'booksRead': 3,
      'pagesRead': 988,
      'booksWithoutPages': 1,
      'averageRating': 3.8,
      'averagePagesPerBook': 494,
      'averageDaysToFinish': null,
      'byMonth': [
        {'month': 1, 'books': 1, 'pages': 688},
      ],
      'topGenres': [
        {'name': 'Science Fiction', 'count': 2},
      ],
      'topAuthors': [],
      'ratingDistribution': [0, 0, 1, 0, 1],
      'longestBook': {'title': 'Dune', 'pages': 688},
      'shortestBook': null,
      'statusCounts': {'read': 4, 'reading': 1, 'wantToRead': 1, 'abandoned': 1},
      'availableYears': [2026, 2025],
    });

    expect(s.booksRead, 3);
    expect(s.averageRating, 3.8);
    expect(s.averageDaysToFinish, isNull);
    expect(s.byMonth.single.pages, 688);
    expect(s.topGenres.single.name, 'Science Fiction');
    expect(s.longestBook?.title, 'Dune');
    expect(s.shortestBook, isNull);
    expect(s.statusCounts['abandoned'], 1);
    expect(s.availableYears, [2026, 2025]);
  });
}
