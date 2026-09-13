import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../models/book_model.dart';

/// Una fila "Porque te gustó X".
class ForYouSection {
  final BookModel seed;

  /// 'rated' (4★ o más), 'favorite' o 'read'.
  final String reason;
  final double? rating;
  final List<BookModel> books;

  ForYouSection({required this.seed, required this.reason, this.rating, required this.books});

  factory ForYouSection.fromJson(Map<String, dynamic> json) {
    return ForYouSection(
      seed: BookModel.fromJson(json['seed'] as Map<String, dynamic>),
      reason: json['reason']?.toString() ?? 'read',
      rating: (json['rating'] as num?)?.toDouble(),
      books: (json['books'] as List? ?? []).map((e) => BookModel.fromJson(e)).toList(),
    );
  }
}

/// Lanzamientos recientes y la ventana de meses que abarcan.
class RecentReleases {
  final List<BookModel> books;

  /// 1 = este mes, 3 = últimos 3 meses, 6 = últimos 6 meses.
  final int windowMonths;

  /// Primer mes incluido, formato "YYYY-MM".
  final String since;

  const RecentReleases({required this.books, required this.windowMonths, required this.since});

  static const empty = RecentReleases(books: [], windowMonths: 0, since: '');

  factory RecentReleases.fromJson(Map<String, dynamic> json) {
    return RecentReleases(
      books: (json['books'] as List? ?? []).map((e) => BookModel.fromJson(e)).toList(),
      windowMonths: (json['windowMonths'] as num?)?.toInt() ?? 0,
      since: json['since']?.toString() ?? '',
    );
  }
}

/// Estado de la pestaña Descubrir.
///
/// Las secciones públicas se cachean por región, así cambiar entre España y
/// Mundial es instantáneo una vez cargadas y una respuesta lenta de una región
/// no pisa a la otra. Las recomendaciones personales no dependen de la región.
class DiscoverProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  String _region = 'ES';
  String get region => _region;

  // Recomendaciones personales
  List<ForYouSection> _forYou = [];
  bool _hasSeeds = true;
  bool _forYouLoaded = false;
  bool _loadingForYou = false;

  List<ForYouSection> get forYou => _forYou;
  bool get hasSeeds => _hasSeeds;
  bool get forYouLoaded => _forYouLoaded;
  bool get isLoadingForYou => _loadingForYou;

  // Secciones por región
  final Map<String, List<BookModel>> _week = {};
  final Map<String, RecentReleases> _recent = {};
  final Map<String, List<BookModel>> _year = {};
  final Set<String> _loading = {};

  List<BookModel> get weekBooks => _week[_region] ?? const [];
  RecentReleases get recent => _recent[_region] ?? RecentReleases.empty;
  List<BookModel> get yearBooks => _year[_region] ?? const [];

  bool get isLoadingWeek => _loading.contains('week:$_region');
  bool get isLoadingRecent => _loading.contains('recent:$_region');
  bool get isLoadingYear => _loading.contains('year:$_region');

  /// Carga todo lo de la región actual y, en segundo plano, la otra región.
  Future<void> load({bool force = false}) async {
    await Future.wait([
      loadForYou(force: force),
      _loadRegion(_region, force: force),
    ]);
    final other = _region == 'ES' ? 'GLOBAL' : 'ES';
    _loadRegion(other, force: force);
  }

  Future<void> setRegion(String region) async {
    if (region == _region) return;
    _region = region;
    notifyListeners();
    await _loadRegion(region);
  }

  Future<void> _loadRegion(String region, {bool force = false}) {
    return Future.wait([
      _loadWeek(region, force),
      _loadRecent(region, force),
      _loadYear(region, force),
    ]);
  }

  /// Ejecuta [task] marcando la clave como cargando y evitando duplicados.
  Future<void> _guarded(String key, bool alreadyLoaded, bool force, Future<void> Function() task) async {
    if (_loading.contains(key)) return;
    if (alreadyLoaded && !force) return;
    _loading.add(key);
    notifyListeners();
    try {
      await task();
    } catch (_) {
      // Sin conexión: conservamos lo que hubiera en caché
    } finally {
      _loading.remove(key);
      notifyListeners();
    }
  }

  Future<void> _loadWeek(String region, bool force) {
    return _guarded('week:$region', _week[region]?.isNotEmpty ?? false, force, () async {
      final r = await _apiClient.get('/search/trending', queryParams: {'region': region, 'period': 'weekly'});
      if (r.success && r.data is List && (r.data as List).isNotEmpty) {
        _week[region] = (r.data as List).map((e) => BookModel.fromJson(e)).toList();
      }
    });
  }

  Future<void> _loadRecent(String region, bool force) {
    return _guarded('recent:$region', _recent[region]?.books.isNotEmpty ?? false, force, () async {
      final r = await _apiClient.get('/search/recent-releases', queryParams: {'region': region});
      if (r.success && r.data is Map<String, dynamic>) {
        final value = RecentReleases.fromJson(r.data as Map<String, dynamic>);
        if (value.books.isNotEmpty) _recent[region] = value;
      }
    });
  }

  Future<void> _loadYear(String region, bool force) {
    return _guarded('year:$region', _year[region]?.isNotEmpty ?? false, force, () async {
      final r = await _apiClient.get('/search/new-releases', queryParams: {
        'region': region,
        'sort': 'readinglog',
        'limit': 20,
      });
      final data = r.data;
      if (r.success && data is Map<String, dynamic> && data['books'] is List) {
        final books = (data['books'] as List).map((e) => BookModel.fromJson(e)).toList();
        if (books.isNotEmpty) _year[region] = books;
      }
    });
  }

  /// Recomendaciones "Porque te gustó X". Requiere sesión.
  Future<void> loadForYou({bool force = false}) async {
    if (_loadingForYou) return;
    if (_forYouLoaded && !force) return;
    _loadingForYou = true;
    notifyListeners();
    try {
      final r = await _apiClient.get('/discover/for-you');
      if (r.success && r.data is Map<String, dynamic>) {
        final data = r.data as Map<String, dynamic>;
        _hasSeeds = data['hasSeeds'] == true;
        _forYou = (data['sections'] as List? ?? [])
            .map((e) => ForYouSection.fromJson(e as Map<String, dynamic>))
            .toList();
        _forYouLoaded = true;
      }
    } catch (_) {
      // Conservamos las recomendaciones anteriores
    } finally {
      _loadingForYou = false;
      notifyListeners();
    }
  }
}
