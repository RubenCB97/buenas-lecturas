import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../models/book_model.dart';
import '../models/reading_group_model.dart';

class GroupsProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<ReadingGroupModel> _myGroups = [];
  List<ReadingGroupModel> _discover = [];
  ReadingGroupModel? _selectedGroup;
  GroupProgressResponse? _progress;
  List<GroupMessageModel> _messages = [];
  bool _isLoading = false;
  bool _isSendingMessage = false;

  List<ReadingGroupModel> get myGroups => _myGroups;
  List<ReadingGroupModel> get discover => _discover;
  ReadingGroupModel? get selectedGroup => _selectedGroup;
  GroupProgressResponse? get progress => _progress;
  List<GroupMessageModel> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isSendingMessage => _isSendingMessage;

  Future<void> fetchMyGroups() async {
    _isLoading = true;
    notifyListeners();
    final r = await _apiClient.get('/groups');
    if (r.success && r.data is List) {
      _myGroups = (r.data as List).map((e) => ReadingGroupModel.fromJson(e)).toList();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchDiscover([String? q]) async {
    final r = await _apiClient.get('/groups/discover', queryParams: q != null ? {'q': q} : null);
    if (r.success && r.data is List) {
      _discover = (r.data as List).map((e) => ReadingGroupModel.fromJson(e)).toList();
    }
    notifyListeners();
  }

  Future<ReadingGroupModel?> createGroup(String name, String? description, {String coverColor = '#C8602E', bool isPrivate = false}) async {
    final r = await _apiClient.post('/groups', body: {
      'name': name,
      'description': description,
      'coverColor': coverColor,
      'isPrivate': isPrivate,
    });
    if (r.success && r.data is Map<String, dynamic>) {
      await fetchMyGroups();
      return ReadingGroupModel.fromJson(r.data);
    }
    return null;
  }

  Future<void> loadGroup(int id) async {
    _isLoading = true;
    notifyListeners();
    final r = await _apiClient.get('/groups/$id');
    if (r.success && r.data is Map<String, dynamic>) {
      _selectedGroup = ReadingGroupModel.fromJson(r.data);
    }
    // Load progress + messages
    final p = await _apiClient.get('/groups/$id/ranking');
    if (p.success && p.data is Map<String, dynamic>) {
      _progress = GroupProgressResponse.fromJson(p.data);
    }
    await loadMessages(id);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMessages(int groupId, {int? bookId, int? chapter}) async {
    final params = <String, dynamic>{};
    if (bookId != null) params['bookId'] = bookId;
    if (chapter != null) params['chapter'] = chapter;
    final r = await _apiClient.get('/groups/$groupId/messages', queryParams: params.isEmpty ? null : params);
    if (r.success && r.data is List) {
      _messages = (r.data as List).map((e) => GroupMessageModel.fromJson(e)).toList();
    }
    notifyListeners();
  }

  Future<bool> sendMessage(int groupId, String content, {int? bookId, int? chapter}) async {
    if (content.trim().isEmpty) return false;
    _isSendingMessage = true;
    notifyListeners();
    final r = await _apiClient.post('/groups/$groupId/messages', body: {
      'content': content,
      if (bookId != null) 'bookId': bookId,
      if (chapter != null) 'chapterNumber': chapter,
    });
    _isSendingMessage = false;
    if (r.success) {
      await loadMessages(groupId, bookId: bookId, chapter: chapter);
      return true;
    }
    notifyListeners();
    return false;
  }

  Future<void> addBookToGroup(int groupId, BookModel book, {DateTime? startDate, DateTime? targetEndDate, GroupBookStatus status = GroupBookStatus.current}) async {
    await _apiClient.post('/groups/$groupId/books', body: {
      'book': book.toJson(),
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (targetEndDate != null) 'targetEndDate': targetEndDate.toIso8601String(),
      'status': groupBookStatusValue(status),
    });
    await loadGroup(groupId);
  }

  Future<void> joinGroup(int groupId) async {
    await _apiClient.post('/groups/$groupId/join');
    await fetchMyGroups();
  }

  Future<void> leaveGroup(int groupId) async {
    await _apiClient.post('/groups/$groupId/leave');
    await fetchMyGroups();
  }

  Future<void> deleteGroup(int groupId) async {
    await _apiClient.delete('/groups/$groupId');
    await fetchMyGroups();
  }
}
