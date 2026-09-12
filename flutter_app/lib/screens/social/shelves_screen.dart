import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/social_provider.dart';
import '../../widgets/book_cover_image.dart';
import '../book_detail/book_detail_screen.dart';

class ShelvesScreen extends StatefulWidget {
  const ShelvesScreen({super.key});

  @override
  State<ShelvesScreen> createState() => _ShelvesScreenState();
}

class _ShelvesScreenState extends State<ShelvesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SocialProvider>(context, listen: false).fetchShelves();
    });
  }

  Future<void> _createShelfDialog() async {
    final ctrl = TextEditingController();
    String icon = '📚';
    const options = ['📚', '⭐', '🎃', '❤', '🔥', '🌸', '☕', '🌙', '🎓', '🔍'];
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Nueva estantería'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Nombre (ej: "Verano 2026")')),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: options.map((o) {
                    return ChoiceChip(
                      label: Text(o, style: const TextStyle(fontSize: 18)),
                      selected: icon == o,
                      onSelected: (_) => setState(() => icon = o),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crear')),
            ],
          );
        });
      },
    );
    if (result == true && ctrl.text.trim().isNotEmpty && mounted) {
      await Provider.of<SocialProvider>(context, listen: false).createShelf(ctrl.text.trim(), icon: icon);
    }
  }

  @override
  Widget build(BuildContext context) {
    final social = Provider.of<SocialProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis estanterías'),
        actions: [IconButton(icon: const Icon(Icons.add_rounded), onPressed: _createShelfDialog)],
      ),
      body: social.shelves.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.library_books_outlined, size: 60, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('Sin estanterías', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('Crea colecciones personalizadas para organizar tus libros como tú quieras.',
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Crear estantería'),
                      onPressed: _createShelfDialog,
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              itemCount: social.shelves.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, i) {
                final s = social.shelves[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(s.icon, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                            Text('${s.books.length} libros', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                              onPressed: () => social.deleteShelf(s.id),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (s.books.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.surfaceDarkSecondary : AppTheme.surfaceLightSecondary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Sin libros aún. Añade libros desde la ficha de cada libro.',
                                style: TextStyle(color: Colors.grey, fontSize: 12.5)),
                          )
                        else
                          SizedBox(
                            height: 130,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: s.books.length,
                              itemBuilder: (context, j) {
                                final b = s.books[j];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: GestureDetector(
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailScreen(book: b))),
                                    onLongPress: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('¿Quitar libro?'),
                                          content: Text('¿Quitar "${b.title}" de "${s.name}"?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Quitar')),
                                          ],
                                        ),
                                      );
                                      if (confirm == true && b.id != null) {
                                        social.removeBookFromShelf(s.id, b.id is int ? b.id : int.tryParse('${b.id}') ?? 0);
                                      }
                                    },
                                    child: BookCoverImage(imageUrl: b.thumbnail, width: 78, height: 118, borderRadius: 6, title: b.title),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
