import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:buenas_lecturas_app/core/utils/google_auth_callback.dart';

void main() {
  test('extrae token y usuario de la vuelta del login', () {
    final user = jsonEncode({'id': 1, 'email': 'a@b.es', 'firstName': 'Rubén'});
    final cb = GoogleAuthCallback.parse('buenaslecturas://auth?token=abc.def&user=${Uri.encodeComponent(user)}');
    expect(cb.isSuccess, isTrue);
    expect(cb.token, 'abc.def');
    expect(cb.user!.email, 'a@b.es');
  });

  test('detecta errores y URLs ajenas', () {
    expect(GoogleAuthCallback.parse('buenaslecturas://auth?error=auth_failed').error, 'auth_failed');
    expect(GoogleAuthCallback.parse('https://evil.es/auth?token=x&user={}').isSuccess, isFalse);
    expect(GoogleAuthCallback.parse('buenaslecturas://auth?token=x&user=noesjson').isSuccess, isFalse);
  });
}
