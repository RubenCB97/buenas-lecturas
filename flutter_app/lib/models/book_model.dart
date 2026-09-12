import '../core/constants/api_constants.dart';

class BookModel {
  final dynamic id;
  final String? googleId;
  final String title;
  final String? subtitle;
  final List<String> authors;
  final String? description;
  final String? thumbnail;
  final String? publisher;
  final String? publishedDate;
  final int? pageCount;
  final List<String> categories;
  final String? language;
  final double? averageRating;
  final int? ratingsCount;
  final String? isbn;
  final String? asin;
  final String? awards;

  BookModel({
    this.id,
    this.googleId,
    required this.title,
    this.subtitle,
    this.authors = const [],
    this.description,
    this.thumbnail,
    this.publisher,
    this.publishedDate,
    this.pageCount,
    this.categories = const [],
    this.language,
    this.averageRating,
    this.ratingsCount,
    this.isbn,
    this.asin,
    this.awards,
  });

  String get authorDisplay => authors.isNotEmpty ? authors.join(', ') : 'Autor desconocido';
  String get genreDisplay => categories.isNotEmpty ? categories.first : 'General';

  /// Indica si conocemos de verdad el número de páginas. Las distintas APIs
  /// (Google Books, Open Library) no siempre lo traen, y a veces devuelven 0
  /// o valores imposibles, así que no basta con comprobar `!= null`.
  bool get hasPageCount => pageCount != null && pageCount! > 0;

  /// Páginas para mostrar en texto, o `null` si el dato no es fiable.
  String? get pageCountDisplay => hasPageCount ? '$pageCount páginas' : null;

  /// Total de páginas a efectos de calcular progreso. Cuando no hay dato
  /// usamos una estimación para que las barras no se rompan, pero nunca la
  /// enseñamos como si fuera un dato real.
  int get effectivePageCount => hasPageCount ? pageCount! : 300;

  /// Dominios de portadas que servimos a través del proxy del backend.
  /// Deben coincidir con la lista permitida en `ProxyController`.
  static const List<String> _proxyableCoverHosts = [
    'books.google.com',
    'books.googleusercontent.com',
    'lh3.googleusercontent.com',
    'covers.openlibrary.org',
    'images-na.ssl-images-amazon.com',
    'm.media-amazon.com',
    'i.gr-assets.com',
  ];

  static bool _isProxyableCover(String url) {
    return _proxyableCoverHosts.any((h) => url.contains(h));
  }

  factory BookModel.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) return value.map((e) => e.toString()).toList();
      if (value is String) {
        if (value.startsWith('[') && value.endsWith(']')) {
          try {
            final cleaned = value.substring(1, value.length - 1).replaceAll('"', '').split(',');
            return cleaned.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          } catch (_) {
            return [value];
          }
        }
        return value.split(',').map((s) => s.trim()).toList();
      }
      return [];
    }

    double? parseRating(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    int? parsePages(dynamic value) {
      if (value == null) return null;
      int? n;
      if (value is int) {
        n = value;
      } else if (value is num) {
        n = value.toInt();
      } else if (value is String) {
        n = int.tryParse(value);
      }
      // Normalizamos: 0 o negativos significan "sin dato", no "cero páginas".
      if (n == null || n <= 0) return null;
      return n;
    }

    // A veces la API de Google Books devuelve volumeInfo anidado
    final volumeInfo = json['volumeInfo'] as Map<String, dynamic>?;
    final source = volumeInfo ?? json;

    String? thumb = source['thumbnail'] ?? source['imageLinks']?['thumbnail'] ?? source['imageLinks']?['smallThumbnail'];
    if (thumb != null && thumb.isNotEmpty) {
      // 1) Si viene envuelta por el proxy de una sesión anterior (con host
      //    distinto al actual), extraer la URL original para no depender
      //    de "localhost:3000" guardado en la BD.
      final proxyMatch = RegExp(r'/proxy/image\?url=([^&]+)').firstMatch(thumb);
      if (proxyMatch != null) {
        try {
          thumb = Uri.decodeComponent(proxyMatch.group(1)!);
        } catch (_) {/* ignore */}
      }
      // 2) Forzamos https (los proveedores lo sirven igual).
      if (thumb!.startsWith('http://')) {
        thumb = thumb.replaceFirst('http://', 'https://');
      }
      // 3) Enrutamos por el proxy del backend en todas las plataformas.
      //    Además de evitar CORS en web, el proxy cachea las portadas y
      //    convierte en 404 las respuestas "200 OK con 1x1 px" que devuelven
      //    Open Library y Google Books cuando la portada no existe — así el
      //    cliente puede mostrar su placeholder en lugar de un hueco vacío.
      if (_isProxyableCover(thumb)) {
        thumb = '${ApiConstants.baseUrl}/proxy/image?url=${Uri.encodeComponent(thumb)}';
      }
    }

    return BookModel(
      id: json['id'],
      googleId: json['googleId'] ?? json['id']?.toString(),
      title: source['title'] ?? 'Sin título',
      subtitle: source['subtitle'],
      authors: parseStringList(source['authors']),
      description: source['description'],
      thumbnail: thumb,
      publisher: source['publisher'],
      publishedDate: source['publishedDate']?.toString(),
      pageCount: parsePages(source['pageCount']),
      categories: parseStringList(source['categories']),
      language: source['language'],
      averageRating: parseRating(source['averageRating']),
      ratingsCount: parsePages(source['ratingsCount']),
      isbn: source['isbn'] ?? (source['industryIdentifiers'] is List && (source['industryIdentifiers'] as List).isNotEmpty ? source['industryIdentifiers'][0]['identifier'] : null),
      asin: source['asin'],
      awards: source['awards'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'googleId': googleId,
      'title': title,
      'subtitle': subtitle,
      'authors': authors,
      'description': description,
      'thumbnail': thumbnail,
      'publisher': publisher,
      'publishedDate': publishedDate,
      'pageCount': pageCount,
      'categories': categories,
      'language': language,
      'averageRating': averageRating,
      'ratingsCount': ratingsCount,
      'isbn': isbn,
      'asin': asin,
      'awards': awards,
    };
  }
}
