import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../models/friendship_model.dart';
import '../models/user_model.dart';

class FriendsProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<UserModel> _friends = [];
  List<FriendshipModel> _incoming = [];
  List<FriendshipModel> _outgoing = [];
  List<UserModel> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;

  List<UserModel> get friends => _friends;
  List<FriendshipModel> get incoming => _incoming;
  List<FriendshipModel> get outgoing => _outgoing;
  List<UserModel> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  int get pendingCount => _incoming.length;

  Future<void> fetchAll() async {
    _isLoading = true;
    notifyListeners();
    try {
      final f = await _apiClient.get('/friends');
      if (f.success && f.data is List) {
        _friends = (f.data as List).map((e) => UserModel.fromJson(e)).toList();
      }
      final inR = await _apiClient.get('/friends/requests/incoming');
      if (inR.success && inR.data is List) {
        _incoming = (inR.data as List).map((e) => FriendshipModel.fromJson(e)).toList();
      }
      final outR = await _apiClient.get('/friends/requests/outgoing');
      if (outR.success && outR.data is List) {
        _outgoing = (outR.data as List).map((e) => FriendshipModel.fromJson(e)).toList();
      }
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> search(String query) async {
    if (query.trim().length < 2) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    _isSearching = true;
    notifyListeners();
    final r = await _apiClient.get('/friends/search', queryParams: {'q': query});
    if (r.success && r.data is List) {
      _searchResults = (r.data as List).map((e) => UserModel.fromJson(e)).toList();
    } else {
      _searchResults = [];
    }
    _isSearching = false;
    notifyListeners();
  }

  Future<FriendshipStatus> statusWith(dynamic userId) async {
    final r = await _apiClient.get('/friends/status/$userId');
    if (r.success && r.data is Map) {
      return friendshipStatusFromString(r.data['status']);
    }
    return FriendshipStatus.none;
  }

  Future<void> sendRequest(dynamic userId) async {
    await _apiClient.post('/friends/request/$userId');
    await fetchAll();
  }

  Future<void> respond(int friendshipId, bool accept) async {
    await _apiClient.post('/friends/respond/$friendshipId', body: {'accept': accept});
    await fetchAll();
  }

  Future<void> removeFriend(dynamic userId) async {
    await _apiClient.delete('/friends/$userId');
    await fetchAll();
  }
}
