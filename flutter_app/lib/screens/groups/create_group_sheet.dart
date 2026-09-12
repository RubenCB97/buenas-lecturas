import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/groups_provider.dart';

class CreateGroupSheet extends StatefulWidget {
  const CreateGroupSheet({super.key});

  @override
  State<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<CreateGroupSheet> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  String _color = '#C8602E';
  bool _isPrivate = false;
  bool _submitting = false;

  static const _colors = ['#C8602E', '#2D5A43', '#3B82F6', '#DC2626', '#7C3AED', '#F59E0B', '#0F766E'];

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    final provider = Provider.of<GroupsProvider>(context, listen: false);
    await provider.createGroup(_name.text.trim(), _description.text.trim(), coverColor: _color, isPrivate: _isPrivate);
    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Crear grupo de lectura', style: Theme.of(context).textTheme.titleLarge),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nombre del club', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Descripción (opcional)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          const Text('Color', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _colors.map((c) {
              final selected = _color == c;
              return GestureDetector(
                onTap: () => setState(() => _color = c),
                child: Container(
                  width: 34,
                  height: 34,
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
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Grupo privado (solo por invitación)'),
            value: _isPrivate,
            activeColor: AppTheme.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _isPrivate = v),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded),
              label: Text(_submitting ? 'Creando…' : 'Crear grupo'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
