import '../core/constants/api_constants.dart';

class UserModel {
  final dynamic id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? picture;
  final String? bio;
  final String? favoriteGenre;
  final int readingGoal;

  UserModel({
    this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.picture,
    this.bio,
    this.favoriteGenre,
    this.readingGoal = 20,
  });

  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName'.trim();
    }
    return firstName ?? email.split('@').first;
  }

  /// URL absoluta de la foto de perfil.
  ///
  /// Los avatares subidos se guardan como ruta relativa (`/uploads/avatars/…`)
  /// para no atarlos a un host concreto, así que la resolvemos contra el
  /// backend actual. Las externas (Google) se devuelven tal cual.
  String get avatarUrl {
    final p = picture?.trim();
    if (p == null || p.isEmpty) return '';
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    return '${ApiConstants.baseUrl}${p.startsWith('/') ? p : '/$p'}';
  }

  /// Indica si el usuario tiene foto (para decidir si mostrar la inicial).
  bool get hasAvatar => avatarUrl.isNotEmpty;

  /// Inicial para el avatar por defecto.
  String get initial {
    final name = fullName.trim();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'] ?? '',
      firstName: json['firstName'],
      lastName: json['lastName'],
      picture: json['picture'],
      bio: json['bio'],
      favoriteGenre: json['favoriteGenre'],
      readingGoal: json['readingGoal'] is num ? (json['readingGoal'] as num).toInt() : 20,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'picture': picture,
      'bio': bio,
      'favoriteGenre': favoriteGenre,
      'readingGoal': readingGoal,
    };
  }

  UserModel copyWith({
    String? firstName,
    String? lastName,
    String? picture,
    String? bio,
    String? favoriteGenre,
    int? readingGoal,
  }) {
    return UserModel(
      id: id,
      email: email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      picture: picture ?? this.picture,
      bio: bio ?? this.bio,
      favoriteGenre: favoriteGenre ?? this.favoriteGenre,
      readingGoal: readingGoal ?? this.readingGoal,
    );
  }
}
