import 'package:flutter/material.dart';

class AddCategoryDialog extends StatefulWidget {
  const AddCategoryDialog({super.key});

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final _ctrl = TextEditingController();
  String _icon = '📖';
  static const _icons = ['📖', '📚', '📕', '📜', '⭐', '🏆', '🌍', '🚀', '💌', '🎲', '🎓', '👩', '☕', '🌙', '🔥'];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva categoría'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Ej: "Un libro traducido"'),
          ),
          const SizedBox(height: 12),
          const Text('Icono', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: _icons.map((i) {
              return ChoiceChip(
                label: Text(i, style: const TextStyle(fontSize: 18)),
                selected: _icon == i,
                onSelected: (_) => setState(() => _icon = i),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
            if (_ctrl.text.trim().isEmpty) return;
            Navigator.pop(context, {'name': _ctrl.text.trim(), 'icon': _icon});
          },
          child: const Text('Añadir'),
        ),
      ],
    );
  }
}
