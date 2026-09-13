import 'book_model.dart';

enum ReadingStatus {
  wantToRead,
  reading,
  read,

  /// Empezado y dejado sin terminar.
  abandoned,
}

extension ReadingStatusExtension on ReadingStatus {
  String get value {
    switch (this) {
      case ReadingStatus.wantToRead:
        return 'WANT_TO_READ';
      case ReadingStatus.reading:
        return 'READING';
      case ReadingStatus.read:
        return 'READ';
      case ReadingStatus.abandoned:
        return 'ABANDONED';
    }
  }

  String get label {
    switch (this) {
      case ReadingStatus.wantToRead:
        return 'Quiero leer';
      case ReadingStatus.reading:
        return 'Leyendo';
      case ReadingStatus.read:
        return 'Leído';
      case ReadingStatus.abandoned:
        return 'No lo terminé';
    }
  }

  static ReadingStatus fromString(String? status) {
    if (status == null) return ReadingStatus.wantToRead;
    switch (status.toUpperCase()) {
      case 'READING':
        return ReadingStatus.reading;
      case 'READ':
        return ReadingStatus.read;
      case 'ABANDONED':
        return ReadingStatus.abandoned;
      case 'WANT_TO_READ':
      default:
        return ReadingStatus.wantToRead;
    }
  }
}

class UserBookModel {
  final int id;
  final BookModel book;
  final ReadingStatus status;
  final double? rating;
  final int? currentPage;
  final String? notes;
  final bool isFavorite;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserBookModel({
    required this.id,
    required this.book,
    required this.status,
    this.rating,
    // NOTE: rating admite 0.5, 1.0, 1.5, ..., 5.0
    this.currentPage,
    this.notes,
    this.isFavorite = false,
    this.startedAt,
    this.finishedAt,
    this.createdAt,
    this.updatedAt,
  });

  /// Progreso real de lectura entre 0 y 1.
  ///
  /// Sin páginas leídas es 0%: no inventamos un mínimo para que la barra
  /// "no se vea vacía". Si el libro no tiene total de páginas conocido se usa
  /// la misma estimación que la hoja de actualizar progreso, para que el
  /// porcentaje coincida con lo que el usuario vio al guardarlo.
  double get progressPercentage {
    if (status == ReadingStatus.read) return 1.0;
    final pages = currentPage ?? 0;
    if (pages <= 0) return 0.0;
    return (pages / book.effectivePageCount).clamp(0.0, 1.0);
  }

  factory UserBookModel.fromJson(Map<String, dynamic> json) {
    final bookData = json['book'] is Map<String, dynamic>
        ? json['book'] as Map<String, dynamic>
        : json;

    int? parseInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    double? parseDouble(dynamic v) {
      if (v is double) return v;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return UserBookModel(
      id: parseInt(json['id']) ?? 0,
      book: BookModel.fromJson(bookData),
      status: ReadingStatusExtension.fromString(json['status']?.toString()),
      rating: parseDouble(json['rating']),
      currentPage: parseInt(json['currentPage']),
      notes: json['notes']?.toString(),
      isFavorite: json['isFavorite'] == true,
      startedAt: parseDate(json['startedAt']),
      finishedAt: parseDate(json['finishedAt']),
      createdAt: parseDate(json['addedAt'] ?? json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  UserBookModel copyWith({
    ReadingStatus? status,
    double? rating,
    int? currentPage,
    String? notes,
    bool? isFavorite,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) {
    return UserBookModel(
      id: id,
      book: book,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      currentPage: currentPage ?? this.currentPage,
      notes: notes ?? this.notes,
      isFavorite: isFavorite ?? this.isFavorite,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
