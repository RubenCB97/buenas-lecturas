import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/network/api_client.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/deep_link.dart';
import '../models/book_model.dart';
import '../providers/friends_provider.dart';
import '../providers/library_provider.dart';
import '../providers/notifications_provider.dart';
import '../providers/social_provider.dart';
import 'book_detail/book_detail_screen.dart';
import 'challenges/challenges_screen.dart';
import 'discover/discover_screen.dart';
import 'explore/explore_screen.dart';
import 'friends/friends_screen.dart';
import 'groups/groups_screen.dart';
import 'library/library_screen.dart';
import 'profile/profile_screen.dart';
import 'social/feed_screen.dart';
import 'social/quotes_screen.dart';
import 'notifications/notifications_screen.dart';
import 'social/recommendations_screen.dart';
import 'social/shelves_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    ExploreScreen(),
    DiscoverScreen(),
    LibraryScreen(),
    _CommunityHub(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LibraryProvider>(context, listen: false).fetchLibrary();
      Provider.of<FriendsProvider>(context, listen: false).fetchAll();
      Provider.of<SocialProvider>(context, listen: false).fetchRecommendations();
      Provider.of<NotificationsProvider>(context, listen: false).startPolling();
      _openLinkedBook();
    });
  }

  /// Si la app se abrió con un enlace a un libro (/libro/<id>), abre su ficha.
  Future<void> _openLinkedBook() async {
    final id = DeepLink.consumePendingBookId();
    if (id == null) return;
    final r = await ApiClient().get('/books/lookup/${Uri.encodeComponent(id)}', requiresAuth: false);
    if (!mounted) return;
    if (r.success && r.data is Map<String, dynamic>) {
      final book = BookModel.fromJson(r.data as Map<String, dynamic>);
      Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hemos podido abrir el libro del enlace')),
      );
    }
  }

  @override
  void dispose() {
    Provider.of<NotificationsProvider>(context, listen: false).stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final libraryProvider = Provider.of<LibraryProvider>(context);
    final friendsProvider = Provider.of<FriendsProvider>(context);
    final socialProvider = Provider.of<SocialProvider>(context);
    final pendingBadges = friendsProvider.pendingCount + socialProvider.unseenRecommendations;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore_rounded),
              label: 'Explorar',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome_outlined),
              activeIcon: Icon(Icons.auto_awesome),
              label: 'Descubrir',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.collections_bookmark_outlined),
                  if (libraryProvider.countReading > 0)
                    Positioned(
                      top: -2, right: -4,
                      child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle)),
                    ),
                ],
              ),
              activeIcon: const Icon(Icons.collections_bookmark_rounded),
              label: 'Biblioteca',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.people_outline_rounded),
                  if (pendingBadges > 0)
                    Positioned(
                      top: -4, right: -6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                        child: Text('$pendingBadges', style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      ),
                    ),
                ],
              ),
              activeIcon: const Icon(Icons.people_rounded),
              label: 'Comunidad',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

/// Hub interno de la sección "Comunidad" con feed y accesos a lo social.
class _CommunityHub extends StatelessWidget {
  const _CommunityHub();

  void _navigate(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final social = Provider.of<SocialProvider>(context);
    final friends = Provider.of<FriendsProvider>(context);
    final notifications = Provider.of<NotificationsProvider>(context);
    final unseenRecs = social.unseenRecommendations;

    return DefaultTabController(
      length: 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Comunidad'),
          actions: [
            IconButton(
              tooltip: 'Notificaciones',
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_none_rounded),
                  if (notifications.unread > 0)
                    Positioned(top: -4, right: -4, child: _dot(text: '${notifications.unread}')),
                ],
              ),
              onPressed: () => _navigate(context, const NotificationsScreen()),
            ),
            IconButton(
              tooltip: 'Amigos',
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.people_alt_outlined),
                  if (friends.pendingCount > 0)
                    Positioned(top: -4, right: -4, child: _dot(text: '${friends.pendingCount}')),
                ],
              ),
              onPressed: () => _navigate(context, const FriendsScreen()),
            ),
            IconButton(
              tooltip: 'Recomendaciones',
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.recommend_outlined),
                  if (unseenRecs > 0)
                    Positioned(top: -4, right: -4, child: _dot(text: '$unseenRecs')),
                ],
              ),
              onPressed: () => _navigate(context, const RecommendationsScreen()),
            ),
          ],
        ),
        body: Column(
          children: [
            SizedBox(
              height: 92,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  _quickTile(context, Icons.emoji_events_rounded, 'Reto lector', const Color(0xFFF59E0B), () => _navigate(context, const ChallengesScreen())),
                  _quickTile(context, Icons.groups_rounded, 'Clubes', AppTheme.primary, () => _navigate(context, const GroupsScreen())),
                  _quickTile(context, Icons.people_rounded, 'Amigos', AppTheme.accentSage, () => _navigate(context, const FriendsScreen())),
                  _quickTile(context, Icons.format_quote_rounded, 'Citas', const Color(0xFF7C3AED), () => _navigate(context, const QuotesScreen())),
                  _quickTile(context, Icons.library_books_rounded, 'Estanterías', const Color(0xFF3B82F6), () => _navigate(context, const ShelvesScreen())),
                  _quickTile(context, Icons.recommend_rounded, 'Recomendaciones', const Color(0xFFDC2626), () => _navigate(context, const RecommendationsScreen())),
                ],
              ),
            ),
            const Divider(height: 1),
            const Expanded(child: FeedScreen()),
          ],
        ),
      ),
    );
  }

  Widget _dot({required String text}) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
    );
  }

  Widget _quickTile(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      width: 84,
      child: Material(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 6),
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
