import 'package:firebase_core/firebase_core.dart';

/// Configuración de Firebase para las notificaciones push del móvil.
///
/// Se pasa al compilar, sin guardar claves en el repositorio:
///   flutter build apk --dart-define-from-file=firebase.json
/// Si falta algún dato, la app funciona igual pero sin notificaciones push.
class FirebaseConfig {
  FirebaseConfig._();

  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  /// Clave propia de iOS; si no se indica, se usa FIREBASE_API_KEY.
  static const _iosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const _androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const _iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

  /// Opciones para la plataforma, o `null` si no está configurada.
  static FirebaseOptions? optionsFor({required bool isIOS}) => build(
        apiKey: isIOS && _iosApiKey.isNotEmpty ? _iosApiKey : _apiKey,
        projectId: _projectId,
        senderId: _senderId,
        appId: isIOS ? _iosAppId : _androidAppId,
        iosBundleId: isIOS ? _iosBundleId : null,
      );

  static FirebaseOptions? build({
    required String apiKey,
    required String projectId,
    required String senderId,
    required String appId,
    String? iosBundleId,
  }) {
    if ([apiKey, projectId, senderId, appId].any((v) => v.trim().isEmpty)) return null;
    return FirebaseOptions(
      apiKey: apiKey.trim(),
      appId: appId.trim(),
      messagingSenderId: senderId.trim(),
      projectId: projectId.trim(),
      iosBundleId: (iosBundleId?.trim().isEmpty ?? true) ? null : iosBundleId!.trim(),
    );
  }
}
