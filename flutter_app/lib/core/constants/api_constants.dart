import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  // Configuración de URL base dinámica según plataforma (Web / Emulador Android / iOS Simulator / Dispositivo físico)
  static String get baseUrl {
    if (const bool.hasEnvironment('API_URL')) {
      return const String.fromEnvironment('API_URL');
    }
    if (kIsWeb) {
      // En Web, si no hay API_URL (local), probamos localhost
      return 'http://localhost:3000';
    }
    if (Platform.isAndroid) {
      // 10.0.2.2 es la IP del host en el emulador de Android oficial
      return 'http://10.0.2.2:3000';
    }
    // iOS Simulator / macOS / Linux
    return 'http://localhost:3000';
  }

  // Endpoints del backend NestJS
  static const String authGoogle = '/auth/google';
  static const String searchBooks = '/search';
  static const String library = '/library';
  static const String libraryAdd = '/library/add';
  static const String libraryActivities = '/library/activities';
  static const String reviews = '/reviews';
  static const String userProfile = '/users/profile';
}
