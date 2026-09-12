import 'book_model.dart';
import 'user_model.dart';

class RecommendationModel {
  final int id;
  final UserModel? fromUser;
  final UserModel? toUser;
  final BookModel? book;
  final String? note;
  final bool seen;
  final DateTime? createdAt;

  RecommendationModel({
    required this.id,
    this.fromUser,
    this.toUser,
    this.book,
    this.note,
    this.seen = false,
    this.createdAt,
  });

  factory RecommendationModel.fromJson(Map<String, dynamic> json) {
    return RecommendationModel(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      fromUser: json['fromUser'] is Map<String, dynamic> ? UserModel.fromJson(json['fromUser']) : null,
      toUser: json['toUser'] is Map<String, dynamic> ? UserModel.fromJson(json['toUser']) : null,
      book: json['book'] is Map<String, dynamic> ? BookModel.fromJson(json['book']) : null,
      note: json['note']?.toString(),
      seen: json['seen'] == true,
      createdAt: json['createdAt'] != null ? DateTime.tryParse('${json['createdAt']}') : null,
    );
  }
}
