import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../models/book_model.dart';
import '../models/review_model.dart';
import '../models/user_model.dart';

class BookDetailProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<ReviewModel> _reviews = [];
  List<BookModel> _similarBooks = [];
  List<BookModel> _seriesBooks = [];
  bool _isLoadingReviews = false;
  bool _isLoadingSimilar = false;
  bool _isLoadingSeries = false;
  bool _isSubmittingReview = false;
  String? _errorMessage;

  List<ReviewModel> get reviews => _reviews;
  List<BookModel> get similarBooks => _similarBooks;
  List<BookModel> get seriesBooks => _seriesBooks;
  bool get isLoadingReviews => _isLoadingReviews;
  bool get isLoadingSimilar => _isLoadingSimilar;
  bool get isLoadingSeries => _isLoadingSeries;
  bool get isSubmittingReview => _isSubmittingReview;
  String? get errorMessage => _errorMessage;

  // Reseña propia del usuario actual sobre el libro cargado
  ReviewModel? myReviewFor(dynamic userId) {
    if (userId == null) return null;
    final target = userId.toString();
    try {
      return _reviews.firstWhere((r) => r.user?.id?.toString() == target);
    } catch (_) {
      return null;
    }
  }

  // Carga de reseñas de la comunidad desde el backend NestJS
  Future<void> fetchReviews(String? googleId) async {
    if (googleId == null || googleId.isEmpty) {
      _reviews = [];
      notifyListeners();
      return;
    }

    _isLoadingReviews = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.get('/reviews/$googleId');
      if (response.success && response.data is List) {
        final list = response.data as List;
        _reviews = list.map((item) => ReviewModel.fromJson(item)).toList();
      }
    } catch (_) {
      // Sin conexión: dejar lista vacía
    } finally {
      _isLoadingReviews = false;
      notifyListeners();
    }
  }

  // Publicar reseña en el backend
  Future<bool> addReview({
    required BookModel book,
    required String content,
    required double rating,
    UserModel? currentUser,
  }) async {
    _isSubmittingReview = true;
    notifyListeners();

    try {
      final response = await _apiClient.post('/reviews', body: {
        'book': book.toJson(),
        'content': content,
        'rating': rating,
      });

      if (response.success) {
        // Añadir a la lista local
        final newReview = ReviewModel(
          id: DateTime.now().millisecondsSinceEpoch,
          user: currentUser,
          book: book,
          content: content,
          rating: rating,
          createdAt: DateTime.now(),
        );
        _reviews.insert(0, newReview);
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      _isSubmittingReview = false;
      notifyListeners();
    }
  }

  // Libros de la misma saga/serie (heurística título+autor)
  Future<void> fetchSeriesBooks(BookModel book) async {
    _isLoadingSeries = true;
    notifyListeners();
    try {
      final params = <String, dynamic>{'title': book.title};
      if (book.authors.isNotEmpty) params['author'] = book.authors.first;
      if (book.googleId != null) params['googleId'] = book.googleId!;
      final response = await _apiClient.get('/search/series', queryParams: params);
      if (response.success && response.data is List) {
        _seriesBooks = (response.data as List).map((e) => BookModel.fromJson(e)).toList();
      } else {
        _seriesBooks = [];
      }
    } catch (_) {
      _seriesBooks = [];
    } finally {
      _isLoadingSeries = false;
      notifyListeners();
    }
  }

  // Cargar libros similares al estilo Goodreads "Readers also enjoyed"
  Future<void> fetchSimilarBooks(BookModel book) async {
    final id = book.googleId ?? book.id?.toString();
    if (id == null || id.isEmpty) {
      _similarBooks = [];
      notifyListeners();
      return;
    }
    _isLoadingSimilar = true;
    notifyListeners();

    try {
      final params = <String, dynamic>{};
      if (book.categories.isNotEmpty) params['category'] = book.categories.first;
      if (book.authors.isNotEmpty) params['author'] = book.authors.first;

      final response = await _apiClient.get('/search/similar/$id', queryParams: params);
      if (response.success && response.data is List) {
        final list = response.data as List;
        _similarBooks = list.map((item) => BookModel.fromJson(item)).toList();
      } else {
        _similarBooks = [];
      }
    } catch (_) {
      _similarBooks = [];
    } finally {
      _isLoadingSimilar = false;
      notifyListeners();
    }
  }

  void clear() {
    _reviews = [];
    _similarBooks = [];
    _seriesBooks = [];
    notifyListeners();
  }

  // Desglose de estrellas estilo Goodreads (5★, 4★, 3★, 2★, 1★)
  Map<int, double> getRatingDistribution(double? avgRating) {
    // Si hay reseñas reales, calcularlas
    if (_reviews.isNotEmpty) {
      final total = _reviews.length;
      final counts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
      for (final r in _reviews) {
        final k = r.rating.round().clamp(1, 5);
        counts[k] = (counts[k] ?? 0) + 1;
      }
      return counts.map((k, v) => MapEntry(k, v / total));
    }

    // Calculamos o generamos la campana típica de Goodreads
    final avg = avgRating ?? 4.5;
    if (avg >= 4.5) {
      return {5: 0.65, 4: 0.22, 3: 0.08, 2: 0.03, 1: 0.02};
    } else if (avg >= 4.0) {
      return {5: 0.45, 4: 0.35, 3: 0.12, 2: 0.05, 1: 0.03};
    } else if (avg >= 3.5) {
      return {5: 0.30, 4: 0.32, 3: 0.22, 2: 0.10, 1: 0.06};
    } else {
      return {5: 0.15, 4: 0.25, 3: 0.30, 2: 0.18, 1: 0.12};
    }
  }
}
