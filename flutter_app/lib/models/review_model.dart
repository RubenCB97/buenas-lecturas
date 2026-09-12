import 'user_model.dart';
import 'book_model.dart';

class ReviewModel {
  final int id;
  final UserModel? user;
  final BookModel? book;
  final String content;
  final double rating;
  final DateTime? createdAt;

  ReviewModel({
    required this.id,
    this.user,
    this.book,
    required this.content,
    required this.rating,
    this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      user: json['user'] != null && json['user'] is Map<String, dynamic> 
          ? UserModel.fromJson(json['user']) 
          : null,
      book: json['book'] != null && json['book'] is Map<String, dynamic> 
          ? BookModel.fromJson(json['book']) 
          : null,
      content: json['content'] ?? '',
      rating: json['rating'] is num ? (json['rating'] as num).toDouble() : double.tryParse(json['rating']?.toString() ?? '5') ?? 5.0,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }
}
