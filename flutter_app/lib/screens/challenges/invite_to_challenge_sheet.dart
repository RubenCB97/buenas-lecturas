import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/challenges_provider.dart';
import '../../providers/friends_provider.dart';

class InviteToChallengeSheet extends StatefulWidget {
  final int challengeId;

  const InviteToChallengeSheet({super.key, required this.challengeId});

  @override
  State<InviteToChallengeSheet> createState() => _InviteToChallengeSheetState();
}

class _InviteToChallengeSheetState extends State<InviteToChallengeSheet> {
  final Set<int> _selected = {};
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FriendsProvider>(context, listen: false).fetchAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final friends = Provider.of<FriendsProvider>(context).friends;
    final detail = Provider.of<ChallengesProvider>(context).selected;
    final existingIds = detail?.participants.map((p) => p.user.id is int ? p.user.id as int : int.tryParse('${p.user.id}') ?? -1).toSet() ?? <int>{};

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Text('Invitar al reto', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Expanded(
              child: friends.isEmpty
                  ? const Center(child: Text('Sin amigos aún. Añade amigos desde la sección Comunidad.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: friends.length,
                      itemBuilder: (context, i) {
                        final f = friends[i];
                        final id = f.id is int ? f.id : int.tryParse('${f.id}') ?? -1;
                        final already = existingIds.contains(id);
                        final selected = _selected.contains(id);
                        return CheckboxListTile(
                          value: already || selected,
                          onChanged: already
                              ? null
                              : (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selected.add(id);
                                    } else {
                                      _selected.remove(id);
                                    }
                                  });
                                },
                          title: Text(f.fullName),
                          subtitle: Text(already ? 'Ya participa' : f.email, style: const TextStyle(fontSize: 11.5)),
                          secondary: CircleAvatar(
                            backgroundColor: AppTheme.primaryLight,
                            backgroundImage: f.picture != null && f.picture!.isNotEmpty ? NetworkImage(f.avatarUrl) : null,
                            child: f.picture == null || f.picture!.isEmpty
                                ? Text(f.fullName.isNotEmpty ? f.fullName[0].toUpperCase() : '?', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold))
                                : null,
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _selected.isEmpty || _sending
                        ? null
                        : () async {
                            setState(() => _sending = true);
                            await Provider.of<ChallengesProvider>(context, listen: false)
                                .invite(widget.challengeId, _selected.toList());
                            if (mounted) Navigator.pop(context);
                          },
                    icon: _sending
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send_rounded),
                    label: Text(_sending ? 'Invitando…' : 'Invitar (${_selected.length})'),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
