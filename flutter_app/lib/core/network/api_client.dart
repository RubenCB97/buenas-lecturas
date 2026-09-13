import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? errorMessage;
  final int? statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.errorMessage,
    this.statusCode,
  });
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  static const String tokenKey = 'access_token';
  static const String userKey = 'user_data';

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(tokenKey);
  }

  Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
  }

  Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
    await prefs.remove(userKey);
  }

  Future<Map<String, String>> _getHeaders({bool requiresAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (requiresAuth) {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // GET request
  Future<ApiResponse<dynamic>> get(String endpoint, {bool requiresAuth = true, Map<String, dynamic>? queryParams}) async {
    try {
      var uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
      if (queryParams != null && queryParams.isNotEmpty) {
        final stringParams = queryParams.map((key, value) => MapEntry(key, value.toString()));
        uri = uri.replace(queryParameters: stringParams);
      }

      final headers = await _getHeaders(requiresAuth: requiresAuth);
      developer.log('GET: $uri');
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));

      return _handleResponse(response);
    } catch (e) {
      developer.log('GET Error [$endpoint]: $e');
      return ApiResponse(success: false, errorMessage: e.toString());
    }
  }

  // POST request
  Future<ApiResponse<dynamic>> post(String endpoint, {dynamic body, bool requiresAuth = true}) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final jsonBody = body != null ? jsonEncode(body) : null;

      developer.log('POST: $uri, body: $jsonBody');
      final response = await http.post(uri, headers: headers, body: jsonBody).timeout(const Duration(seconds: 20));

      return _handleResponse(response);
    } catch (e) {
      developer.log('POST Error [$endpoint]: $e');
      return ApiResponse(success: false, errorMessage: e.toString());
    }
  }

  // PATCH request
  Future<ApiResponse<dynamic>> patch(String endpoint, {dynamic body, bool requiresAuth = true}) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final jsonBody = body != null ? jsonEncode(body) : null;

      developer.log('PATCH: $uri, body: $jsonBody');
      final response = await http.patch(uri, headers: headers, body: jsonBody).timeout(const Duration(seconds: 10));

      return _handleResponse(response);
    } catch (e) {
      developer.log('PATCH Error [$endpoint]: $e');
      return ApiResponse(success: false, errorMessage: e.toString());
    }
  }

  // DELETE request
  Future<ApiResponse<dynamic>> delete(String endpoint, {bool requiresAuth = true}) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
      final headers = await _getHeaders(requiresAuth: requiresAuth);

      developer.log('DELETE: $uri');
      final response = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 10));

      return _handleResponse(response);
    } catch (e) {
      developer.log('DELETE Error [$endpoint]: $e');
      return ApiResponse(success: false, errorMessage: e.toString());
    }
  }

  /// Sube un archivo con multipart/form-data.
  ///
  /// Usa bytes en memoria para que funcione igual en móvil y en Flutter Web
  /// (donde no hay acceso al sistema de archivos).
  Future<ApiResponse<dynamic>> uploadFile(
    String endpoint, {
    required String fieldName,
    required List<int> bytes,
    required String filename,
    String? contentType,
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
      final request = http.MultipartRequest('POST', uri);

      if (requiresAuth) {
        final token = await getToken();
        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $token';
        }
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          bytes,
          filename: filename,
          contentType: contentType != null ? MediaType.parse(contentType) : null,
        ),
      );

      developer.log('UPLOAD: $uri ($filename, ${bytes.length} bytes)');
      final streamed = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamed);

      return _handleResponse(response);
    } catch (e) {
      developer.log('UPLOAD Error [$endpoint]: $e');
      return ApiResponse(success: false, errorMessage: e.toString());
    }
  }

  ApiResponse<dynamic> _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) {
        return ApiResponse(success: true, statusCode: statusCode, data: null);
      }
      try {
        final data = jsonDecode(response.body);
        return ApiResponse(success: true, statusCode: statusCode, data: data);
      } catch (_) {
        return ApiResponse(success: true, statusCode: statusCode, data: response.body);
      }
    } else {
      String message = 'Error $statusCode';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body.containsKey('message')) {
          message = body['message'] is List ? (body['message'] as List).join(', ') : body['message'].toString();
        }
      } catch (_) {
        message = response.body.isNotEmpty ? response.body : 'Error en la petición ($statusCode)';
      }
      return ApiResponse(success: false, statusCode: statusCode, errorMessage: message);
    }
  }
}
