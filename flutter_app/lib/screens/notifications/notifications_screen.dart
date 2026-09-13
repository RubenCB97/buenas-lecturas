import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/notification_model.dart';
import '../../providers/notifications_provider.dart';
import '../challenges/challenge_detail_screen.dart';
import '../friends/friends_screen.dart';
import '../groups/group_detail_screen.dart';
import '../social/recommendations_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationsProvider>(context, listen: false).fetch();
    });
  }

  IconData _iconFor(AppNotificationType t) {
    switch (t) {
      case AppNotificationType.challengeInvite:
      case AppNotificationType.challengeMemberJoined:
        return Icons.emoji_events_rounded;
      case AppNotificationType.challengeCategoryAdded:
        return Icons.category_rounded;
      case AppNotificationType.challengeBookPicked:
        return Icons.menu_book_rounded;
      case AppNotificationType.challengeBookCompleted:
        return Icons.check_circle_rounded;
      case AppNotificationType.challengeReviewed:
        return Icons.star_rate_rounded;
      case AppNotificationType.challengeNotesUpdated:
        return Icons.sticky_note_2_rounded;
      case AppNotificationType.friendRequest:
      case AppNotificationType.friendAccepted:
        return Icons.people_rounded;
      case AppNotificationType.recommendationReceived:
        return Icons.recommend_rounded;
      case AppNotificationType.groupInvite:
      case AppNotificationType.groupMessage:
        return Icons.groups_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorFor(AppNotificationType t) {
    switch (t) {
      case AppNotificationType.challengeBookCompleted:
        return AppTheme.accentSage;
      case AppNotificationType.challengeReviewed:
        return AppTheme.starGold;
      case AppNotificationType.friendRequest:
      case AppNotificationType.friendAccepted:
        return const Color(0xFF3B82F6);
      case AppNotificationType.recommendationReceived:
        return const Color(0xFFDC2626);
      default:
        return AppTheme.primary;
    }
  }

  void _navigateForNotification(NotificationModel n) => openNotificationTarget(context, n);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NotificationsProvider>(context);
    final items = provider.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          if (provider.unread > 0)
            TextButton(
              onPressed: provider.markAllRead,
              child: const Text('Marcar todas leídas'),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: provider.fetch,
        child: provider.isLoading && items.isEmpty
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 100),
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(30),
                          child: Column(
                            children: [
                              Icon(Icons.notifications_off_rounded, size: 60, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('Sin notificaciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              SizedBox(height: 6),
                              Text('Aquí verás la actividad de tus retos, amigos y grupos.',
                                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final n = items[i];
                      final color = _colorFor(n.type);
                      return Dismissible(
                        key: ValueKey('notif_${n.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.redAccent,
                          child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                        ),
                        onDismissed: (_) => provider.remove(n.id),
                        child: ListTile(
                          tileColor: n.read ? null : color.withValues(alpha: 0.06),
                          leading: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                backgroundColor: color.withValues(alpha: 0.15),
                                child: Icon(_iconFor(n.type), color: color),
                              ),
                              if (!n.read)
                                Positioned(
                                  right: -1, top: -1,
                                  child: Container(
                                    width: 10, height: 10,
                                    decoration: BoxDecoration(
                                      color: color, shape: BoxShape.circle,
                                      border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w500 : FontWeight.bold, fontSize: 13.5)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (n.body != null && n.body!.isNotEmpty)
                                Text(n.body!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                              Text(DateFormatter.timeAgo(n.createdAt), style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                            ],
                          ),
                          onTap: () async {
                            if (!n.read) await provider.markRead(n.id);
                            if (mounted) _navigateForNotification(n);
                          },
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

/// Abre la pantalla relacionada con una notificación (también desde un push).
void openNotificationTarget(BuildContext context, NotificationModel n) {
  if (n.refType == 'challenge' && n.refId != null) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChallengeDetailScreen(challengeId: n.refId!)));
    return;
  }
  if (n.refType == 'group' && n.refId != null) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: n.refId!)));
    return;
  }
  if (n.type == AppNotificationType.friendRequest || n.type == AppNotificationType.friendAccepted) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendsScreen()));
    return;
  }
  if (n.type == AppNotificationType.recommendationReceived) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RecommendationsScreen()));
    return;
  }
  Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
}
