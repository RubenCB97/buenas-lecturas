import 'package:flutter_test/flutter_test.dart';
import 'package:buenas_lecturas_app/core/utils/deep_link.dart';

void main() {
  test('extrae el id de /libro/<id> y de ?libro=<id>', () {
    expect(DeepLink.bookIdFromUri(Uri.parse('https://x.es/libro/B1hSG45JCX4C')), 'B1hSG45JCX4C');
    expect(DeepLink.bookIdFromUri(Uri.parse('https://x.es/libro/OL17930368W/')), 'OL17930368W');
    expect(DeepLink.bookIdFromUri(Uri.parse('https://x.es/?libro=gr_234225')), 'gr_234225');
  });

  test('ignora otras rutas e ids con caracteres raros', () {
    expect(DeepLink.bookIdFromUri(Uri.parse('https://x.es/')), isNull);
    expect(DeepLink.bookIdFromUri(Uri.parse('https://x.es/perfil/123')), isNull);
    expect(DeepLink.bookIdFromUri(Uri.parse('https://x.es/?libro=../../etc')), isNull);
  });

  test('genera el enlace a un libro', () {
    expect(DeepLink.bookUrl('OL17930368W'), '${DeepLink.appUrl}/libro/OL17930368W');
  });
}
