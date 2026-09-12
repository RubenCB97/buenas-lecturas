import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/activity_model.dart';
import '../../providers/social_provider.dart';
import '../book_detail/book_detail_screen.dart';
import '../friends/user_profile_screen.dart';
import 'activity_comments_sheet.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SocialProvider>(context, listen: false).fetchFeed();
    });
  }

  IconData _iconFor(String action) {
    switch (action.toUpperCase()) {
      case 'ADDED': return Icons.bookmark_added_rounded;
      case 'UPDATED_STATUS': return Icons.swap_horiz_rounded;
      case 'RATED': return Icons.star_rounded;
      case 'PROGRESS': return Icons.auto_stories_rounded;
      case 'FAVORITED': return Icons.favorite_rounded;
      case 'REMOVED': return Icons.delete_outline_rounded;
    }
    return Icons.bookmark_added_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final social = Provider.of<SocialProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: social.fetchFeed,
      child: social.loadingFeed
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : social.feed.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 100),
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(30),
                        child: Column(
                          children: [
                            Icon(Icons.dynamic_feed_rounded, size: 60, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('Feed vacío', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            SizedBox(height: 6),
                            Text('Sigue a otros lectores para ver aquí su actividad.',
                                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  itemCount: social.feed.length,
                  itemBuilder: (context, i) => _card(social.feed[i], social, isDark),
                ),
    );
  }

  Widget _card(ActivityModel a, SocialProvider social, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (a.user != null) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: a.user!.id, initialUser: a.user)));
                    }
                  },
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.primaryLight,
                    backgroundImage: a.user?.picture != null && a.user!.picture!.isNotEmpty ? NetworkImage(a.user!.avatarUrl) : null,
                    child: a.user?.picture == null || a.user!.picture!.isEmpty
                        ? Text(a.user?.fullName.isNotEmpty == true ? a.user!.fullName[0].toUpperCase() : '?',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary))
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.user?.fullName ?? 'Lector', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      Text(DateFormatter.timeAgo(a.createdAt),
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                Icon(_iconFor(a.action), color: AppTheme.primary, size: 18),
              ],
            ),
            const SizedBox(height: 10),
            Text(a.details, style: const TextStyle(fontSize: 13.5)),
            if (a.book != null) ...[
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailScreen(book: a.book!))),
                child: Row(
                  children: [
                    if (a.book!.thumbnail != null && a.book!.thumbnail!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(a.book!.thumbnail!, width: 36, height: 52, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 36, height: 52)),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(a.book!.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                InkWell(
                  onTap: () => social.toggleLike(a.id),
                  borderRadius: BorderRadius.circular(30),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          a.likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          size: 16,
                          color: a.likedByMe ? Colors.redAccent : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text('${a.likesCount}', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                      builder: (_) => ActivityCommentsSheet(activityId: a.id),
                    );
                  },
                  borderRadius: BorderRadius.circular(30),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: const [
                        Icon(Icons.mode_comment_outlined, size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),
                Text('${a.commentsCount}', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
