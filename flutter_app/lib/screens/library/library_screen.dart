import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_book_model.dart';
import '../../providers/library_provider.dart';
import '../../widgets/book_card.dart';
import '../../widgets/custom_search_bar.dart';
import '../book_detail/book_detail_screen.dart';
import '../import/goodreads_import_screen.dart';
import '../scanner/isbn_scanner_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    final libraryProvider =
        Provider.of<LibraryProvider>(context, listen: false);
    switch (_tabController.index) {
      case 0:
        libraryProvider.setFilter(LibraryFilter.all);
        break;
      case 1:
        libraryProvider.setFilter(LibraryFilter.reading);
        break;
      case 2:
        libraryProvider.setFilter(LibraryFilter.wantToRead);
        break;
      case 3:
        libraryProvider.setFilter(LibraryFilter.read);
        break;
      case 4:
        libraryProvider.setFilter(LibraryFilter.favorites);
        break;
      case 5:
        libraryProvider.setFilter(LibraryFilter.abandoned);
        break;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSortDialog(BuildContext context) {
    final libraryProvider =
        Provider.of<LibraryProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        Widget item(String label, LibrarySort value) {
          return ListTile(
            title: Text(label),
            trailing: libraryProvider.currentSort == value
                ? const Icon(Icons.check, color: AppTheme.primary)
                : null,
            onTap: () {
              libraryProvider.setSort(value);
              Navigator.pop(ctx);
            },
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ordenar biblioteca por',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                item('Añadidos recientemente', LibrarySort.recent),
                item('Título (A-Z)', LibrarySort.title),
                item('Tu puntuación', LibrarySort.rating),
                item('Fecha de inicio', LibrarySort.dateStarted),
                item('Fecha de finalización', LibrarySort.dateFinished),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final libraryProvider = Provider.of<LibraryProvider>(context);
    final books = libraryProvider.filteredBooks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Biblioteca'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Escanear libro',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const IsbnScannerScreen()),
            ),
          ),
          IconButton(
            icon: Icon(
              libraryProvider.isGridView
                  ? Icons.view_list_rounded
                  : Icons.grid_view_rounded,
            ),
            tooltip: libraryProvider.isGridView
                ? 'Vista en lista'
                : 'Vista en cuadrícula',
            onPressed: () {
              libraryProvider.toggleViewMode();
            },
          ),
          IconButton(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Ordenar',
            onPressed: () => _showSortDialog(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor:
              isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(text: 'Todos (${libraryProvider.totalBooks})'),
            Tab(text: 'Leyendo (${libraryProvider.countReading})'),
            Tab(text: 'Por leer (${libraryProvider.countWantToRead})'),
            Tab(text: 'Leídos (${libraryProvider.countRead})'),
            Tab(text: '★ Favoritos (${libraryProvider.countFavorites})'),
            Tab(text: 'No terminados (${libraryProvider.countAbandoned})'),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () => libraryProvider.fetchLibrary(),
        child: Column(
          children: [
            // Barra de búsqueda dentro de la biblioteca
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: CustomSearchBar(
                placeholder: 'Filtrar en mis estanterías...',
                onChanged: (q) {
                  libraryProvider.setSearchQuery(q);
                },
                onClear: () {
                  libraryProvider.setSearchQuery('');
                },
              ),
            ),

            // Contenido de la lista / cuadrícula
            Expanded(
              child: libraryProvider.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary))
                  : books.isEmpty
                      ? _buildEmptyState(context)
                      : libraryProvider.isGridView
                          ? _buildGridView(books)
                          : _buildListView(books),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(List<UserBookModel> books) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: books.length,
          itemBuilder: (context, index) {
            final item = books[index];
            return Dismissible(
              key: ValueKey('dismiss_${item.id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: Colors.white, size: 28),
              ),
              confirmDismiss: (_) async {
                return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('¿Eliminar libro?'),
                        content: Text(
                            '¿Seguro que deseas quitar "${item.book.title}" de tu biblioteca?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Eliminar'),
                          ),
                        ],
                      ),
                    ) ??
                    false;
              },
              onDismissed: (_) {
                Provider.of<LibraryProvider>(context, listen: false)
                    .removeBook(item.id);
              },
              child: BookCard(
                book: item.book,
                userBook: item,
                style: BookCardStyle.libraryRow,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookDetailScreen(book: item.book),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGridView(List<UserBookModel> books) {
    // Ancho máximo del contenido para que en web las portadas no se estiren
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          // Rejilla adaptativa: celdas de ~136px de ancho y alto fijo, así
          // entran 3 por fila en móvil y más en pantallas anchas, sin que las
          // portadas crezcan sin control.
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 136,
            mainAxisExtent: 232,
            crossAxisSpacing: 14,
            mainAxisSpacing: 18,
          ),
          itemCount: books.length,
          itemBuilder: (context, index) {
            final item = books[index];
            final tag = BookCard.heroTagFor('librarygrid', item.book);
            return BookCard(
              book: item.book,
              userBook: item,
              style: BookCardStyle.gridItem,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        BookDetailScreen(book: item.book, heroTag: tag),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppTheme.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.collections_bookmark_outlined,
                  size: 40, color: AppTheme.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'Estantería vacía',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Explora nuevos libros y añádelos a tus estanterías para organizar tus lecturas.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppTheme.textSecondaryDark
                    : AppTheme.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Escanear un libro'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const IsbnScannerScreen()),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.download_rounded),
              label: const Text('Importar desde Goodreads'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GoodreadsImportScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
