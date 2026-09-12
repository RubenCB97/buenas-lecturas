import 'user_model.dart';

enum FriendshipStatus { none, pendingOut, pendingIn, friends, blocked }

FriendshipStatus friendshipStatusFromString(String? s) {
  switch ((s ?? '').toUpperCase()) {
    case 'PENDING_OUT':
      return FriendshipStatus.pendingOut;
    case 'PENDING_IN':
      return FriendshipStatus.pendingIn;
    case 'FRIENDS':
    case 'ACCEPTED':
      return FriendshipStatus.friends;
    case 'BLOCKED':
      return FriendshipStatus.blocked;
    default:
      return FriendshipStatus.none;
  }
}

class FriendshipModel {
  final int id;
  final UserModel requester;
  final UserModel recipient;
  final FriendshipStatus status;
  final DateTime? createdAt;

  FriendshipModel({
    required this.id,
    required this.requester,
    required this.recipient,
    required this.status,
    this.createdAt,
  });

  factory FriendshipModel.fromJson(Map<String, dynamic> json) {
    return FriendshipModel(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      requester: UserModel.fromJson(json['requester'] ?? {}),
      recipient: UserModel.fromJson(json['recipient'] ?? {}),
      status: friendshipStatusFromString(json['status']),
      createdAt: json['createdAt'] != null ? DateTime.tryParse('${json['createdAt']}') : null,
    );
  }
}
