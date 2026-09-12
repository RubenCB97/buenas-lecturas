import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/book_model.dart';
import '../../models/user_book_model.dart';
import '../../models/user_model.dart';
import '../../providers/friends_provider.dart';
import '../../widgets/book_cover_image.dart';
import '../book_detail/book_detail_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final dynamic userId;
  final UserModel? initialUser;

  const UserProfileScreen({super.key, required this.userId, this.initialUser});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final ApiClient _client = ApiClient();
  UserModel? _user;
  List<UserBookModel> _library = [];
  Map<String, dynamic>? _compare;
  bool _loading = true;
  String _friendStatus = 'NONE';

  @override
  void initState() {
    super.initState();
    _user = widget.initialUser;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await _client.get('/social/users/${widget.userId}/profile');
    if (r.success && r.data is Map<String, dynamic>) {
      final data = r.data as Map<String, dynamic>;
      _user = UserModel.fromJson(data['user'] ?? {});
      final lib = data['library'];
      if (lib is List) {
        _library = lib.map((e) => UserBookModel.fromJson(e)).toList();
      }
      final fs = data['friendship'];
      if (fs is Map && fs['status'] != null) {
        _friendStatus = fs['status'].toString();
      }
    }
    // Comparación
    final c = await _client.get('/social/users/${widget.userId}/compare');
    if (c.success && c.data is Map<String, dynamic>) {
      _compare = c.data as Map<String, dynamic>;
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final friendsProvider = Provider.of<FriendsProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: Text(_user?.fullName ?? 'Perfil')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _user == null
              ? const Center(child: Text('Usuario no encontrado'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 38,
                            backgroundColor: AppTheme.primaryLight,
                            backgroundImage: _user!.picture != null && _user!.picture!.isNotEmpty ? NetworkImage(_user!.avatarUrl) : null,
                            child: _user!.picture == null || _user!.picture!.isEmpty
                                ? const Icon(Icons.person, color: AppTheme.primary, size: 40)
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_user!.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                Text(_user!.email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                if (_user!.bio != null && _user!.bio!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(_user!.bio!, style: const TextStyle(fontSize: 12.5)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Botón amistad
                      _buildFriendButton(friendsProvider),

                      const SizedBox(height: 20),

                      // Comparativa
                      if (_compare != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.surfaceDarkSecondary : AppTheme.surfaceLightSecondary,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: _statCol('${_compare!['sharedCount'] ?? 0}', 'Libros en común')),
                              Container(width: 1, height: 34, color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                              Expanded(child: _statCol('${_compare!['totalTheirs'] ?? 0}', 'En su biblioteca')),
                              Container(width: 1, height: 34, color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                              Expanded(child: _statCol('${_compare!['totalMine'] ?? 0}', 'En la tuya')),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Libros de su biblioteca
                      Text('Su biblioteca (${_library.length})', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 10),
                      if (_library.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Center(child: Text('Sin libros aún', style: TextStyle(color: Colors.grey))),
                        )
                      else
                        SizedBox(
                          height: 165,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _library.length,
                            itemBuilder: (context, index) {
                              final ub = _library[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailScreen(book: ub.book)));
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      BookCoverImage(
                                        imageUrl: ub.book.thumbnail,
                                        width: 85,
                                        height: 128,
                                        borderRadius: 8,
                                        title: ub.book.title,
                                      ),
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        width: 85,
                                        child: Text(
                                          ub.book.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                      // Libros en común
                      if (_compare != null && _compare!['shared'] is List && (_compare!['shared'] as List).isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text('En común (${(_compare!['shared'] as List).length})', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 10),
                        ...((_compare!['shared'] as List).take(5).map<Widget>((s) {
                          final b = BookModel.fromJson(s['book'] ?? {});
                          return Card(
                            child: ListTile(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailScreen(book: b))),
                              leading: BookCoverImage(imageUrl: b.thumbnail, width: 40, height: 55, borderRadius: 4, title: b.title),
                              title: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                              subtitle: Text('Tú: ${s['myRating'] ?? '—'} ★ · Ella/él: ${s['theirRating'] ?? '—'} ★', style: const TextStyle(fontSize: 11.5)),
                            ),
                          );
                        }).toList()),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _statCol(String v, String label) {
    return Column(
      children: [
        Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildFriendButton(FriendsProvider provider) {
    switch (_friendStatus) {
      case 'FRIENDS':
        return OutlinedButton.icon(
          icon: const Icon(Icons.check_rounded),
          label: const Text('Sois amigos'),
          onPressed: () async {
            await provider.removeFriend(widget.userId);
            _load();
          },
        );
      case 'PENDING_OUT':
        return const Chip(label: Text('Solicitud enviada'));
      case 'PENDING_IN':
        return ElevatedButton.icon(
          icon: const Icon(Icons.check_rounded),
          label: const Text('Aceptar solicitud'),
          onPressed: () async {
            await provider.sendRequest(widget.userId);
            _load();
          },
        );
      default:
        return ElevatedButton.icon(
          icon: const Icon(Icons.person_add_rounded),
          label: const Text('Seguir'),
          onPressed: () async {
            await provider.sendRequest(widget.userId);
            _load();
          },
        );
    }
  }
}
