import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../models/book_model.dart';
import '../models/challenge_model.dart';

class ChallengesProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<ChallengeSummaryModel> _myChallenges = [];
  ChallengeDetailModel? _selected;
  bool _isLoading = false;

  List<ChallengeSummaryModel> get myChallenges => _myChallenges;
  ChallengeDetailModel? get selected => _selected;
  bool get isLoading => _isLoading;

  Future<void> fetchMine() async {
    _isLoading = true;
    notifyListeners();
    final r = await _apiClient.get('/challenges');
    if (r.success && r.data is List) {
      _myChallenges = (r.data as List).map((e) => ChallengeSummaryModel.fromJson(e)).toList();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<ChallengeSummaryModel?> create({
    required String name,
    String? description,
    String coverColor = '#C8602E',
    DateTime? startDate,
    DateTime? endDate,
    List<int> initialParticipantIds = const [],
    List<Map<String, dynamic>> initialCategories = const [],
  }) async {
    final r = await _apiClient.post('/challenges', body: {
      'name': name,
      if (description != null) 'description': description,
      'coverColor': coverColor,
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate.toIso8601String(),
      if (initialParticipantIds.isNotEmpty) 'initialParticipantIds': initialParticipantIds,
      if (initialCategories.isNotEmpty) 'initialCategories': initialCategories,
    });
    if (r.success && r.data is Map<String, dynamic>) {
      await fetchMine();
      return ChallengeSummaryModel.fromJson(r.data);
    }
    return null;
  }

  Future<void> load(int challengeId) async {
    _isLoading = true;
    notifyListeners();
    final r = await _apiClient.get('/challenges/$challengeId');
    if (r.success && r.data is Map<String, dynamic>) {
      _selected = ChallengeDetailModel.fromJson(r.data);
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addCategory(int challengeId, String name, {String icon = '📖', String? description}) async {
    await _apiClient.post('/challenges/$challengeId/categories', body: {
      'name': name,
      'icon': icon,
      if (description != null) 'description': description,
    });
    await load(challengeId);
  }

  Future<void> deleteCategory(int challengeId, int categoryId) async {
    await _apiClient.delete('/challenges/categories/$categoryId');
    await load(challengeId);
  }

  Future<void> setBookForCell(int challengeId, int categoryId, BookModel book) async {
    await _apiClient.post('/challenges/$challengeId/entries/$categoryId', body: {'book': book.toJson()});
    await load(challengeId);
  }

  Future<void> clearCell(int challengeId, int categoryId) async {
    await _apiClient.delete('/challenges/$challengeId/entries/$categoryId');
    await load(challengeId);
  }

  Future<void> updateEntryStatus(int challengeId, int entryId, ChallengeEntryStatus status) async {
    await _apiClient.post('/challenges/entries/$entryId/status', body: {
      'status': challengeEntryStatusValue(status),
    });
    await load(challengeId);
  }

  Future<void> reviewCell(int challengeId, int entryId, {double? rating, String? comment}) async {
    // Cuantizar a medios puntos antes de enviar
    double? clamped;
    if (rating != null) {
      final c = rating.clamp(0.0, 5.0);
      clamped = (c * 2).roundToDouble() / 2;
    }
    await _apiClient.post('/challenges/entries/$entryId/review', body: {
      if (clamped != null) 'rating': clamped,
      if (comment != null) 'comment': comment,
    });
    await load(challengeId);
  }

  Future<void> updateMyNotes(int challengeId, String notes) async {
    await _apiClient.post('/challenges/$challengeId/notes', body: {'notes': notes});
    await load(challengeId);
  }

  Future<void> invite(int challengeId, List<int> userIds) async {
    await _apiClient.post('/challenges/$challengeId/invite', body: {'userIds': userIds});
    await load(challengeId);
  }

  Future<void> leave(int challengeId) async {
    await _apiClient.post('/challenges/$challengeId/leave');
    _selected = null;
    await fetchMine();
  }

  Future<void> delete(int challengeId) async {
    await _apiClient.delete('/challenges/$challengeId');
    _selected = null;
    await fetchMine();
  }
}
