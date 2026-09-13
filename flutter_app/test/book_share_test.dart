import 'package:flutter_test/flutter_test.dart';
import 'package:buenas_lecturas_app/core/utils/book_share.dart';
import 'package:buenas_lecturas_app/models/book_model.dart';

void main() {
  test('enlace de Google Books para ids de volumen', () {
    final b = BookModel(title: 'Dune', authors: ['Frank Herbert'], googleId: 'B1hSG45JCX4C');
    expect(BookShare.publicLink(b), 'https://books.google.com/books?id=B1hSG45JCX4C');
  });

  test('enlace de Open Library para obras OL…W', () {
    final b = BookModel(title: 'Atomic Habits', googleId: 'OL17930368W');
    expect(BookShare.publicLink(b), 'https://openlibrary.org/works/OL17930368W');
  });

  test('cae a ISBN si el id es interno', () {
    final b = BookModel(title: 'X', googleId: 'custom_123', isbn: '9788408175216');
    expect(BookShare.publicLink(b), 'https://openlibrary.org/isbn/9788408175216');
  });

  test('sin enlace si no hay identificadores', () {
    final b = BookModel(title: 'X', googleId: 'custom_123');
    expect(BookShare.publicLink(b), isNull);
    expect(BookShare.buildText(b), contains(BookShare.appUrl));
  });

  test('el texto incluye título, autor y enlace', () {
    final text = BookShare.buildText(
      BookModel(title: 'Dune', authors: ['Frank Herbert'], googleId: 'B1hSG45JCX4C'),
    );
    expect(text, contains('«Dune»'));
    expect(text, contains('de Frank Herbert'));
    expect(text, contains('books.google.com'));
  });
}
