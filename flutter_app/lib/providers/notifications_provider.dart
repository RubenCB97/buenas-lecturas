import 'dart:async';
import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../models/notification_model.dart';

class NotificationsProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<NotificationModel> _items = [];
  int _unread = 0;
  bool _isLoading = false;
  Timer? _pollTimer;

  List<NotificationModel> get items => _items;
  int get unread => _unread;
  bool get isLoading => _isLoading;

  Future<void> fetch() async {
    _isLoading = true;
    notifyListeners();
    final r = await _apiClient.get('/notifications');
    if (r.success && r.data is List) {
      _items = (r.data as List).map((e) => NotificationModel.fromJson(e)).toList();
      _unread = _items.where((n) => !n.read).length;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshUnreadCount() async {
    final r = await _apiClient.get('/notifications/unread-count');
    if (r.success && r.data is Map<String, dynamic>) {
      final c = r.data['count'];
      _unread = c is int ? c : int.tryParse('$c') ?? 0;
      notifyListeners();
    }
  }

  Future<void> markRead(int id) async {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx != -1 && !_items[idx].read) {
      _items[idx] = _items[idx].copyWith(read: true);
      _unread = (_unread - 1).clamp(0, 9999);
      notifyListeners();
    }
    await _apiClient.post('/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    _items = _items.map((n) => n.copyWith(read: true)).toList();
    _unread = 0;
    notifyListeners();
    await _apiClient.post('/notifications/read-all');
  }

  Future<void> remove(int id) async {
    _items.removeWhere((n) => n.id == id);
    notifyListeners();
    await _apiClient.delete('/notifications/$id');
    await refreshUnreadCount();
  }

  /// Poll ligero cada 60s del contador de no-leídas.
  void startPolling() {
    _pollTimer?.cancel();
    refreshUnreadCount();
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) => refreshUnreadCount());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
