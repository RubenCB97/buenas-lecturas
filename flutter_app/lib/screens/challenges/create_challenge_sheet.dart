import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/challenges_provider.dart';
import '../../providers/friends_provider.dart';

class CreateChallengeSheet extends StatefulWidget {
  const CreateChallengeSheet({super.key});

  @override
  State<CreateChallengeSheet> createState() => _CreateChallengeSheetState();
}

class _CreateChallengeSheetState extends State<CreateChallengeSheet> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _categoryName = TextEditingController();
  DateTime? _endDate;
  String _color = '#C8602E';
  final List<Map<String, dynamic>> _categories = [];
  final Set<int> _selectedFriends = {};
  bool _submitting = false;

  static const _colors = ['#C8602E', '#2D5A43', '#3B82F6', '#DC2626', '#7C3AED', '#F59E0B', '#0F766E'];
  static const _suggestedCategories = [
    {'name': 'Un clásico', 'icon': '📜'},
    {'name': 'Un libro corto (<200 pág.)', 'icon': '📕'},
    {'name': 'Ciencia ficción', 'icon': '🚀'},
    {'name': 'Un premio Nobel', 'icon': '🏅'},
    {'name': 'Autora mujer', 'icon': '👩'},
    {'name': 'Publicado este año', 'icon': '🗓️'},
    {'name': 'Género que nunca leas', 'icon': '🎲'},
    {'name': 'No ficción', 'icon': '📚'},
    {'name': 'Un libro traducido', 'icon': '🌍'},
    {'name': 'Un libro que te recomienden', 'icon': '💌'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FriendsProvider>(context, listen: false).fetchAll();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _categoryName.dispose();
    super.dispose();
  }

  void _addCategoryFromField() {
    final txt = _categoryName.text.trim();
    if (txt.isEmpty) return;
    setState(() {
      _categories.add({'name': txt, 'icon': '📖'});
      _categoryName.clear();
    });
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) return;
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Añade al menos una categoría antes de crear el reto')),
      );
      return;
    }
    setState(() => _submitting = true);
    final provider = Provider.of<ChallengesProvider>(context, listen: false);
    final created = await provider.create(
      name: _name.text.trim(),
      description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      coverColor: _color,
      endDate: _endDate,
      initialParticipantIds: _selectedFriends.toList(),
      initialCategories: _categories,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (created != null) Navigator.pop(context, created);
  }

  @override
  Widget build(BuildContext context) {
    final friends = Provider.of<FriendsProvider>(context).friends;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 12),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  Text('Nuevo reto lector', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nombre del reto', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _description,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Descripción (opcional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.event_rounded, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(_endDate == null ? 'Sin fecha límite' : 'Termina: ${_endDate!.toIso8601String().substring(0, 10)}',
                      style: const TextStyle(fontSize: 12.5)),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_month_rounded, size: 16),
                    label: const Text('Fecha límite'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 90)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                      );
                      if (picked != null) setState(() => _endDate = picked);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Color', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: _colors.map((c) {
                  final selected = _color == c;
                  return GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: Color(int.parse(c.replaceFirst('#', 'FF'), radix: 16)),
                        shape: BoxShape.circle,
                        border: Border.all(color: selected ? Colors.black : Colors.transparent, width: 3),
                      ),
                      child: selected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),
              const Text('Categorías (columnas de la tabla)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _suggestedCategories.map((c) {
                  final selected = _categories.any((e) => e['name'] == c['name']);
                  return FilterChip(
                    avatar: Text(c['icon'] as String),
                    label: Text(c['name'] as String, style: const TextStyle(fontSize: 12)),
                    selected: selected,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _categories.add({'name': c['name'], 'icon': c['icon']});
                        } else {
                          _categories.removeWhere((e) => e['name'] == c['name']);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _categoryName,
                      onSubmitted: (_) => _addCategoryFromField(),
                      decoration: const InputDecoration(
                        labelText: 'Categoría personalizada',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _addCategoryFromField, child: const Text('Añadir')),
                ],
              ),
              if (_categories.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _categories.map((c) {
                    return InputChip(
                      avatar: Text((c['icon'] ?? '📖').toString()),
                      label: Text(c['name'].toString(), style: const TextStyle(fontSize: 12)),
                      onDeleted: () {
                        setState(() => _categories.remove(c));
                      },
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 20),
              const Text('Invita amigos al reto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 6),
              if (friends.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Aún no tienes amigos añadidos. Puedes invitar más tarde.',
                      style: TextStyle(color: Colors.grey, fontSize: 12.5)),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: friends.map((f) {
                    final id = f.id is int ? f.id : int.tryParse('${f.id}') ?? -1;
                    final selected = _selectedFriends.contains(id);
                    return FilterChip(
                      avatar: CircleAvatar(
                        backgroundColor: AppTheme.primaryLight,
                        backgroundImage: f.picture != null && f.picture!.isNotEmpty ? NetworkImage(f.avatarUrl) : null,
                        child: f.picture == null || f.picture!.isEmpty
                            ? Text(f.fullName.isNotEmpty ? f.fullName[0].toUpperCase() : '?', style: const TextStyle(fontSize: 12))
                            : null,
                      ),
                      label: Text(f.fullName, style: const TextStyle(fontSize: 12)),
                      selected: selected,
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _selectedFriends.add(id);
                          } else {
                            _selectedFriends.remove(id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.rocket_launch_rounded),
                  label: Text(_submitting ? 'Creando…' : 'Crear reto'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
