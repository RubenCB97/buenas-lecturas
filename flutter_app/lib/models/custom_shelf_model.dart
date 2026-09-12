import 'book_model.dart';

class CustomShelfModel {
  final int id;
  final String name;
  final String icon;
  final List<BookModel> books;

  CustomShelfModel({
    required this.id,
    required this.name,
    required this.icon,
    this.books = const [],
  });

  factory CustomShelfModel.fromJson(Map<String, dynamic> json) {
    return CustomShelfModel(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      name: json['name']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '📚',
      books: (json['books'] is List)
          ? (json['books'] as List).map((b) => BookModel.fromJson(b)).toList()
          : const [],
    );
  }
}
