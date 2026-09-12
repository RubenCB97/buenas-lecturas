import 'dart:async';
import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../models/book_model.dart';

class ExploreProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<BookModel> _trendingBooks = [];
  List<BookModel> _recommendedBooks = [];
  List<BookModel> _newReleases = [];
  List<BookModel> _searchResults = [];

  bool _isLoadingTrending = false;
  bool _isLoadingRecommended = false;
  bool _isLoadingNewReleases = false;
  bool _isSearching = false;

  // Mercado y ventana temporal de las tendencias
  String _trendingRegion = 'ES';
  String _trendingPeriod = 'weekly';
  String _searchQuery = '';
  String _selectedCategory = 'Todos';
  Timer? _debounceTimer;

  List<BookModel> get trendingBooks => _trendingBooks;
  List<BookModel> get recommendedBooks => _recommendedBooks;
  List<BookModel> get newReleases => _newReleases;
  List<BookModel> get searchResults => _searchResults;
  bool get isLoadingTrending => _isLoadingTrending;
  bool get isLoadingRecommended => _isLoadingRecommended;
  bool get isLoadingNewReleases => _isLoadingNewReleases;
  bool get isSearching => _isSearching;
  String get trendingRegion => _trendingRegion;
  String get trendingPeriod => _trendingPeriod;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;

  final List<String> categories = const [
    'Todos',
    'Ciencia Ficción',
    'Fantasía',
    'Clásicos',
    'Filosofía',
    'Misterio & Thriller',
    'Historia',
    'Desarrollo Personal',
  ];

  ExploreProvider() {
    initFeed();
  }

  Future<void> initFeed() async {
    fetchTrending();
    fetchRecommended();
    fetchNewReleases();
  }

  /// Carrusel de novedades del año en la home (primera página).
  Future<void> fetchNewReleases({String region = 'GLOBAL'}) async {
    _isLoadingNewReleases = true;
    notifyListeners();
    try {
      final response = await _apiClient.get('/search/new-releases', queryParams: {
        'region': region,
        'sort': 'readinglog',
        'limit': 20,
      });
      // El endpoint devuelve { books: [...], total, hasMore, ... }
      final data = response.data;
      if (response.success && data is Map<String, dynamic> && data['books'] is List) {
        _newReleases = (data['books'] as List).map((item) => BookModel.fromJson(item)).toList();
      } else if (response.success && data is List) {
        // Compatibilidad con la forma antigua (array plano)
        _newReleases = data.map((item) => BookModel.fromJson(item)).toList();
      }
    } catch (_) {
      // sin conexión
    } finally {
      _isLoadingNewReleases = false;
      notifyListeners();
    }
  }

  void selectCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
    if (category == 'Todos') {
      fetchRecommended();
    } else {
      searchCategoryBooks(category);
    }
  }

  /// Tendencias reales basadas en actividad de lectores (Open Library),
  /// segmentadas por mercado: 'ES' (español) o 'US' (inglés).
  Future<void> fetchTrending({String? region}) async {
    if (region != null && region != _trendingRegion) {
      _trendingRegion = region;
    }
    _isLoadingTrending = true;
    notifyListeners();

    try {
      final response = await _apiClient.get('/search/trending', queryParams: {
        'region': _trendingRegion,
        'period': _trendingPeriod,
      });
      if (response.success && response.data is List && (response.data as List).isNotEmpty) {
        final list = response.data as List;
        _trendingBooks = list.map((item) => BookModel.fromJson(item)).toList();
      } else {
        _trendingBooks = [];
      }
    } catch (_) {
      // Sin conexión al backend: dejar lista vacía
    } finally {
      _isLoadingTrending = false;
      notifyListeners();
    }
  }

  /// Cambia el mercado de las tendencias y recarga.
  Future<void> setTrendingRegion(String region) async {
    if (region == _trendingRegion) return;
    _trendingRegion = region;
    notifyListeners();
    await fetchTrending();
  }

  /// Cambia el periodo (daily/weekly/monthly/yearly) y recarga.
  Future<void> setTrendingPeriod(String period) async {
    if (period == _trendingPeriod) return;
    _trendingPeriod = period;
    notifyListeners();
    await fetchTrending();
  }

  Future<void> fetchRecommended() async {
    _isLoadingRecommended = true;
    notifyListeners();

    try {
      final response = await _apiClient.get('/search', queryParams: {'q': 'ficcion contemporanea'});
      if (response.success && response.data is List && (response.data as List).isNotEmpty) {
        final list = response.data as List;
        _recommendedBooks = list.map((item) => BookModel.fromJson(item)).toList();
      }
    } catch (_) {
      // Sin conexión al backend: dejar lista vacía
    } finally {
      _isLoadingRecommended = false;
      notifyListeners();
    }
  }

  Future<void> searchCategoryBooks(String category) async {
    _isLoadingRecommended = true;
    notifyListeners();

    try {
      final response = await _apiClient.get('/search', queryParams: {'q': 'subject:$category'});
      if (response.success && response.data is List && (response.data as List).isNotEmpty) {
        final list = response.data as List;
        _recommendedBooks = list.map((item) => BookModel.fromJson(item)).toList();
      }
    } catch (_) {
      // Sin conexión al backend: dejar lista vacía
    } finally {
      _isLoadingRecommended = false;
      notifyListeners();
    }
  }

  void onSearchQueryChanged(String query) {
    _searchQuery = query;
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _executeSearch(query);
    });
  }

  Future<void> _executeSearch(String query) async {
    try {
      final response = await _apiClient.get('/search', queryParams: {'q': query});
      if (response.success && response.data is List) {
        final list = response.data as List;
        _searchResults = list.map((item) => BookModel.fromJson(item)).toList();
      } else {
        // Búsqueda en catálogo local
        final all = [..._trendingBooks, ..._recommendedBooks];
        _searchResults = all.where((b) => 
          b.title.toLowerCase().contains(query.toLowerCase()) || 
          b.authors.any((a) => a.toLowerCase().contains(query.toLowerCase()))
        ).toList();
      }
    } catch (_) {
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    _isSearching = false;
    notifyListeners();
  }

}
