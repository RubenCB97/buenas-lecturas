import '../core/constants/api_constants.dart';
import 'book_model.dart';

class AuthorModel {
  final String name;
  final String? olid;
  final String? photoUrl;
  final String? bio;
  final String? birthDate;
  final String? deathDate;
  final String? topWork;
  final int? workCount;
  final List<String> subjects;
  final List<BookModel> books;
  final int booksCount;
  final double? averageRating;

  AuthorModel({
    required this.name,
    this.olid,
    this.photoUrl,
    this.bio,
    this.birthDate,
    this.deathDate,
    this.topWork,
    this.workCount,
    this.subjects = const [],
    this.books = const [],
    this.booksCount = 0,
    this.averageRating,
  });

  /// Años de vida en formato "1899 — 1961" o "1965 —" si sigue vivo.
  String? get lifespan {
    if (birthDate == null && deathDate == null) return null;
    if (deathDate == null) return birthDate;
    return '$birthDate — $deathDate';
  }

  /// Enrutamos la foto por el proxy del backend: evita CORS en web, la cachea
  /// y convierte en 404 las respuestas "200 OK con 1x1 px" que devuelve
  /// Open Library cuando el autor no tiene foto, para que se vea la inicial.
  static String? _normalizePhoto(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var url = raw.trim();
    if (url.startsWith('http://')) {
      url = url.replaceFirst('http://', 'https://');
    }
    if (url.contains('covers.openlibrary.org')) {
      return '${ApiConstants.baseUrl}/proxy/image?url=${Uri.encodeComponent(url)}';
    }
    return url;
  }

  factory AuthorModel.fromJson(Map<String, dynamic> json) {
    return AuthorModel(
      name: json['name']?.toString() ?? '',
      olid: json['olid']?.toString(),
      photoUrl: _normalizePhoto(json['photoUrl']?.toString()),
      bio: json['bio']?.toString(),
      birthDate: json['birthDate']?.toString(),
      deathDate: json['deathDate']?.toString(),
      topWork: json['topWork']?.toString(),
      workCount: json['workCount'] is int ? json['workCount'] : int.tryParse('${json['workCount']}'),
      subjects: (json['subjects'] is List)
          ? (json['subjects'] as List).map((e) => e.toString()).toList()
          : const [],
      books: (json['books'] is List)
          ? (json['books'] as List).map((e) => BookModel.fromJson(e)).toList()
          : const [],
      booksCount: json['booksCount'] is int ? json['booksCount'] : 0,
      averageRating: (json['averageRating'] is num)
          ? (json['averageRating'] as num).toDouble()
          : double.tryParse('${json['averageRating'] ?? ''}'),
    );
  }
}
