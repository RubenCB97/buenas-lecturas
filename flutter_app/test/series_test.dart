import 'package:flutter_test/flutter_test.dart';
import 'package:buenas_lecturas_app/core/utils/series.dart';
import 'package:buenas_lecturas_app/models/book_model.dart';
import 'package:buenas_lecturas_app/models/user_book_model.dart';

UserBookModel ub(int id, String title, ReadingStatus status) =>
    UserBookModel(id: id, book: BookModel(title: title, authors: ['Autora']), status: status);

void main() {
  group('Series.parse', () {
    test('detecta los formatos habituales', () {
      final a = Series.parse('Dune (Dune, #1)')!;
      expect([a.name, a.number], ['Dune', 1]);
      final b = Series.parse('The Novella (Series Name, #0.5)')!;
      expect([b.name, b.numberLabel], ['Series Name', '0.5']);
      final c = Series.parse('El pozo de la ascensión (Nacidos de la bruma, Libro 2)')!;
      expect([c.name, c.number], ['Nacidos de la bruma', 2]);
      final d = Series.parse('Herejes de Dune (Las crónicas de Dune 5)')!;
      expect([d.name, d.number], ['Las crónicas de Dune', 5]);
    });

    test('ignora títulos sin saga, años y ediciones', () {
      expect(Series.parse('1984'), isNull);
      expect(Series.parse('Cien años de soledad (Edición 2017)'), isNull);
      expect(Series.parse('Don Quijote (Edición ilustrada 2)'), isNull);
    });

    test('agrupa nombres con tildes o mayúsculas distintas', () {
      expect(Series.parse('A (Crónicas, #1)')!.key, Series.parse('B (cronicas, #2)')!.key);
    });
  });

  group('Series.fromLibrary', () {
    test('calcula el progreso, el siguiente y los que faltan', () {
      final series = Series.fromLibrary([
        ub(1, 'Uno (Saga, #1)', ReadingStatus.read),
        ub(2, 'Dos (Saga, #2)', ReadingStatus.read),
        ub(4, 'Cuatro (Saga, #4)', ReadingStatus.wantToRead),
        ub(9, 'Suelto', ReadingStatus.read),
      ]);

      expect(series, hasLength(1));
      final s = series.single;
      expect(s.name, 'Saga');
      expect(s.readCount, 2);
      expect(s.nextNumber, 3);
      expect(s.nextBook, isNull); // el #3 no está en la biblioteca
      expect(s.missingNumbers, [3]);
      expect(s.isComplete, isFalse);
    });

    test('propone como siguiente un libro que ya tiene', () {
      final s = Series.fromLibrary([
        ub(1, 'Uno (Saga, #1)', ReadingStatus.read),
        ub(2, 'Dos (Saga, #2)', ReadingStatus.reading),
      ]).single;
      expect(s.nextNumber, 2);
      expect(s.nextBook?.userBook.id, 2);
    });

    test('saga completa y ediciones repetidas', () {
      final s = Series.fromLibrary([
        ub(1, 'Uno (Saga, #1)', ReadingStatus.wantToRead),
        ub(2, 'Uno, otra edición (Saga, #1)', ReadingStatus.read),
        ub(3, 'Dos (Saga, #2)', ReadingStatus.read),
      ]).single;
      expect(s.books, hasLength(2));
      expect(s.isComplete, isTrue);
      expect(s.nextNumber, 3);
    });
  });
}
