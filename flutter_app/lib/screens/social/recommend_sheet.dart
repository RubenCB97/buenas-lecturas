import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/book_model.dart';
import '../../providers/friends_provider.dart';
import '../../providers/social_provider.dart';

class RecommendSheet extends StatefulWidget {
  final BookModel book;

  const RecommendSheet({super.key, required this.book});

  @override
  State<RecommendSheet> createState() => _RecommendSheetState();
}

class _RecommendSheetState extends State<RecommendSheet> {
  final _note = TextEditingController();
  final Set<dynamic> _selected = {};
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FriendsProvider>(context, listen: false).fetchAll();
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_selected.isEmpty) return;
    setState(() => _sending = true);
    final social = Provider.of<SocialProvider>(context, listen: false);
    for (final uid in _selected) {
      await social.sendRecommendation(uid is int ? uid : int.tryParse('$uid') ?? 0, widget.book, note: _note.text.trim().isEmpty ? null : _note.text.trim());
    }
    if (!mounted) return;
    setState(() => _sending = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppTheme.accentSage, content: Text('Recomendación enviada a ${_selected.length} amigo(s)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final friends = Provider.of<FriendsProvider>(context).friends;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 12),
          child: Column(
            children: [
              Row(
                children: [
                  Text('Recomendar libro', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ],
              ),
              Text(widget.book.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Añade una nota (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              Align(alignment: Alignment.centerLeft, child: Text('Enviar a: (${_selected.length})', style: const TextStyle(fontWeight: FontWeight.w600))),
              const SizedBox(height: 8),
              Expanded(
                child: friends.isEmpty
                    ? const Center(child: Text('Aún no tienes amigos para recomendar.', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: friends.length,
                        itemBuilder: (context, i) {
                          final f = friends[i];
                          final selected = _selected.contains(f.id);
                          return CheckboxListTile(
                            value: selected,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selected.add(f.id);
                                } else {
                                  _selected.remove(f.id);
                                }
                              });
                            },
                            title: Text(f.fullName),
                            subtitle: Text(f.email, style: const TextStyle(fontSize: 11.5)),
                            secondary: CircleAvatar(
                              backgroundColor: AppTheme.primaryLight,
                              backgroundImage: f.picture != null && f.picture!.isNotEmpty ? NetworkImage(f.avatarUrl) : null,
                              child: f.picture == null || f.picture!.isEmpty
                                  ? Text(f.fullName.isNotEmpty ? f.fullName[0].toUpperCase() : '?',
                                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold))
                                  : null,
                            ),
                          );
                        },
                      ),
              ),
              SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _selected.isEmpty || _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send_rounded),
                    label: Text(_sending ? 'Enviando…' : 'Enviar recomendación'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
