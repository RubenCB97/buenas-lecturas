import 'book_model.dart';
import 'user_model.dart';

class QuoteModel {
  final int id;
  final UserModel? user;
  final BookModel? book;
  final String text;
  final int? page;
  final int likesCount;
  final DateTime? createdAt;

  QuoteModel({
    required this.id,
    this.user,
    this.book,
    required this.text,
    this.page,
    this.likesCount = 0,
    this.createdAt,
  });

  factory QuoteModel.fromJson(Map<String, dynamic> json) {
    return QuoteModel(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      user: json['user'] is Map<String, dynamic> ? UserModel.fromJson(json['user']) : null,
      book: json['book'] is Map<String, dynamic> ? BookModel.fromJson(json['book']) : null,
      text: json['text']?.toString() ?? '',
      page: json['page'] is int ? json['page'] : int.tryParse('${json['page']}'),
      likesCount: json['likesCount'] is int ? json['likesCount'] : 0,
      createdAt: json['createdAt'] != null ? DateTime.tryParse('${json['createdAt']}') : null,
    );
  }
}
