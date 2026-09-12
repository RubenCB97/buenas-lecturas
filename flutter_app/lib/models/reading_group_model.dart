import 'book_model.dart';
import 'user_model.dart';

enum GroupRole { owner, admin, member, none }

GroupRole groupRoleFromString(String? s) {
  switch ((s ?? '').toUpperCase()) {
    case 'OWNER':
      return GroupRole.owner;
    case 'ADMIN':
      return GroupRole.admin;
    case 'MEMBER':
      return GroupRole.member;
    default:
      return GroupRole.none;
  }
}

enum GroupBookStatus { upcoming, current, finished }

GroupBookStatus groupBookStatusFromString(String? s) {
  switch ((s ?? '').toUpperCase()) {
    case 'CURRENT':
      return GroupBookStatus.current;
    case 'FINISHED':
      return GroupBookStatus.finished;
    default:
      return GroupBookStatus.upcoming;
  }
}

String groupBookStatusValue(GroupBookStatus s) {
  switch (s) {
    case GroupBookStatus.current:
      return 'CURRENT';
    case GroupBookStatus.finished:
      return 'FINISHED';
    case GroupBookStatus.upcoming:
      return 'UPCOMING';
  }
}

class ReadingGroupMemberModel {
  final int id;
  final UserModel user;
  final GroupRole role;
  final DateTime? joinedAt;

  ReadingGroupMemberModel({required this.id, required this.user, required this.role, this.joinedAt});

  factory ReadingGroupMemberModel.fromJson(Map<String, dynamic> json) {
    return ReadingGroupMemberModel(
      id: (json['id'] is int) ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      user: UserModel.fromJson(json['user'] ?? {}),
      role: groupRoleFromString(json['role']),
      joinedAt: json['joinedAt'] != null ? DateTime.tryParse('${json['joinedAt']}') : null,
    );
  }
}

class GroupBookModel {
  final int id;
  final BookModel book;
  final DateTime? startDate;
  final DateTime? targetEndDate;
  final GroupBookStatus status;

  GroupBookModel({
    required this.id,
    required this.book,
    this.startDate,
    this.targetEndDate,
    required this.status,
  });

  factory GroupBookModel.fromJson(Map<String, dynamic> json) {
    return GroupBookModel(
      id: (json['id'] is int) ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      book: BookModel.fromJson(json['book'] ?? {}),
      startDate: json['startDate'] != null ? DateTime.tryParse('${json['startDate']}') : null,
      targetEndDate: json['targetEndDate'] != null ? DateTime.tryParse('${json['targetEndDate']}') : null,
      status: groupBookStatusFromString(json['status']),
    );
  }
}

class ReadingGroupModel {
  final int id;
  final String name;
  final String? description;
  final String coverColor;
  final bool isPrivate;
  final UserModel? owner;
  final GroupRole myRole;
  final List<ReadingGroupMemberModel> members;
  final List<GroupBookModel> books;
  final DateTime? createdAt;

  ReadingGroupModel({
    required this.id,
    required this.name,
    this.description,
    required this.coverColor,
    required this.isPrivate,
    this.owner,
    this.myRole = GroupRole.none,
    this.members = const [],
    this.books = const [],
    this.createdAt,
  });

  factory ReadingGroupModel.fromJson(Map<String, dynamic> json) {
    return ReadingGroupModel(
      id: (json['id'] is int) ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      coverColor: json['coverColor']?.toString() ?? '#C8602E',
      isPrivate: json['isPrivate'] == true,
      owner: json['owner'] is Map<String, dynamic> ? UserModel.fromJson(json['owner']) : null,
      myRole: groupRoleFromString(json['myRole']?.toString()),
      members: (json['members'] is List)
          ? (json['members'] as List).map((m) => ReadingGroupMemberModel.fromJson(m)).toList()
          : const [],
      books: (json['books'] is List)
          ? (json['books'] as List).map((b) => GroupBookModel.fromJson(b)).toList()
          : const [],
      createdAt: json['createdAt'] != null ? DateTime.tryParse('${json['createdAt']}') : null,
    );
  }
}

class GroupMessageModel {
  final int id;
  final UserModel user;
  final String content;
  final DateTime? createdAt;
  final int? chapterNumber;

  GroupMessageModel({
    required this.id,
    required this.user,
    required this.content,
    this.createdAt,
    this.chapterNumber,
  });

  factory GroupMessageModel.fromJson(Map<String, dynamic> json) {
    return GroupMessageModel(
      id: (json['id'] is int) ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      user: UserModel.fromJson(json['user'] ?? {}),
      content: json['content']?.toString() ?? '',
      chapterNumber: json['chapterNumber'] is int ? json['chapterNumber'] : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse('${json['createdAt']}') : null,
    );
  }
}

class GroupProgressEntry {
  final UserModel user;
  final GroupRole role;
  final int currentPage;
  final int totalPages;
  final double percentage;
  final String status;

  GroupProgressEntry({
    required this.user,
    required this.role,
    required this.currentPage,
    required this.totalPages,
    required this.percentage,
    required this.status,
  });

  factory GroupProgressEntry.fromJson(Map<String, dynamic> json) {
    return GroupProgressEntry(
      user: UserModel.fromJson(json['user'] ?? {}),
      role: groupRoleFromString(json['role']?.toString()),
      currentPage: json['currentPage'] is int ? json['currentPage'] : int.tryParse('${json['currentPage']}') ?? 0,
      totalPages: json['totalPages'] is int ? json['totalPages'] : int.tryParse('${json['totalPages']}') ?? 0,
      percentage: (json['percentage'] is num)
          ? (json['percentage'] as num).toDouble()
          : double.tryParse('${json['percentage']}') ?? 0,
      status: json['status']?.toString() ?? '',
    );
  }
}

class GroupProgressResponse {
  final BookModel? book;
  final int? groupBookId;
  final DateTime? targetEndDate;
  final List<GroupProgressEntry> ranking;

  GroupProgressResponse({this.book, this.groupBookId, this.targetEndDate, this.ranking = const []});

  factory GroupProgressResponse.fromJson(Map<String, dynamic> json) {
    return GroupProgressResponse(
      book: json['book'] is Map<String, dynamic> ? BookModel.fromJson(json['book']) : null,
      groupBookId: json['groupBookId'] is int ? json['groupBookId'] : null,
      targetEndDate: json['targetEndDate'] != null ? DateTime.tryParse('${json['targetEndDate']}') : null,
      ranking: (json['ranking'] is List)
          ? (json['ranking'] as List).map((e) => GroupProgressEntry.fromJson(e)).toList()
          : const [],
    );
  }
}
