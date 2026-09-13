import 'package:flutter_test/flutter_test.dart';
import 'package:buenas_lecturas_app/core/push/firebase_config.dart';

void main() {
  test('sin datos de Firebase no hay configuración', () {
    expect(FirebaseConfig.build(apiKey: '', projectId: 'p', senderId: '1', appId: 'a'), isNull);
    expect(FirebaseConfig.optionsFor(isIOS: false), isNull);
  });

  test('con todos los datos crea las opciones', () {
    final options = FirebaseConfig.build(
      apiKey: ' key ',
      projectId: 'buenas-lecturas',
      senderId: '123',
      appId: '1:123:ios:abc',
      iosBundleId: 'com.buenaslecturas.app',
    )!;
    expect(options.apiKey, 'key');
    expect(options.projectId, 'buenas-lecturas');
    expect(options.messagingSenderId, '123');
    expect(options.iosBundleId, 'com.buenaslecturas.app');
  });
}
