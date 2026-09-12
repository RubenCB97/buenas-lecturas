import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../providers/friends_provider.dart';
import '../../widgets/custom_search_bar.dart';
import 'user_profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _debounce;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FriendsProvider>(context, listen: false).fetchAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _searchQuery = q;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      Provider.of<FriendsProvider>(context, listen: false).search(q);
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FriendsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Amigos'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(text: 'Amigos (${provider.friends.length})'),
            Tab(text: 'Solicitudes (${provider.incoming.length})'),
            const Tab(text: 'Descubrir'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsList(provider),
          _buildRequests(provider),
          _buildDiscover(provider),
        ],
      ),
    );
  }

  Widget _buildFriendsList(FriendsProvider provider) {
    if (provider.isLoading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (provider.friends.isEmpty) {
      return _empty('Aún no tienes amigos', 'Busca lectores en la pestaña "Descubrir" y envíales una solicitud.');
    }
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: provider.fetchAll,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: provider.friends.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final user = provider.friends[index];
          return _friendTile(user, trailing: PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'remove') provider.removeFriend(user.id);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'remove', child: Text('Quitar amistad')),
            ],
          ));
        },
      ),
    );
  }

  Widget _buildRequests(FriendsProvider provider) {
    final incoming = provider.incoming;
    final outgoing = provider.outgoing;
    if (incoming.isEmpty && outgoing.isEmpty) {
      return _empty('Sin solicitudes', 'Cuando alguien te envíe una solicitud aparecerá aquí.');
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        if (incoming.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Recibidas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          ...incoming.map((fs) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      _avatar(fs.requester),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fs.requester.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(fs.requester.email, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check_circle_rounded, color: AppTheme.accentSage),
                        onPressed: () => provider.respond(fs.id, true),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent),
                        onPressed: () => provider.respond(fs.id, false),
                      ),
                    ],
                  ),
                ),
              )),
        ],
        if (outgoing.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Enviadas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          ...outgoing.map((fs) => Card(
                child: ListTile(
                  leading: _avatar(fs.recipient),
                  title: Text(fs.recipient.fullName),
                  subtitle: const Text('Pendiente de respuesta', style: TextStyle(fontSize: 11.5)),
                  trailing: TextButton(
                    onPressed: () => provider.respond(fs.id, false),
                    child: const Text('Cancelar'),
                  ),
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildDiscover(FriendsProvider provider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: CustomSearchBar(
            placeholder: 'Buscar por nombre o email…',
            onChanged: _onSearchChanged,
            onClear: () {
              _searchQuery = '';
              provider.search('');
            },
          ),
        ),
        Expanded(
          child: _searchQuery.length < 2
              ? _empty('Descubre lectores', 'Escribe al menos 2 letras para buscar personas.')
              : provider.isSearching
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : provider.searchResults.isEmpty
                      ? _empty('Sin resultados', 'Prueba con otro nombre o email.')
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: provider.searchResults.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final user = provider.searchResults[index];
                            return _friendTile(user, trailing: FutureBuilder<dynamic>(
                              future: provider.statusWith(user.id),
                              builder: (_, snap) {
                                final s = snap.data;
                                if (s == null) return const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2));
                                switch (s) {
                                  case null:
                                    return const SizedBox.shrink();
                                  default:
                                }
                                if (s.toString().contains('friends')) {
                                  return const Chip(label: Text('Amigos', style: TextStyle(fontSize: 11)));
                                }
                                if (s.toString().contains('pendingOut')) {
                                  return const Chip(label: Text('Enviada', style: TextStyle(fontSize: 11)));
                                }
                                if (s.toString().contains('pendingIn')) {
                                  return ElevatedButton(
                                    onPressed: () => provider.sendRequest(user.id),
                                    child: const Text('Aceptar'),
                                  );
                                }
                                return ElevatedButton.icon(
                                  onPressed: () => provider.sendRequest(user.id),
                                  icon: const Icon(Icons.person_add_rounded, size: 16),
                                  label: const Text('Seguir'),
                                );
                              },
                            ));
                          },
                        ),
        ),
      ],
    );
  }

  Widget _friendTile(UserModel user, {Widget? trailing}) {
    return Card(
      child: ListTile(
        leading: _avatar(user),
        title: Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(user.email, style: const TextStyle(fontSize: 11.5)),
        trailing: trailing,
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: user.id, initialUser: user)));
        },
      ),
    );
  }

  Widget _avatar(UserModel user) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppTheme.primaryLight,
      backgroundImage: user.picture != null && user.picture!.isNotEmpty ? NetworkImage(user.avatarUrl) : null,
      child: user.picture == null || user.picture!.isEmpty
          ? Text(
              user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
            )
          : null,
    );
  }

  Widget _empty(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline_rounded, size: 60, color: Colors.grey),
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
