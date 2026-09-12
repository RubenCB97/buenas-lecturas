import 'book_model.dart';
import 'user_model.dart';

enum ChallengeEntryStatus { notStarted, reading, completed }

ChallengeEntryStatus challengeEntryStatusFromString(String? s) {
  switch ((s ?? '').toUpperCase()) {
    case 'READING':
      return ChallengeEntryStatus.reading;
    case 'COMPLETED':
      return ChallengeEntryStatus.completed;
    default:
      return ChallengeEntryStatus.notStarted;
  }
}

String challengeEntryStatusValue(ChallengeEntryStatus s) {
  switch (s) {
    case ChallengeEntryStatus.reading:
      return 'READING';
    case ChallengeEntryStatus.completed:
      return 'COMPLETED';
    case ChallengeEntryStatus.notStarted:
      return 'NOT_STARTED';
  }
}

class ChallengeCategoryModel {
  final int id;
  final String name;
  final String icon;
  final String? description;
  final UserModel? createdBy;
  final int order;

  ChallengeCategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    this.description,
    this.createdBy,
    this.order = 0,
  });

  factory ChallengeCategoryModel.fromJson(Map<String, dynamic> json) {
    return ChallengeCategoryModel(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      name: json['name']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '📖',
      description: json['description']?.toString(),
      createdBy: json['createdBy'] is Map<String, dynamic> ? UserModel.fromJson(json['createdBy']) : null,
      order: json['order'] is int ? json['order'] : int.tryParse('${json['order']}') ?? 0,
    );
  }
}

class ChallengeParticipantModel {
  final int id;
  final UserModel user;
  final String? notes;
  final DateTime? joinedAt;

  ChallengeParticipantModel({required this.id, required this.user, this.notes, this.joinedAt});

  factory ChallengeParticipantModel.fromJson(Map<String, dynamic> json) {
    return ChallengeParticipantModel(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      user: UserModel.fromJson(json['user'] ?? {}),
      notes: json['notes']?.toString(),
      joinedAt: json['joinedAt'] != null ? DateTime.tryParse('${json['joinedAt']}') : null,
    );
  }
}

class ChallengeEntryModel {
  final int id;
  final int userId;
  final int categoryId;
  final BookModel? book;
  final ChallengeEntryStatus status;
  // Admite medios puntos: 0.5, 1.0, 1.5, ..., 5.0
  final double? rating;
  final String? comment;
  final DateTime? completedAt;

  ChallengeEntryModel({
    required this.id,
    required this.userId,
    required this.categoryId,
    this.book,
    required this.status,
    this.rating,
    this.comment,
    this.completedAt,
  });

  factory ChallengeEntryModel.fromJson(Map<String, dynamic> json) {
    int extractId(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is Map<String, dynamic>) {
        final id = v['id'];
        if (id is int) return id;
        return int.tryParse('$id') ?? 0;
      }
      return int.tryParse('$v') ?? 0;
    }

    return ChallengeEntryModel(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      userId: extractId(json['user']),
      categoryId: extractId(json['category']),
      book: json['book'] is Map<String, dynamic> ? BookModel.fromJson(json['book']) : null,
      status: challengeEntryStatusFromString(json['status']?.toString()),
      rating: (json['rating'] is num) ? (json['rating'] as num).toDouble() : double.tryParse('${json['rating'] ?? ''}'),
      comment: json['comment']?.toString(),
      completedAt: json['completedAt'] != null ? DateTime.tryParse('${json['completedAt']}') : null,
    );
  }
}

class ChallengeSummaryModel {
  final int id;
  final String name;
  final String? description;
  final String coverColor;
  final UserModel? owner;
  final DateTime? startDate;
  final DateTime? endDate;
  final int participantsCount;
  final int categoriesCount;
  final int myCompletedCount;

  ChallengeSummaryModel({
    required this.id,
    required this.name,
    this.description,
    required this.coverColor,
    this.owner,
    this.startDate,
    this.endDate,
    this.participantsCount = 0,
    this.categoriesCount = 0,
    this.myCompletedCount = 0,
  });

  factory ChallengeSummaryModel.fromJson(Map<String, dynamic> json) {
    return ChallengeSummaryModel(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      coverColor: json['coverColor']?.toString() ?? '#C8602E',
      owner: json['owner'] is Map<String, dynamic> ? UserModel.fromJson(json['owner']) : null,
      startDate: json['startDate'] != null ? DateTime.tryParse('${json['startDate']}') : null,
      endDate: json['endDate'] != null ? DateTime.tryParse('${json['endDate']}') : null,
      participantsCount: json['participantsCount'] is int ? json['participantsCount'] : 0,
      categoriesCount: json['categoriesCount'] is int ? json['categoriesCount'] : 0,
      myCompletedCount: json['myCompletedCount'] is int ? json['myCompletedCount'] : 0,
    );
  }
}

/// Detalle completo del reto con todo lo necesario para pintar la tabla.
class ChallengeDetailModel {
  final ChallengeSummaryModel challenge;
  final List<ChallengeParticipantModel> participants;
  final List<ChallengeCategoryModel> categories;
  final List<ChallengeEntryModel> entries;
  final bool isParticipant;
  final bool isOwner;

  ChallengeDetailModel({
    required this.challenge,
    required this.participants,
    required this.categories,
    required this.entries,
    required this.isParticipant,
    required this.isOwner,
  });

  factory ChallengeDetailModel.fromJson(Map<String, dynamic> json) {
    return ChallengeDetailModel(
      challenge: ChallengeSummaryModel.fromJson(json['challenge'] ?? {}),
      participants: (json['participants'] as List? ?? []).map((e) => ChallengeParticipantModel.fromJson(e)).toList(),
      categories: (json['categories'] as List? ?? []).map((e) => ChallengeCategoryModel.fromJson(e)).toList(),
      entries: (json['entries'] as List? ?? []).map((e) => ChallengeEntryModel.fromJson(e)).toList(),
      isParticipant: json['isParticipant'] == true,
      isOwner: json['isOwner'] == true,
    );
  }

  /// Devuelve la entrada (celda) para un usuario y categoría, si existe.
  ChallengeEntryModel? entryFor(int userId, int categoryId) {
    try {
      return entries.firstWhere((e) => e.userId == userId && e.categoryId == categoryId);
    } catch (_) {
      return null;
    }
  }

  int completedByUser(int userId) => entries.where((e) => e.userId == userId && e.status == ChallengeEntryStatus.completed).length;
}
