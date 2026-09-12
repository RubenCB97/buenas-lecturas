import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/book_model.dart';
import '../../models/challenge_model.dart';
import '../../providers/challenges_provider.dart';

/// Hoja para añadir un libro (desde la ficha del libro) a una celda vacía
/// concreta de un reto lector.
class AddToChallengeSheet extends StatefulWidget {
  final BookModel book;

  const AddToChallengeSheet({super.key, required this.book});

  @override
  State<AddToChallengeSheet> createState() => _AddToChallengeSheetState();
}

class _AddToChallengeSheetState extends State<AddToChallengeSheet> {
  ChallengeSummaryModel? _selectedChallenge;
  List<_Slot> _slots = [];
  bool _loadingSlots = false;
  bool _loadingChallenges = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Provider.of<ChallengesProvider>(context, listen: false).fetchMine();
      setState(() => _loadingChallenges = false);
    });
  }

  Future<void> _loadSlots(int challengeId) async {
    setState(() {
      _loadingSlots = true;
      _slots = [];
    });
    final r = await ApiClient().get('/challenges/$challengeId/my-slots');
    if (r.success && r.data is List) {
      _slots = (r.data as List).map((e) => _Slot.fromJson(e)).toList();
    }
    setState(() => _loadingSlots = false);
  }

  Future<void> _assign(_Slot slot) async {
    if (!slot.empty) return;
    final provider = Provider.of<ChallengesProvider>(context, listen: false);
    await provider.setBookForCell(_selectedChallenge!.id, slot.id, widget.book);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.accentSage,
        content: Text('Añadido a "${_selectedChallenge!.name}" → ${slot.name} ✅'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final challenges = Provider.of<ChallengesProvider>(context).myChallenges;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedChallenge == null ? 'Añadir a un reto lector' : _selectedChallenge!.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_selectedChallenge != null)
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        tooltip: 'Cambiar reto',
                        onPressed: () => setState(() {
                          _selectedChallenge = null;
                          _slots = [];
                        }),
                      ),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(widget.book.title, style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12.5, color: Colors.grey)),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _selectedChallenge == null
                    ? _buildChallengeList(challenges, scrollController)
                    : _buildSlotList(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChallengeList(List<ChallengeSummaryModel> list, ScrollController scrollController) {
    if (_loadingChallenges) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (list.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Text('Aún no participas en ningún reto. Crea uno desde Comunidad → Reto lector.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final c = list[i];
        final color = Color(int.parse(c.coverColor.replaceFirst('#', 'FF'), radix: 16));
        return Card(
          child: ListTile(
            leading: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.emoji_events_rounded, color: Colors.white),
            ),
            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${c.categoriesCount} categorías · ${c.myCompletedCount} completadas',
                style: const TextStyle(fontSize: 11.5)),
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            onTap: () {
              setState(() => _selectedChallenge = c);
              _loadSlots(c.id);
            },
          ),
        );
      },
    );
  }

  Widget _buildSlotList(ScrollController scrollController) {
    if (_loadingSlots) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_slots.isEmpty) {
      return const Center(child: Text('Este reto no tiene categorías todavía.', style: TextStyle(color: Colors.grey)));
    }
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      itemCount: _slots.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final s = _slots[i];
        return Card(
          color: s.empty ? null : Colors.grey.withValues(alpha: 0.08),
          child: ListTile(
            enabled: s.empty,
            leading: Text(s.icon, style: TextStyle(fontSize: 22, color: s.empty ? null : Colors.grey)),
            title: Text(s.name, style: TextStyle(fontWeight: FontWeight.bold, color: s.empty ? null : Colors.grey)),
            subtitle: s.empty
                ? const Text('Categoría vacía · toca para asignar este libro', style: TextStyle(fontSize: 11.5, color: AppTheme.primary))
                : Text('Ocupada por "${s.currentBookTitle ?? "otro libro"}"',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
            trailing: Icon(
              s.empty ? Icons.add_circle_outline_rounded : Icons.check_rounded,
              color: s.empty ? AppTheme.primary : Colors.grey,
            ),
            onTap: () => _assign(s),
          ),
        );
      },
    );
  }
}

class _Slot {
  final int id;
  final String name;
  final String icon;
  final bool empty;
  final String? currentBookTitle;

  _Slot({required this.id, required this.name, required this.icon, required this.empty, this.currentBookTitle});

  factory _Slot.fromJson(Map<String, dynamic> j) => _Slot(
        id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
        name: j['name']?.toString() ?? '',
        icon: j['icon']?.toString() ?? '📖',
        empty: j['empty'] == true,
        currentBookTitle: j['currentBookTitle']?.toString(),
      );
}
