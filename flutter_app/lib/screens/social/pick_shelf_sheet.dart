import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/book_model.dart';
import '../../providers/social_provider.dart';

class PickShelfSheet extends StatefulWidget {
  final BookModel book;

  const PickShelfSheet({super.key, required this.book});

  @override
  State<PickShelfSheet> createState() => _PickShelfSheetState();
}

class _PickShelfSheetState extends State<PickShelfSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SocialProvider>(context, listen: false).fetchShelves();
    });
  }

  @override
  Widget build(BuildContext context) {
    final social = Provider.of<SocialProvider>(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Añadir a una estantería', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            if (social.shelves.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Aún no tienes estanterías personalizadas.', style: TextStyle(color: Colors.grey)),
              )
            else
              ...social.shelves.map((s) {
                final already = s.books.any((b) => b.id == widget.book.id);
                return ListTile(
                  leading: Text(s.icon, style: const TextStyle(fontSize: 20)),
                  title: Text(s.name),
                  subtitle: Text('${s.books.length} libros', style: const TextStyle(fontSize: 11.5)),
                  trailing: already ? const Icon(Icons.check_rounded, color: AppTheme.accentSage) : const Icon(Icons.add_rounded),
                  onTap: already
                      ? null
                      : () async {
                          await social.addBookToShelf(s.id, widget.book);
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(backgroundColor: AppTheme.accentSage, content: Text('Añadido a "${s.name}"')),
                            );
                          }
                        },
                );
              }),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add_rounded, color: AppTheme.primary),
              title: const Text('Crear nueva estantería…'),
              onTap: () async {
                final ctrl = TextEditingController();
                final result = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Nueva estantería'),
                    content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Nombre')),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                      ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crear')),
                    ],
                  ),
                );
                if (result == true && ctrl.text.trim().isNotEmpty) {
                  final shelf = await social.createShelf(ctrl.text.trim());
                  if (shelf != null) await social.addBookToShelf(shelf.id, widget.book);
                  if (mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
