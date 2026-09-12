import 'user_model.dart';

enum AppNotificationType {
  challengeInvite,
  challengeCategoryAdded,
  challengeBookPicked,
  challengeBookCompleted,
  challengeReviewed,
  challengeNotesUpdated,
  challengeMemberJoined,
  friendRequest,
  friendAccepted,
  recommendationReceived,
  groupInvite,
  groupMessage,
  unknown,
}

AppNotificationType notificationTypeFromString(String? s) {
  switch ((s ?? '').toUpperCase()) {
    case 'CHALLENGE_INVITE':
      return AppNotificationType.challengeInvite;
    case 'CHALLENGE_CATEGORY_ADDED':
      return AppNotificationType.challengeCategoryAdded;
    case 'CHALLENGE_BOOK_PICKED':
      return AppNotificationType.challengeBookPicked;
    case 'CHALLENGE_BOOK_COMPLETED':
      return AppNotificationType.challengeBookCompleted;
    case 'CHALLENGE_REVIEWED':
      return AppNotificationType.challengeReviewed;
    case 'CHALLENGE_NOTES_UPDATED':
      return AppNotificationType.challengeNotesUpdated;
    case 'CHALLENGE_MEMBER_JOINED':
      return AppNotificationType.challengeMemberJoined;
    case 'FRIEND_REQUEST':
      return AppNotificationType.friendRequest;
    case 'FRIEND_ACCEPTED':
      return AppNotificationType.friendAccepted;
    case 'RECOMMENDATION_RECEIVED':
      return AppNotificationType.recommendationReceived;
    case 'GROUP_INVITE':
      return AppNotificationType.groupInvite;
    case 'GROUP_MESSAGE':
      return AppNotificationType.groupMessage;
    default:
      return AppNotificationType.unknown;
  }
}

class NotificationModel {
  final int id;
  final AppNotificationType type;
  final String title;
  final String? body;
  final UserModel? actor;
  final String? refType;
  final int? refId;
  final bool read;
  final DateTime? createdAt;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.actor,
    this.refType,
    this.refId,
    required this.read,
    this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      type: notificationTypeFromString(json['type']?.toString()),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString(),
      actor: json['actor'] is Map<String, dynamic> ? UserModel.fromJson(json['actor']) : null,
      refType: json['refType']?.toString(),
      refId: json['refId'] is int ? json['refId'] : int.tryParse('${json['refId']}'),
      read: json['read'] == true,
      createdAt: json['createdAt'] != null ? DateTime.tryParse('${json['createdAt']}') : null,
    );
  }

  NotificationModel copyWith({bool? read}) => NotificationModel(
        id: id,
        type: type,
        title: title,
        body: body,
        actor: actor,
        refType: refType,
        refId: refId,
        read: read ?? this.read,
        createdAt: createdAt,
      );
}
