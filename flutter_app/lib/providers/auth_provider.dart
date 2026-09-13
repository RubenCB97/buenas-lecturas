import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/api_client.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  
  UserModel? _currentUser;
  bool _isLoading = true;
  String? _token;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    initAuth();
  }

  Future<void> initAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      // Interceptar callback de Google OAuth en Web
      if (Uri.base.queryParameters.containsKey('token') && Uri.base.queryParameters.containsKey('user')) {
        final urlToken = Uri.base.queryParameters['token']!;
        final userStr = Uri.base.queryParameters['user']!;
        try {
          final decodedUser = UserModel.fromJson(jsonDecode(userStr));
          await prefs.setString(ApiClient.tokenKey, urlToken);
          await prefs.setString(ApiClient.userKey, jsonEncode(decodedUser.toJson()));
          // Si estamos en Web, idealmente limpiaríamos la URL, pero con setSession basta para entrar
        } catch (e) {
          debugPrint('Error parseando usuario de la URL: $e');
        }
      }

      _token = prefs.getString(ApiClient.tokenKey);
      final userJson = prefs.getString(ApiClient.userKey);

      if (_token != null && userJson != null) {
        _currentUser = UserModel.fromJson(jsonDecode(userJson));
        // Refrescar perfil desde el backend
        await fetchProfile();
      }
    } catch (e) {
      debugPrint('Error initAuth: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchProfile() async {
    if (!isAuthenticated) return;
    final response = await _apiClient.get('/users/profile');
    if (response.success && response.data != null) {
      _currentUser = UserModel.fromJson(response.data);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ApiClient.userKey, jsonEncode(_currentUser!.toJson()));
      notifyListeners();
    }
  }

  Future<void> setSession(String token, UserModel user) async {
    _token = token;
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiClient.tokenKey, token);
    await prefs.setString(ApiClient.userKey, jsonEncode(user.toJson()));
    notifyListeners();
  }

  // Inicio de sesión de desarrollo / demostración conectada al backend NestJS
  Future<void> loginAsDemoUser() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.post('/auth/dev-login', requiresAuth: false);
      if (response.success && response.data != null) {
        final token = response.data['access_token']?.toString() ?? '';
        final userData = response.data['user'] as Map<String, dynamic>;
        final user = UserModel.fromJson(userData);
        await setSession(token, user);
      } else {
        _errorMessage = 'No se pudo conectar al servidor. Asegúrate de que el backend esté arrancado.';
      }
    } catch (e) {
      _errorMessage = 'Error de conexión: $e';
      debugPrint('Error loginAsDemoUser: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({String? firstName, String? bio, String? favoriteGenre}) async {
    if (_currentUser == null) return;
    
    final body = <String, dynamic>{};
    if (firstName != null) body['firstName'] = firstName;
    if (bio != null) body['bio'] = bio;
    if (favoriteGenre != null) body['favoriteGenre'] = favoriteGenre;

    final response = await _apiClient.patch('/users/profile', body: body);
    if (response.success && response.data != null) {
      _currentUser = UserModel.fromJson(response.data);
    } else {
      _currentUser = _currentUser!.copyWith(
        firstName: firstName,
        bio: bio,
        favoriteGenre: favoriteGenre,
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiClient.userKey, jsonEncode(_currentUser!.toJson()));
    notifyListeners();
  }

  /// Sube una nueva foto de perfil. Devuelve `null` si fue bien, o el mensaje
  /// de error para mostrarlo en la UI.
  Future<String?> uploadAvatar({
    required List<int> bytes,
    required String filename,
    String? contentType,
  }) async {
    if (_currentUser == null) return 'No hay sesión activa';

    final response = await _apiClient.uploadFile(
      '/users/avatar',
      fieldName: 'avatar',
      bytes: bytes,
      filename: filename,
      contentType: contentType,
    );

    if (response.success && response.data is Map<String, dynamic>) {
      _currentUser = UserModel.fromJson(response.data);
      await _persistUser();
      notifyListeners();
      return null;
    }
    return response.errorMessage ?? 'No se pudo subir la imagen';
  }

  /// Quita la foto de perfil y vuelve al avatar con la inicial.
  Future<String?> removeAvatar() async {
    if (_currentUser == null) return 'No hay sesión activa';

    final response = await _apiClient.delete('/users/avatar');
    if (response.success && response.data is Map<String, dynamic>) {
      _currentUser = UserModel.fromJson(response.data);
      await _persistUser();
      notifyListeners();
      return null;
    }
    return response.errorMessage ?? 'No se pudo quitar la imagen';
  }

  /// Usa una imagen alojada en una URL externa como avatar.
  Future<String?> setAvatarUrl(String url) async {
    if (_currentUser == null) return 'No hay sesión activa';

    final response = await _apiClient.patch('/users/profile', body: {'picture': url});
    if (response.success && response.data is Map<String, dynamic>) {
      _currentUser = UserModel.fromJson(response.data);
      await _persistUser();
      notifyListeners();
      return null;
    }
    return response.errorMessage ?? 'No se pudo actualizar el avatar';
  }

  Future<void> _persistUser() async {
    if (_currentUser == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiClient.userKey, jsonEncode(_currentUser!.toJson()));
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    _errorMessage = null;
    await _apiClient.removeToken();
    notifyListeners();
  }
}
