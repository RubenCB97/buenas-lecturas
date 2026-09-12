import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../models/book_model.dart';

/// Orden disponible para las novedades.
enum NewReleasesSort { mostRead, newest }

extension NewReleasesSortX on NewReleasesSort {
  String get value => this == NewReleasesSort.newest ? 'new' : 'readinglog';
  String get label => this == NewReleasesSort.newest ? 'Más recientes' : 'Más leídos';
  IconData get icon =>
      this == NewReleasesSort.newest ? Icons.schedule_rounded : Icons.local_fire_department_rounded;
}

/// Estado de la pantalla "Novedades del año", con paginación infinita,
/// filtro por región (España / Mundial) y por año.
class NewReleasesProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  final List<BookModel> _books = [];
  String _region = 'GLOBAL';
  NewReleasesSort _sort = NewReleasesSort.mostRead;
  late int _year = DateTime.now().year;

  int _page = 1;
  int _total = 0;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  List<BookModel> get books => List.unmodifiable(_books);
  String get region => _region;
  NewReleasesSort get sort => _sort;
  int get year => _year;
  int get total => _total;
  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;

  /// Años seleccionables: el actual y los dos anteriores.
  List<int> get availableYears {
    final current = DateTime.now().year;
    return [current, current - 1, current - 2];
  }

  Future<void> _fetch({required bool reset}) async {
    if (reset) {
      _page = 1;
      _hasMore = true;
      _isLoading = true;
      _error = null;
    } else {
      if (!_hasMore || _isLoadingMore) return;
      _isLoadingMore = true;
    }
    notifyListeners();

    try {
      final response = await _apiClient.get('/search/new-releases', queryParams: {
        'year': _year,
        'region': _region,
        'sort': _sort.value,
        'page': _page,
        'limit': 24,
      });

      final data = response.data;
      if (response.success && data is Map<String, dynamic>) {
        final incoming = (data['books'] as List? ?? [])
            .map((e) => BookModel.fromJson(e))
            .toList();

        if (reset) _books.clear();

        // Evitamos duplicados entre páginas
        final seen = _books
            .map((b) => (b.googleId ?? b.title).toLowerCase())
            .toSet();
        for (final b in incoming) {
          final key = (b.googleId ?? b.title).toLowerCase();
          if (seen.add(key)) _books.add(b);
        }

        _total = data['total'] is int ? data['total'] : _books.length;
        _hasMore = data['hasMore'] == true && incoming.isNotEmpty;
        if (_hasMore) _page++;
      } else {
        _error = response.errorMessage ?? 'No se pudieron cargar las novedades';
        _hasMore = false;
      }
    } catch (e) {
      _error = e.toString();
      _hasMore = false;
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> load() => _fetch(reset: true);
  Future<void> loadMore() => _fetch(reset: false);
  Future<void> refresh() => _fetch(reset: true);

  Future<void> setRegion(String region) async {
    if (region == _region) return;
    _region = region;
    await _fetch(reset: true);
  }

  Future<void> setSort(NewReleasesSort sort) async {
    if (sort == _sort) return;
    _sort = sort;
    await _fetch(reset: true);
  }

  Future<void> setYear(int year) async {
    if (year == _year) return;
    _year = year;
    await _fetch(reset: true);
  }
}
