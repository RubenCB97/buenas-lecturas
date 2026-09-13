import 'dart:convert';
import '../../models/user_model.dart';

/// Resultado del login con Google que el servidor devuelve a la app móvil
/// como `buenaslecturas://auth?token=…&user=…` (o `?error=…`).
class GoogleAuthCallback {
  static const String scheme = 'buenaslecturas';

  final String? token;
  final UserModel? user;
  final String? error;

  const GoogleAuthCallback._({this.token, this.user, this.error});

  bool get isSuccess => token != null && user != null;

  static GoogleAuthCallback parse(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != scheme) {
      return const GoogleAuthCallback._(error: 'invalid_callback');
    }
    final params = uri.queryParameters;
    if (params['error'] != null) return GoogleAuthCallback._(error: params['error']);

    final token = params['token'];
    final userJson = params['user'];
    if (token == null || token.isEmpty || userJson == null) {
      return const GoogleAuthCallback._(error: 'missing_session');
    }
    try {
      final user = UserModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      return GoogleAuthCallback._(token: token, user: user);
    } catch (_) {
      return const GoogleAuthCallback._(error: 'invalid_user');
    }
  }
}
