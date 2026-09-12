import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../models/activity_model.dart';

class ProfileProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<ActivityModel> _activities = [];
  bool _isLoadingActivities = false;

  List<ActivityModel> get activities => _activities;
  bool get isLoadingActivities => _isLoadingActivities;

  Future<void> fetchActivities() async {
    _isLoadingActivities = true;
    notifyListeners();

    try {
      final response = await _apiClient.get('/library/activities');
      if (response.success && response.data is List) {
        final list = response.data as List;
        _activities = list.map((item) => ActivityModel.fromJson(item)).toList();
      }
    } catch (_) {
      // Sin conexión: dejar lista vacía
    } finally {
      _isLoadingActivities = false;
      notifyListeners();
    }
  }
}
