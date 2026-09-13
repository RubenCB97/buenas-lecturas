import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/api_client.dart';
import '../models/book_model.dart';
import '../models/user_book_model.dart';

enum LibraryFilter { all, reading, wantToRead, read, favorites, abandoned }
enum LibrarySort { recent, title, rating, dateStarted, dateFinished }

class LibraryProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  
  List<UserBookModel> _libraryBooks = [];
  bool _isLoading = false;
  String? _errorMessage;
  LibraryFilter _currentFilter = LibraryFilter.all;
  LibrarySort _currentSort = LibrarySort.recent;
  String _searchQuery = '';
  bool _isGridView = false;
  bool _isOffline = false;
  DateTime? _cachedAt;

  static const String _cacheKey = 'library_cache_v1';
  static const String _cacheTimeKey = 'library_cache_time_v1';

  List<UserBookModel> get libraryBooks => _libraryBooks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  LibraryFilter get currentFilter => _currentFilter;
  LibrarySort get currentSort => _currentSort;
  String get searchQuery => _searchQuery;
  bool get isGridView => _isGridView;

  /// Sin conexión con el servidor: mostramos la última copia guardada.
  bool get isOffline => _isOffline;

  /// Cuándo se guardó la copia que se está mostrando sin conexión.
  DateTime? get cachedAt => _cachedAt;

  // Filtrado y ordenación
  List<UserBookModel> get filteredBooks {
    List<UserBookModel> list = [..._libraryBooks];

    // Filtro por estantería
    switch (_currentFilter) {
      case LibraryFilter.reading:
        list = list.where((b) => b.status == ReadingStatus.reading).toList();
        break;
      case LibraryFilter.wantToRead:
        list = list.where((b) => b.status == ReadingStatus.wantToRead).toList();
        break;
      case LibraryFilter.read:
        list = list.where((b) => b.status == ReadingStatus.read).toList();
        break;
      case LibraryFilter.favorites:
        list = list.where((b) => b.isFavorite).toList();
        break;
      case LibraryFilter.abandoned:
        list = list.where((b) => b.status == ReadingStatus.abandoned).toList();
        break;
      case LibraryFilter.all:
        break;
    }

    // Filtro por búsqueda dentro de la biblioteca
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((b) {
        final title = b.book.title.toLowerCase();
        final authors = b.book.authors.join(' ').toLowerCase();
        return title.contains(q) || authors.contains(q);
      }).toList();
    }

    // Ordenación
    switch (_currentSort) {
      case LibrarySort.recent:
        list.sort((a, b) => (b.updatedAt ?? DateTime(2000)).compareTo(a.updatedAt ?? DateTime(2000)));
        break;
      case LibrarySort.title:
        list.sort((a, b) => a.book.title.compareTo(b.book.title));
        break;
      case LibrarySort.rating:
        list.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
        break;
      case LibrarySort.dateStarted:
        list.sort((a, b) => (b.startedAt ?? DateTime(1970)).compareTo(a.startedAt ?? DateTime(1970)));
        break;
      case LibrarySort.dateFinished:
        list.sort((a, b) => (b.finishedAt ?? DateTime(1970)).compareTo(a.finishedAt ?? DateTime(1970)));
        break;
    }

    return list;
  }

  int get countReading => _libraryBooks.where((b) => b.status == ReadingStatus.reading).length;
  int get countWantToRead => _libraryBooks.where((b) => b.status == ReadingStatus.wantToRead).length;
  int get countRead => _libraryBooks.where((b) => b.status == ReadingStatus.read).length;
  int get countFavorites => _libraryBooks.where((b) => b.isFavorite).length;
  int get countAbandoned => _libraryBooks.where((b) => b.status == ReadingStatus.abandoned).length;
  int get totalBooks => _libraryBooks.length;

  // Libros que se están leyendo actualmente
  List<UserBookModel> get currentlyReading =>
      _libraryBooks.where((b) => b.status == ReadingStatus.reading).toList();

  // Promedio de puntuaciones dadas por el usuario
  double get userAverageRating {
    final rated = _libraryBooks.where((b) => b.rating != null && b.rating! > 0).toList();
    if (rated.isEmpty) return 0;
    final total = rated.fold<double>(0.0, (sum, b) => sum + b.rating!);
    return total / rated.length;
  }

  // Libros terminados en el año actual
  int get booksReadThisYear {
    final now = DateTime.now();
    return _libraryBooks
        .where((b) => b.finishedAt != null && b.finishedAt!.year == now.year)
        .length;
  }
  
  // Total de páginas leídas aproximadas. Para los libros sin dato de páginas
  // usamos una estimación media en vez de contarlos como 0.
  int get totalPagesRead {
    const estimated = 280;
    int total = 0;
    for (var b in _libraryBooks) {
      final pages = b.book.hasPageCount ? b.book.pageCount! : estimated;
      if (b.status == ReadingStatus.read) {
        total += pages;
      } else if (b.status == ReadingStatus.reading) {
        // Solo contamos lo realmente registrado, sin estimar un avance
        total += b.currentPage ?? 0;
      }
    }
    return total;
  }

  void setFilter(LibraryFilter filter) {
    _currentFilter = filter;
    notifyListeners();
  }

  void setSort(LibrarySort sort) {
    _currentSort = sort;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleViewMode() {
    _isGridView = !_isGridView;
    notifyListeners();
  }

  // Cargar biblioteca desde el backend NestJS. Si no hay conexión se usa la
  // última copia guardada en el dispositivo (solo lectura).
  Future<void> fetchLibrary() async {
    _isLoading = true;
    _errorMessage = null;
    if (_libraryBooks.isEmpty) await _loadCache();
    notifyListeners();

    try {
      final response = await _apiClient.get('/library');
      if (response.success && response.data != null && response.data is List) {
        final list = response.data as List;
        _libraryBooks = list.map((item) => UserBookModel.fromJson(item)).toList();
        _isOffline = false;
        _saveCache(list);
      } else if (response.statusCode == null || response.statusCode! >= 502) {
        // Ni siquiera hubo respuesta: estamos sin red o el servidor no responde
        _isOffline = true;
      } else {
        _isOffline = false;
        _errorMessage = response.errorMessage;
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;
      final list = jsonDecode(raw) as List;
      _libraryBooks = list.map((item) => UserBookModel.fromJson(item)).toList();
      final time = prefs.getInt(_cacheTimeKey);
      _cachedAt = time == null ? null : DateTime.fromMillisecondsSinceEpoch(time);
    } catch (_) {
      // Copia corrupta o de un formato antiguo: la ignoramos
    }
  }

  Future<void> _saveCache(List raw) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      await prefs.setString(_cacheKey, jsonEncode(raw));
      await prefs.setInt(_cacheTimeKey, now.millisecondsSinceEpoch);
      _cachedAt = now;
    } catch (_) {
      // Sin espacio o almacenamiento no disponible: no es crítico
    }
  }

  /// Borra la copia local (al cerrar sesión, para no mostrarla a otra cuenta).
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimeKey);
  }

  // Añadir libro a la biblioteca
  Future<bool> addBook(BookModel book, {ReadingStatus status = ReadingStatus.wantToRead}) async {
    final response = await _apiClient.post('/library/add', body: {
      'book': book.toJson(),
      'status': status.value,
    });

    if (response.success) {
      await fetchLibrary();
      return true;
    } else {
      // Optimistic update local
      final existingIndex = _libraryBooks.indexWhere((b) => b.book.title == book.title || b.book.googleId == book.googleId);
      if (existingIndex == -1) {
        _libraryBooks.insert(
          0,
          UserBookModel(
            id: DateTime.now().millisecondsSinceEpoch,
            book: book,
            status: status,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        notifyListeners();
      }
      return true;
    }
  }

  // Actualizar estado del libro
  Future<bool> updateStatus(dynamic bookId, ReadingStatus status) async {
    final response = await _apiClient.post('/library/$bookId/status', body: {
      'status': status.value,
    });

    // Actualización local
    final index = _libraryBooks.indexWhere((b) => b.id == bookId || b.book.id == bookId);
    if (index != -1) {
      _libraryBooks[index] = _libraryBooks[index].copyWith(status: status);
      notifyListeners();
    }

    if (response.success) {
      fetchLibrary();
      return true;
    }
    return false;
  }

  // Actualizar puntuación del libro (admite medios puntos, ej. 3.5)
  Future<bool> updateRating(dynamic bookId, double rating) async {
    final clamped = rating.clamp(0.0, 5.0);
    final half = (clamped * 2).roundToDouble() / 2;
    final response = await _apiClient.post('/library/$bookId/rating', body: {
      'rating': half,
    });

    final index = _libraryBooks.indexWhere((b) => b.id == bookId || b.book.id == bookId);
    if (index != -1) {
      _libraryBooks[index] = _libraryBooks[index].copyWith(rating: half);
      notifyListeners();
    }

    if (response.success) {
      fetchLibrary();
      return true;
    }
    return false;
  }

  // Actualizar progreso (página actual) - estilo Goodreads
  Future<bool> updateProgress(dynamic bookId, int currentPage) async {
    final index = _libraryBooks.indexWhere((b) => b.id == bookId || b.book.id == bookId);
    if (index != -1) {
      final book = _libraryBooks[index].book;
      final totalPages = book.pageCount ?? 0;
      // Actualización optimista
      ReadingStatus newStatus = _libraryBooks[index].status;
      if (totalPages > 0 && currentPage >= totalPages) {
        newStatus = ReadingStatus.read;
      } else if (currentPage > 0 && newStatus == ReadingStatus.wantToRead) {
        newStatus = ReadingStatus.reading;
      }
      _libraryBooks[index] = _libraryBooks[index].copyWith(
        currentPage: currentPage,
        status: newStatus,
      );
      notifyListeners();
    }

    final response = await _apiClient.post('/library/$bookId/progress', body: {
      'currentPage': currentPage,
    });

    if (response.success) {
      fetchLibrary();
      return true;
    }
    return false;
  }

  // Guardar notas privadas del libro
  Future<bool> updateNotes(dynamic bookId, String notes) async {
    final index = _libraryBooks.indexWhere((b) => b.id == bookId || b.book.id == bookId);
    if (index != -1) {
      _libraryBooks[index] = _libraryBooks[index].copyWith(notes: notes);
      notifyListeners();
    }

    final response = await _apiClient.post('/library/$bookId/notes', body: {
      'notes': notes,
    });

    if (response.success) {
      return true;
    }
    return false;
  }

  // Alternar libro favorito
  Future<bool> toggleFavorite(dynamic bookId) async {
    final index = _libraryBooks.indexWhere((b) => b.id == bookId || b.book.id == bookId);
    if (index != -1) {
      _libraryBooks[index] = _libraryBooks[index].copyWith(
        isFavorite: !_libraryBooks[index].isFavorite,
      );
      notifyListeners();
    }

    final response = await _apiClient.post('/library/$bookId/favorite');
    if (response.success) {
      fetchLibrary();
      return true;
    }
    return false;
  }

  // Eliminar libro de la biblioteca
  Future<bool> removeBook(dynamic bookId) async {
    final response = await _apiClient.delete('/library/$bookId');

    _libraryBooks.removeWhere((b) => b.id == bookId || b.book.id == bookId);
    notifyListeners();

    if (response.success) {
      fetchLibrary();
      return true;
    }
    return false;
  }

  bool isInLibrary(BookModel book) {
    return _libraryBooks.any((b) => 
      (book.googleId != null && b.book.googleId == book.googleId) ||
      (book.id != null && (b.id == book.id || b.book.id == book.id)) ||
      (b.book.title.toLowerCase() == book.title.toLowerCase())
    );
  }

  UserBookModel? getUserBook(BookModel book) {
    try {
      return _libraryBooks.firstWhere((b) => 
        (book.googleId != null && b.book.googleId == book.googleId) ||
        (book.id != null && (b.id == book.id || b.book.id == book.id)) ||
        (b.book.title.toLowerCase() == book.title.toLowerCase())
      );
    } catch (_) {
      return null;
    }
  }

}
