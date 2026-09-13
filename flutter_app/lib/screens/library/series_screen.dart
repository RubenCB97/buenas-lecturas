import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/series.dart';
import '../../models/book_model.dart';
import '../../providers/library_provider.dart';
import '../../widgets/book_card.dart';
import '../../widgets/book_cover_image.dart';
import '../book_detail/book_detail_screen.dart';

/// Sagas detectadas en la biblioteca, con el progreso y el siguiente libro.
class SeriesScreen extends StatelessWidget {
  /// Saga que se muestra primero (al llegar desde la ficha de un libro).
  final String? highlight;

  const SeriesScreen({super.key, this.highlight});

  @override
  Widget build(BuildContext context) {
    final library = Provider.of<LibraryProvider>(context).libraryBooks;
    final series = Series.fromLibrary(library);

    if (highlight != null) {
      final key = Series.normalize(highlight!);
      final index = series.indexWhere((s) => Series.normalize(s.name) == key);
      if (index > 0) series.insert(0, series.removeAt(index));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mis sagas')),
      body: series.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.collections_bookmark_outlined, size: 56, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('Todavía no hay sagas en tu biblioteca',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    SizedBox(height: 6),
                    Text(
                      'Detectamos las sagas por el título, por ejemplo «Dune (Dune, #1)». '
                      'Los libros importados de Goodreads suelen traerlo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: series.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _SeriesCard(progress: series[i]),
                ),
              ),
            ),
    );
  }
}

class _SeriesCard extends StatelessWidget {
  final SeriesProgress progress;

  const _SeriesCard({required this.progress});

  void _open(BuildContext context, BookModel book) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)));
  }

  void _searchNext(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _NextBookSearchSheet(progress: progress),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final total = p.books.length;
    final next = p.nextBook;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      if (p.author != null)
                        Text(p.author!, style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
                    ],
                  ),
                ),
                if (p.isComplete)
                  const Chip(
                    avatar: Icon(Icons.emoji_events_rounded, size: 16, color: AppTheme.starGold),
                    label: Text('Completa', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : p.readCount / total,
                      minHeight: 8,
                      color: AppTheme.primary,
                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${p.readCount} de $total leídos', style: const TextStyle(fontSize: 12.5)),
              ],
            ),
            const SizedBox(height: 12),

            // Portadas en orden
            SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: p.books.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final b = p.books[i];
                  final label = SeriesInfo(p.name, b.number).numberLabel;
                  return GestureDetector(
                    onTap: () => _open(context, b.userBook.book),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Opacity(
                              opacity: b.isRead ? 1 : 0.55,
                              child: BookCoverImage(
                                imageUrl: b.userBook.book.thumbnail,
                                width: 54,
                                height: 80,
                                borderRadius: 6,
                                title: b.userBook.book.title,
                                hasShadow: false,
                              ),
                            ),
                            if (b.isRead)
                              const Positioned(
                                right: 2,
                                top: 2,
                                child: Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.accentSage),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('#$label', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                },
              ),
            ),

            if (!p.isComplete) ...[
              const Divider(height: 22),
              Row(
                children: [
                  const Icon(Icons.skip_next_rounded, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: next != null
                        ? Text.rich(
                            TextSpan(children: [
                              TextSpan(text: 'Siguiente: #${p.nextNumber} '),
                              TextSpan(
                                text: next.userBook.book.title,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          )
                        : Text(
                            'Siguiente: #${p.nextNumber} · no lo tienes en tu biblioteca',
                            style: const TextStyle(fontSize: 13),
                          ),
                  ),
                  if (next != null)
                    TextButton(onPressed: () => _open(context, next.userBook.book), child: const Text('Abrir'))
                  else
                    TextButton(onPressed: () => _searchNext(context), child: const Text('Buscar')),
                ],
              ),
              if (p.missingNumbers.length > (next == null ? 1 : 0))
                Padding(
                  padding: const EdgeInsets.only(left: 32, top: 2),
                  child: Text(
                    'Te faltan: ${p.missingNumbers.map((n) => '#$n').join(', ')}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Busca en el catálogo libros de la saga para encontrar el siguiente.
class _NextBookSearchSheet extends StatefulWidget {
  final SeriesProgress progress;

  const _NextBookSearchSheet({required this.progress});

  @override
  State<_NextBookSearchSheet> createState() => _NextBookSearchSheetState();
}

class _NextBookSearchSheetState extends State<_NextBookSearchSheet> {
  List<BookModel>? _results;

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    final p = widget.progress;
    var q = 'intitle:"${p.name}"';
    if (p.author != null) q += ' inauthor:"${p.author}"';
    final r = await ApiClient().get('/search', queryParams: {'q': q});
    if (!mounted) return;

    final owned = p.books.map((b) => b.userBook.book.title.toLowerCase()).toSet();
    final books = (r.success && r.data is List)
        ? (r.data as List)
            .map((e) => BookModel.fromJson(e))
            .where((b) => !owned.contains(b.title.toLowerCase()))
            .toList()
        : <BookModel>[];

    // Primero los que indican el número que buscamos
    books.sort((a, b) {
      int score(BookModel x) => Series.parse(x.title)?.number == widget.progress.nextNumber.toDouble() ? 0 : 1;
      return score(a).compareTo(score(b));
    });
    setState(() => _results = books);
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Text(
              'Buscar el #${widget.progress.nextNumber} de «${widget.progress.name}»',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 17),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Los catálogos no siempre indican el número de la saga: revisa el título antes de añadirlo.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            child: results == null
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : results.isEmpty
                    ? const Center(child: Text('No hemos encontrado más libros de esta saga'))
                    : ListView.builder(
                        controller: controller,
                        padding: const EdgeInsets.all(16),
                        itemCount: results.length,
                        itemBuilder: (context, i) {
                          final book = results[i];
                          return BookCard(
                            book: book,
                            style: BookCardStyle.largeFeed,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
