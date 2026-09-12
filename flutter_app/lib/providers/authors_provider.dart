import 'dart:async';
import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../models/author_model.dart';

class AuthorsProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<AuthorModel> _searchResults = [];
  bool _isSearching = false;
  String _query = '';
  Timer? _debounce;

  // Caché de fichas ya cargadas para no repetir peticiones al volver atrás
  final Map<String, AuthorModel> _detailCache = {};
  AuthorModel? _current;
  bool _isLoadingDetail = false;

  List<AuthorModel> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  String get query => _query;
  AuthorModel? get current => _current;
  bool get isLoadingDetail => _isLoadingDetail;

  void onQueryChanged(String q) {
    _query = q;
    _debounce?.cancel();

    if (q.trim().length < 2) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();
    _debounce = Timer(const Duration(milliseconds: 400), () => _executeSearch(q));
  }

  Future<void> _executeSearch(String q) async {
    try {
      final r = await _apiClient.get('/authors/search', queryParams: {'q': q});
      if (r.success && r.data is List) {
        _searchResults = (r.data as List).map((e) => AuthorModel.fromJson(e)).toList();
      } else {
        _searchResults = [];
      }
    } catch (_) {
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _query = '';
    _searchResults = [];
    _isSearching = false;
    _debounce?.cancel();
    notifyListeners();
  }

  /// Carga la ficha del autor. Sirve de caché si ya se consultó antes.
  Future<AuthorModel?> loadAuthor(String name) async {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return null;

    if (_detailCache.containsKey(key)) {
      _current = _detailCache[key];
      notifyListeners();
      return _current;
    }

    _isLoadingDetail = true;
    _current = null;
    notifyListeners();

    try {
      final r = await _apiClient.get('/authors/${Uri.encodeComponent(name.trim())}');
      if (r.success && r.data is Map<String, dynamic>) {
        final author = AuthorModel.fromJson(r.data as Map<String, dynamic>);
        _detailCache[key] = author;
        _current = author;
      }
    } catch (_) {
      _current = null;
    } finally {
      _isLoadingDetail = false;
      notifyListeners();
    }
    return _current;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
