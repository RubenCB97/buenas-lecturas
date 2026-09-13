import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../network/api_client.dart';
import 'firebase_config.dart';

/// Notificaciones push en Android e iOS con Firebase Cloud Messaging.
/// En la web no hace nada: allí ya están las notificaciones internas.
class PushNotifications {
  PushNotifications._();

  static bool _initialized = false;
  static StreamSubscription<String>? _tokenSub;
  static StreamSubscription<RemoteMessage>? _foregroundSub;
  static StreamSubscription<RemoteMessage>? _openedSub;

  static bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Activa las notificaciones para el usuario con sesión iniciada.
  ///
  /// [onForeground] se llama al llegar un aviso con la app abierta y
  /// [onOpen] al tocar una notificación, con los datos que envía el servidor.
  static Future<void> init({
    required void Function(RemoteMessage message) onForeground,
    required void Function(Map<String, dynamic> data) onOpen,
  }) async {
    if (!_isMobile) return;
    final options = FirebaseConfig.optionsFor(isIOS: Platform.isIOS);
    if (options == null) {
      developer.log('Push desactivado: faltan los datos de Firebase (--dart-define)');
      return;
    }

    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: options);
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      // En iOS, mostrar el aviso también con la app abierta
      await messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

      final token = await messaging.getToken();
      if (token != null) await _register(token);

      if (!_initialized) {
        _initialized = true;
        _tokenSub = messaging.onTokenRefresh.listen(_register);
        _foregroundSub = FirebaseMessaging.onMessage.listen(onForeground);
        _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((m) => onOpen(m.data));
        // La app estaba cerrada y se abrió tocando una notificación
        final initial = await messaging.getInitialMessage();
        if (initial != null) onOpen(initial.data);
      }
    } catch (e) {
      developer.log('No se pudieron activar las notificaciones push: $e');
    }
  }

  static Future<void> _register(String token) async {
    await ApiClient().post('/notifications/devices', body: {
      'token': token,
      'platform': Platform.isIOS ? 'ios' : 'android',
    });
  }

  /// Deja de recibir notificaciones en este móvil (al cerrar sesión).
  static Future<void> unregister() async {
    if (!_isMobile || Firebase.apps.isEmpty) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token != null) {
        await ApiClient().post('/notifications/devices/remove', body: {'token': token});
      }
      await messaging.deleteToken();
    } catch (e) {
      developer.log('No se pudo dar de baja el dispositivo: $e');
    } finally {
      await _tokenSub?.cancel();
      await _foregroundSub?.cancel();
      await _openedSub?.cancel();
      _tokenSub = _foregroundSub = _openedSub = null;
      _initialized = false;
    }
  }
}
