import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/social_provider.dart';
import '../../widgets/book_cover_image.dart';
import '../book_detail/book_detail_screen.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SocialProvider>(context, listen: false).fetchRecommendations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final social = Provider.of<SocialProvider>(context);
    final list = social.recommendations;

    return Scaffold(
      appBar: AppBar(title: const Text('Recomendaciones')),
      body: list.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.recommend_outlined, size: 60, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('Sin recomendaciones', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    Text('Cuando un amigo te recomiende un libro aparecerá aquí.',
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final r = list[i];
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      if (!r.seen) await social.markSeen(r.id);
                      if (r.book != null && mounted) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailScreen(book: r.book!)));
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BookCoverImage(imageUrl: r.book?.thumbnail, width: 54, height: 80, borderRadius: 6, title: r.book?.title ?? ''),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (!r.seen)
                                      Container(
                                        margin: const EdgeInsets.only(right: 6),
                                        width: 8, height: 8,
                                        decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                                      ),
                                    Expanded(
                                      child: Text(
                                        '${r.fromUser?.fullName ?? 'Alguien'} te recomienda:',
                                        style: TextStyle(fontSize: 12, fontWeight: r.seen ? FontWeight.w500 : FontWeight.bold, color: r.seen ? Colors.grey : AppTheme.primary),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(r.book?.title ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                if (r.note != null && r.note!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text('"${r.note}"', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12.5)),
                                ],
                                if (r.createdAt != null) ...[
                                  const SizedBox(height: 4),
                                  Text(DateFormatter.timeAgo(r.createdAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
