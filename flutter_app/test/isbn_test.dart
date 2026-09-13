import 'package:flutter_test/flutter_test.dart';
import 'package:buenas_lecturas_app/core/utils/isbn.dart';

void main() {
  test('acepta ISBN-13 e ISBN-10 válidos', () {
    expect(Isbn.normalize('978-0-441-17271-9'), '9780441172719');
    expect(Isbn.normalize('0441172717'), '0441172717');
    expect(Isbn.normalize('080442957x'), '080442957X');
  });

  test('rechaza dígito de control incorrecto y códigos que no son libros', () {
    expect(Isbn.normalize('9780441172718'), isNull);
    expect(Isbn.normalize('8410000000001'), isNull);
    expect(Isbn.normalize('51299'), isNull);
  });
}
