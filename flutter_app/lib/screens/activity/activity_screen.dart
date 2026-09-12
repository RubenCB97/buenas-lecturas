import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/profile_provider.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProfileProvider>(context, listen: false).fetchActivities();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileProvider = Provider.of<ProfileProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comunidad & Actividad'),
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () => profileProvider.fetchActivities(),
        child: profileProvider.isLoadingActivities
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : profileProvider.activities.isEmpty
                ? _buildEmptyState(context)
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    itemCount: profileProvider.activities.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final act = profileProvider.activities[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: const BoxDecoration(
                                  color: AppTheme.primaryLight,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getActivityIcon(act.action),
                                  color: AppTheme.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          act.action,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          DateFormatter.timeAgo(act.createdAt),
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      act.details,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  IconData _getActivityIcon(String action) {
    final upper = action.toUpperCase();
    switch (upper) {
      case 'ADDED':
        return Icons.bookmark_added_rounded;
      case 'UPDATED_STATUS':
        return Icons.swap_horiz_rounded;
      case 'RATED':
        return Icons.star_rounded;
      case 'PROGRESS':
        return Icons.auto_stories_rounded;
      case 'FAVORITED':
        return Icons.favorite_rounded;
      case 'REMOVED':
        return Icons.delete_outline_rounded;
    }
    final lower = action.toLowerCase();
    if (lower.contains('leyendo') || lower.contains('empezó')) {
      return Icons.auto_stories_rounded;
    } else if (lower.contains('puntuó') || lower.contains('estrella')) {
      return Icons.star_rounded;
    } else if (lower.contains('reseña')) {
      return Icons.rate_review_rounded;
    } else if (lower.contains('terminó') || lower.contains('leído')) {
      return Icons.check_circle_rounded;
    }
    return Icons.bookmark_added_rounded;
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.forum_outlined, size: 50, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Sin actividad reciente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              'A medida que leas libros y los califiques, aparecerán aquí tus actualizaciones y las de tus amigos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
