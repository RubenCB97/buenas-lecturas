import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/reading_group_model.dart';
import '../../providers/groups_provider.dart';
import 'create_group_sheet.dart';
import 'group_detail_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<GroupsProvider>(context, listen: false);
      provider.fetchMyGroups();
      provider.fetchDiscover();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const CreateGroupSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GroupsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clubes de lectura'),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: _openCreateSheet, tooltip: 'Crear grupo'),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(text: 'Mis clubes (${provider.myGroups.length})'),
            const Tab(text: 'Descubrir'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyGroups(provider),
          _buildDiscover(provider),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        icon: const Icon(Icons.group_add_rounded),
        label: const Text('Nuevo club'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  Widget _buildMyGroups(GroupsProvider provider) {
    if (provider.isLoading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (provider.myGroups.isEmpty) {
      return _empty('Sin clubes de lectura', 'Crea tu primer club o únete a uno existente en la pestaña "Descubrir".');
    }
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: provider.fetchMyGroups,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: provider.myGroups.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _groupCard(provider.myGroups[index], mine: true),
      ),
    );
  }

  Widget _buildDiscover(GroupsProvider provider) {
    if (provider.discover.isEmpty) return _empty('Sin grupos públicos', 'Aún no hay grupos abiertos. Crea uno tú.');
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: provider.discover.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _groupCard(provider.discover[index], mine: false),
    );
  }

  Widget _groupCard(ReadingGroupModel g, {required bool mine}) {
    final color = Color(int.parse(g.coverColor.replaceFirst('#', 'FF'), radix: 16));
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: g.id)));
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 76,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(g.isPrivate ? Icons.lock_rounded : Icons.groups_rounded, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    if (g.description != null && g.description!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(g.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (mine) ...[
                          const Icon(Icons.check_circle_rounded, size: 13, color: AppTheme.accentSage),
                          const SizedBox(width: 4),
                          Text('Miembro (${g.myRole.name})', style: const TextStyle(fontSize: 11, color: AppTheme.accentSage, fontWeight: FontWeight.w600)),
                        ] else ...[
                          const Icon(Icons.public_rounded, size: 13, color: Colors.grey),
                          const SizedBox(width: 4),
                          const Text('Grupo público', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.groups_outlined, size: 60, color: Colors.grey),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
