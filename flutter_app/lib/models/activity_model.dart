import 'book_model.dart';
import 'user_model.dart';

class ActivityModel {
  final int id;
  final String action;
  final String details;
  final UserModel? user;
  final BookModel? book;
  final DateTime? createdAt;
  final int likesCount;
  final int commentsCount;
  final bool likedByMe;

  ActivityModel({
    required this.id,
    required this.action,
    required this.details,
    this.user,
    this.book,
    this.createdAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.likedByMe = false,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      action: json['action']?.toString() ?? 'Actualización',
      details: json['details']?.toString() ?? '',
      user: json['user'] is Map<String, dynamic> ? UserModel.fromJson(json['user']) : null,
      book: json['book'] is Map<String, dynamic> ? BookModel.fromJson(json['book']) : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse('${json['createdAt']}') : null,
      likesCount: json['likesCount'] is int ? json['likesCount'] : 0,
      commentsCount: json['commentsCount'] is int ? json['commentsCount'] : 0,
      likedByMe: json['likedByMe'] == true,
    );
  }

  ActivityModel copyWith({int? likesCount, int? commentsCount, bool? likedByMe}) {
    return ActivityModel(
      id: id,
      action: action,
      details: details,
      user: user,
      book: book,
      createdAt: createdAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      likedByMe: likedByMe ?? this.likedByMe,
    );
  }
}

class ActivityCommentModel {
  final int id;
  final UserModel? user;
  final String content;
  final DateTime? createdAt;

  ActivityCommentModel({required this.id, this.user, required this.content, this.createdAt});

  factory ActivityCommentModel.fromJson(Map<String, dynamic> json) {
    return ActivityCommentModel(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      user: json['user'] is Map<String, dynamic> ? UserModel.fromJson(json['user']) : null,
      content: json['content']?.toString() ?? '',
      createdAt: json['createdAt'] != null ? DateTime.tryParse('${json['createdAt']}') : null,
    );
  }
}
