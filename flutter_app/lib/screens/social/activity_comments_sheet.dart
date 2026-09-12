import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/activity_model.dart';
import '../../providers/social_provider.dart';

class ActivityCommentsSheet extends StatefulWidget {
  final int activityId;

  const ActivityCommentsSheet({super.key, required this.activityId});

  @override
  State<ActivityCommentsSheet> createState() => _ActivityCommentsSheetState();
}

class _ActivityCommentsSheetState extends State<ActivityCommentsSheet> {
  final _controller = TextEditingController();
  List<ActivityCommentModel> _comments = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final social = Provider.of<SocialProvider>(context, listen: false);
    final list = await social.fetchComments(widget.activityId);
    setState(() {
      _comments = list;
      _loading = false;
    });
  }

  Future<void> _send() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _sending = true);
    final social = Provider.of<SocialProvider>(context, listen: false);
    final added = await social.addComment(widget.activityId, _controller.text.trim());
    if (added != null) {
      setState(() {
        _comments.add(added);
        _controller.clear();
      });
    }
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Comentarios', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                    : _comments.isEmpty
                        ? const Center(child: Text('Sin comentarios. Sé el primero.', style: TextStyle(color: Colors.grey)))
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _comments.length,
                            separatorBuilder: (_, __) => const Divider(height: 20),
                            itemBuilder: (context, i) {
                              final c = _comments[i];
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 15,
                                    backgroundColor: AppTheme.primaryLight,
                                    backgroundImage: c.user?.picture != null && c.user!.picture!.isNotEmpty ? NetworkImage(c.user!.avatarUrl) : null,
                                    child: c.user?.picture == null || c.user!.picture!.isEmpty
                                        ? Text(c.user?.fullName.isNotEmpty == true ? c.user!.fullName[0].toUpperCase() : '?',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary))
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(c.user?.fullName ?? 'Anónimo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                            const SizedBox(width: 6),
                                            Text(DateFormatter.timeAgo(c.createdAt), style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(c.content, style: const TextStyle(fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: 'Escribe un comentario…',
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: AppTheme.primary,
                        child: IconButton(
                          icon: _sending
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                          onPressed: _send,
                        ),
                      ),
                    ],
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
