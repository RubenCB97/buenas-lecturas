import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../models/activity_model.dart';
import '../models/book_model.dart';
import '../models/custom_shelf_model.dart';
import '../models/quote_model.dart';
import '../models/recommendation_model.dart';

class SocialProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<ActivityModel> _feed = [];
  List<QuoteModel> _quotesFeed = [];
  List<QuoteModel> _myQuotes = [];
  List<RecommendationModel> _recommendations = [];
  List<CustomShelfModel> _shelves = [];
  bool _loadingFeed = false;

  List<ActivityModel> get feed => _feed;
  List<QuoteModel> get quotesFeed => _quotesFeed;
  List<QuoteModel> get myQuotes => _myQuotes;
  List<RecommendationModel> get recommendations => _recommendations;
  List<CustomShelfModel> get shelves => _shelves;
  bool get loadingFeed => _loadingFeed;
  int get unseenRecommendations => _recommendations.where((r) => !r.seen).length;

  // ---------------- Feed social ----------------
  Future<void> fetchFeed() async {
    _loadingFeed = true;
    notifyListeners();
    final r = await _apiClient.get('/social/feed');
    if (r.success && r.data is List) {
      _feed = (r.data as List).map((e) => ActivityModel.fromJson(e)).toList();
    }
    _loadingFeed = false;
    notifyListeners();
  }

  Future<void> toggleLike(int activityId) async {
    // Optimista
    final idx = _feed.indexWhere((a) => a.id == activityId);
    if (idx != -1) {
      final a = _feed[idx];
      _feed[idx] = a.copyWith(
        likedByMe: !a.likedByMe,
        likesCount: a.likedByMe ? a.likesCount - 1 : a.likesCount + 1,
      );
      notifyListeners();
    }
    await _apiClient.post('/social/activity/$activityId/like');
  }

  Future<List<ActivityCommentModel>> fetchComments(int activityId) async {
    final r = await _apiClient.get('/social/activity/$activityId/comments');
    if (r.success && r.data is List) {
      return (r.data as List).map((e) => ActivityCommentModel.fromJson(e)).toList();
    }
    return [];
  }

  Future<ActivityCommentModel?> addComment(int activityId, String content) async {
    final r = await _apiClient.post('/social/activity/$activityId/comments', body: {'content': content});
    if (r.success && r.data is Map<String, dynamic>) {
      // Actualizar contador
      final idx = _feed.indexWhere((a) => a.id == activityId);
      if (idx != -1) {
        _feed[idx] = _feed[idx].copyWith(commentsCount: _feed[idx].commentsCount + 1);
        notifyListeners();
      }
      return ActivityCommentModel.fromJson(r.data);
    }
    return null;
  }

  // ---------------- Citas ----------------
  Future<void> fetchQuotesFeed() async {
    final r = await _apiClient.get('/social/quotes/feed');
    if (r.success && r.data is List) {
      _quotesFeed = (r.data as List).map((e) => QuoteModel.fromJson(e)).toList();
      notifyListeners();
    }
  }

  Future<void> fetchMyQuotes() async {
    final r = await _apiClient.get('/social/quotes/mine');
    if (r.success && r.data is List) {
      _myQuotes = (r.data as List).map((e) => QuoteModel.fromJson(e)).toList();
      notifyListeners();
    }
  }

  Future<List<QuoteModel>> fetchQuotesForBook(String googleId) async {
    final r = await _apiClient.get('/social/quotes/book/$googleId');
    if (r.success && r.data is List) {
      return (r.data as List).map((e) => QuoteModel.fromJson(e)).toList();
    }
    return [];
  }

  Future<bool> addQuote(BookModel book, String text, {int? page}) async {
    final r = await _apiClient.post('/social/quotes', body: {
      'book': book.toJson(),
      'text': text,
      if (page != null) 'page': page,
    });
    if (r.success) {
      await fetchMyQuotes();
      return true;
    }
    return false;
  }

  Future<void> deleteQuote(int quoteId) async {
    await _apiClient.delete('/social/quotes/$quoteId');
    _myQuotes.removeWhere((q) => q.id == quoteId);
    _quotesFeed.removeWhere((q) => q.id == quoteId);
    notifyListeners();
  }

  // ---------------- Recomendaciones ----------------
  Future<void> fetchRecommendations() async {
    final r = await _apiClient.get('/social/recommendations');
    if (r.success && r.data is List) {
      _recommendations = (r.data as List).map((e) => RecommendationModel.fromJson(e)).toList();
      notifyListeners();
    }
  }

  Future<bool> sendRecommendation(int toUserId, BookModel book, {String? note}) async {
    final r = await _apiClient.post('/social/recommend/$toUserId', body: {
      'book': book.toJson(),
      if (note != null) 'note': note,
    });
    return r.success;
  }

  Future<void> markSeen(int recId) async {
    await _apiClient.post('/social/recommendations/$recId/seen');
    final idx = _recommendations.indexWhere((r) => r.id == recId);
    if (idx != -1) {
      final r = _recommendations[idx];
      _recommendations[idx] = RecommendationModel(
        id: r.id, fromUser: r.fromUser, toUser: r.toUser, book: r.book, note: r.note, seen: true, createdAt: r.createdAt,
      );
      notifyListeners();
    }
  }

  // ---------------- Estanterías personalizadas ----------------
  Future<void> fetchShelves() async {
    final r = await _apiClient.get('/social/shelves');
    if (r.success && r.data is List) {
      _shelves = (r.data as List).map((e) => CustomShelfModel.fromJson(e)).toList();
      notifyListeners();
    }
  }

  Future<CustomShelfModel?> createShelf(String name, {String icon = '📚'}) async {
    final r = await _apiClient.post('/social/shelves', body: {'name': name, 'icon': icon});
    if (r.success && r.data is Map<String, dynamic>) {
      await fetchShelves();
      return CustomShelfModel.fromJson(r.data);
    }
    return null;
  }

  Future<bool> addBookToShelf(int shelfId, BookModel book) async {
    final r = await _apiClient.post('/social/shelves/$shelfId/add', body: {'book': book.toJson()});
    if (r.success) {
      await fetchShelves();
      return true;
    }
    return false;
  }

  Future<void> removeBookFromShelf(int shelfId, int bookId) async {
    await _apiClient.delete('/social/shelves/$shelfId/books/$bookId');
    await fetchShelves();
  }

  Future<void> deleteShelf(int shelfId) async {
    await _apiClient.delete('/social/shelves/$shelfId');
    _shelves.removeWhere((s) => s.id == shelfId);
    notifyListeners();
  }
}
