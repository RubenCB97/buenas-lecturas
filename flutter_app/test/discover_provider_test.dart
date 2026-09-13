import 'package:flutter_test/flutter_test.dart';
import 'package:buenas_lecturas_app/providers/discover_provider.dart';

void main() {
  test('RecentReleases parsea libros, ventana y fecha de inicio', () {
    final r = RecentReleases.fromJson({
      'books': [
        {'title': 'Nunca estuviste solo', 'authors': ['Albert Espinosa']},
      ],
      'windowMonths': 3,
      'since': '2026-07',
    });
    expect(r.books.single.title, 'Nunca estuviste solo');
    expect(r.windowMonths, 3);
    expect(r.since, '2026-07');
  });

  test('RecentReleases tolera respuesta vacía', () {
    final r = RecentReleases.fromJson({});
    expect(r.books, isEmpty);
    expect(r.windowMonths, 0);
  });

  test('ForYouSection parsea semilla, motivo y nota con medio punto', () {
    final s = ForYouSection.fromJson({
      'seed': {'title': 'Dune', 'authors': ['Frank Herbert']},
      'reason': 'rated',
      'rating': 4.5,
      'books': [
        {'title': 'Fahrenheit 451'},
        {'title': 'Brave New World'},
      ],
    });
    expect(s.seed.title, 'Dune');
    expect(s.reason, 'rated');
    expect(s.rating, 4.5);
    expect(s.books.map((b) => b.title), ['Fahrenheit 451', 'Brave New World']);
  });
}
