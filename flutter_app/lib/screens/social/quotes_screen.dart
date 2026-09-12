import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/quote_model.dart';
import '../../providers/social_provider.dart';

class QuotesScreen extends StatefulWidget {
  const QuotesScreen({super.key});

  @override
  State<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = Provider.of<SocialProvider>(context, listen: false);
      s.fetchQuotesFeed();
      s.fetchMyQuotes();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final social = Provider.of<SocialProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Citas'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(text: 'De mis amigos (${social.quotesFeed.length})'),
            Tab(text: 'Mis citas (${social.myQuotes.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildList(social.quotesFeed, isDark, showAuthor: true, allowDelete: false),
          _buildList(social.myQuotes, isDark, showAuthor: false, allowDelete: true),
        ],
      ),
    );
  }

  Widget _buildList(List<QuoteModel> list, bool isDark, {required bool showAuthor, required bool allowDelete}) {
    if (list.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.format_quote_rounded, size: 60, color: Colors.grey),
              SizedBox(height: 12),
              Text('Sin citas todavía', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('Añade citas desde la ficha de un libro que hayas leído.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final q = list[i];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.format_quote_rounded, color: AppTheme.primary),
                const SizedBox(height: 6),
                Text('"${q.text}"',
                    style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic, height: 1.4)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (q.book != null) ...[
                      const Icon(Icons.menu_book_rounded, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${q.book!.title}${q.page != null ? ' · p. ${q.page}' : ''}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else const Spacer(),
                    if (showAuthor && q.user != null)
                      Text('— ${q.user!.fullName}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    if (allowDelete)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                        onPressed: () => Provider.of<SocialProvider>(context, listen: false).deleteQuote(q.id),
                      ),
                  ],
                ),
                if (q.createdAt != null)
                  Text(DateFormatter.timeAgo(q.createdAt), style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }
}
