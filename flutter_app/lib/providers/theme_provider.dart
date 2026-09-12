import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { system, light, dark }

extension AppThemeModeX on AppThemeMode {
  String get storageKey {
    switch (this) {
      case AppThemeMode.light:
        return 'light';
      case AppThemeMode.dark:
        return 'dark';
      case AppThemeMode.system:
        return 'system';
    }
  }

  String get label {
    switch (this) {
      case AppThemeMode.light:
        return 'Claro';
      case AppThemeMode.dark:
        return 'Oscuro';
      case AppThemeMode.system:
        return 'Según el sistema';
    }
  }

  IconData get icon {
    switch (this) {
      case AppThemeMode.light:
        return Icons.light_mode_rounded;
      case AppThemeMode.dark:
        return Icons.dark_mode_rounded;
      case AppThemeMode.system:
        return Icons.brightness_auto_rounded;
    }
  }

  ThemeMode toFlutter() {
    switch (this) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  static AppThemeMode fromString(String? s) {
    switch (s) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      case 'system':
      default:
        return AppThemeMode.system;
    }
  }
}

/// Gestor de tema (claro / oscuro / sistema) con persistencia en SharedPreferences.
class ThemeProvider extends ChangeNotifier {
  static const String _prefsKey = 'app_theme_mode';

  AppThemeMode _mode = AppThemeMode.system;
  bool _loaded = false;

  AppThemeMode get mode => _mode;
  bool get isLoaded => _loaded;
  ThemeMode get themeMode => _mode.toFlutter();

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      _mode = AppThemeModeX.fromString(saved);
    } catch (_) {
      _mode = AppThemeMode.system;
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> setMode(AppThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.storageKey);
    } catch (_) {/* no bloqueamos si no se pudo persistir */}
  }
}
