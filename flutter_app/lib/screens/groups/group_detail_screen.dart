import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/reading_group_model.dart';
import '../../providers/groups_provider.dart';
import '../../widgets/book_cover_image.dart';
import '../../widgets/reading_progress_bar.dart';
import '../book_detail/book_detail_screen.dart';
import 'group_chat_screen.dart';
import 'select_book_for_group_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final int groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GroupsProvider>(context, listen: false).loadGroup(widget.groupId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GroupsProvider>(context);
    final g = provider.selectedGroup;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (provider.isLoading || g == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primary)));
    }

    final color = Color(int.parse(g.coverColor.replaceFirst('#', 'FF'), radix: 16));

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 180,
            backgroundColor: color,
            foregroundColor: Colors.white,
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'leave') {
                    await provider.leaveGroup(widget.groupId);
                    if (mounted) Navigator.pop(context);
                  }
                  if (v == 'delete') {
                    await provider.deleteGroup(widget.groupId);
                    if (mounted) Navigator.pop(context);
                  }
                },
                itemBuilder: (_) => [
                  if (g.myRole != GroupRole.owner) const PopupMenuItem(value: 'leave', child: Text('Salir del grupo')),
                  if (g.myRole == GroupRole.owner) const PopupMenuItem(value: 'delete', child: Text('Eliminar grupo')),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(g.name),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.75)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 60),
                    child: Row(
                      children: [
                        Icon(g.isPrivate ? Icons.lock_rounded : Icons.public_rounded, color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Text('${g.members.length} miembros', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'Progreso'),
                Tab(text: 'Libros'),
                Tab(text: 'Discusión'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildRanking(provider, isDark),
            _buildBooks(provider, g),
            GroupChatScreen(groupId: widget.groupId),
          ],
        ),
      ),
    );
  }

  Widget _buildRanking(GroupsProvider provider, bool isDark) {
    final p = provider.progress;
    if (p == null || p.book == null) {
      return _empty('Sin libro actual', 'Añade un libro al grupo para comenzar a leer juntos.');
    }
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () => provider.loadGroup(widget.groupId),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          Card(
            color: isDark ? AppTheme.surfaceDarkSecondary : AppTheme.primaryLight.withValues(alpha: 0.35),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  BookCoverImage(imageUrl: p.book!.thumbnail, width: 62, height: 90, borderRadius: 8, title: p.book!.title),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('LIBRO ACTUAL DEL CLUB',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.primary, letterSpacing: 0.6)),
                        const SizedBox(height: 4),
                        Text(p.book!.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        Text(p.book!.authorDisplay, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        if (p.targetEndDate != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.flag_rounded, size: 13, color: AppTheme.accentSage),
                              const SizedBox(width: 4),
                              Text('Meta: ${DateFormatter.formatShort(p.targetEndDate)}',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Ranking del club', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...p.ranking.asMap().entries.map((e) {
            final idx = e.key;
            final r = e.value;
            final medal = idx == 0 ? '🥇' : idx == 1 ? '🥈' : idx == 2 ? '🥉' : '#${idx + 1}';
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    SizedBox(width: 34, child: Center(child: Text(medal, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.primaryLight,
                      backgroundImage: r.user.picture != null && r.user.picture!.isNotEmpty ? NetworkImage(r.user.avatarUrl) : null,
                      child: r.user.picture == null || r.user.picture!.isEmpty
                          ? Text(r.user.fullName.isNotEmpty ? r.user.fullName[0].toUpperCase() : '?',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary))
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(r.user.fullName, style: const TextStyle(fontWeight: FontWeight.bold))),
                              Text('${r.percentage.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: r.percentage >= 100 ? AppTheme.accentSage : AppTheme.primary)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ReadingProgressBar(
                            progress: r.percentage / 100,
                            currentPage: r.currentPage,
                            totalPages: r.totalPages > 0 ? r.totalPages : 300,
                            height: 5,
                            showLabel: false,
                          ),
                          const SizedBox(height: 4),
                          Text(r.status == 'READ' ? 'Terminado' : (r.status == 'READING' ? 'Leyendo ahora' : 'Sin empezar'),
                              style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBooks(GroupsProvider provider, ReadingGroupModel g) {
    final books = g.books;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.library_add_rounded),
              label: const Text('Añadir libro al grupo'),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => SelectBookForGroupScreen(groupId: widget.groupId)));
              },
            ),
          ),
        ),
        Expanded(
          child: books.isEmpty
              ? _empty('Sin libros', 'Añade el primer libro del club para empezar.')
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: books.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final gb = books[index];
                    Color chipColor;
                    String label;
                    switch (gb.status) {
                      case GroupBookStatus.current:
                        chipColor = AppTheme.primary;
                        label = 'Leyendo ahora';
                        break;
                      case GroupBookStatus.finished:
                        chipColor = AppTheme.accentSage;
                        label = 'Terminado';
                        break;
                      case GroupBookStatus.upcoming:
                        chipColor = Colors.blueGrey;
                        label = 'Próximo';
                        break;
                    }
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailScreen(book: gb.book))),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              BookCoverImage(imageUrl: gb.book.thumbnail, width: 52, height: 76, borderRadius: 6, title: gb.book.title),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: chipColor, borderRadius: BorderRadius.circular(6)),
                                      child: Text(label,
                                          style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(gb.book.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                    Text(gb.book.authorDisplay, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                                    if (gb.targetEndDate != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text('Meta: ${DateFormatter.formatShort(gb.targetEndDate)}',
                                            style: const TextStyle(fontSize: 11)),
                                      ),
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
        ),
      ],
    );
  }

  Widget _empty(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
