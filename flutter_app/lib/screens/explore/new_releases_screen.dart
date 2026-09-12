import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/book_model.dart';
import '../../providers/new_releases_provider.dart';
import '../../widgets/book_card.dart';
import '../book_detail/book_detail_screen.dart';

/// Pantalla completa de novedades del año, con filtros de región, año y orden,
/// y scroll infinito.
class NewReleasesScreen extends StatefulWidget {
  /// Región inicial: 'ES' o 'GLOBAL'.
  final String initialRegion;

  const NewReleasesScreen({super.key, this.initialRegion = 'GLOBAL'});

  @override
  State<NewReleasesScreen> createState() => _NewReleasesScreenState();
}

class _NewReleasesScreenState extends State<NewReleasesScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _gridView = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<NewReleasesProvider>(context, listen: false);
      if (provider.region != widget.initialRegion) {
        provider.setRegion(widget.initialRegion);
      } else if (provider.books.isEmpty) {
        provider.load();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // Cargamos la siguiente página cuando faltan ~600px para el final
    if (pos.pixels >= pos.maxScrollExtent - 600) {
      Provider.of<NewReleasesProvider>(context, listen: false).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NewReleasesProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Novedades ${provider.year}'),
        actions: [
          IconButton(
            tooltip: _gridView ? 'Vista en lista' : 'Vista en cuadrícula',
            icon: Icon(
                _gridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
            onPressed: () => setState(() => _gridView = !_gridView),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(provider, isDark),
          Expanded(
            child: provider.isLoading && provider.books.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary))
                : provider.books.isEmpty
                    ? _buildEmpty(provider)
                    : RefreshIndicator(
                        color: AppTheme.primary,
                        onRefresh: provider.refresh,
                        // Limitamos el ancho del contenido para que en web
                        // las tarjetas no se estiren de lado a lado.
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 900),
                            child: _gridView
                                ? _buildGrid(provider)
                                : _buildList(provider),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(NewReleasesProvider provider, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
        border: Border(
          bottom: BorderSide(
              color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Región + año
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.surfaceDarkSecondary
                          : AppTheme.surfaceLightSecondary,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isDark
                              ? AppTheme.borderDark
                              : AppTheme.borderLight),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _chip(
                          label: '🇪🇸 España',
                          selected: provider.region == 'ES',
                          onTap: () => provider.setRegion('ES'),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 2),
                        _chip(
                          label: '🌍 Mundial',
                          selected: provider.region == 'GLOBAL',
                          onTap: () => provider.setRegion('GLOBAL'),
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: provider.year,
                      isDense: true,
                      borderRadius: BorderRadius.circular(12),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppTheme.textPrimaryDark
                            : AppTheme.textPrimaryLight,
                      ),
                      items: provider.availableYears
                          .map((y) =>
                              DropdownMenuItem(value: y, child: Text('$y')))
                          .toList(),
                      onChanged: (y) {
                        if (y != null) provider.setYear(y);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Orden + contador
              Row(
                children: [
                  ...NewReleasesSort.values.map((s) {
                    final selected = provider.sort == s;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(
                          s.icon,
                          size: 15,
                          color: selected ? Colors.white : AppTheme.primary,
                        ),
                        label:
                            Text(s.label, style: const TextStyle(fontSize: 12)),
                        selected: selected,
                        showCheckmark: false,
                        selectedColor: AppTheme.primary,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : null,
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.w500,
                        ),
                        onSelected: (_) => provider.setSort(s),
                      ),
                    );
                  }),
                  const Spacer(),
                  if (provider.total > 0)
                    Text(
                      '${provider.total} libros',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected
                ? Colors.white
                : (isDark
                    ? AppTheme.textSecondaryDark
                    : AppTheme.textSecondaryLight),
          ),
        ),
      ),
    );
  }

  void _openBook(BookModel book) {
    final tag = BookCard.heroTagFor('newreleases', book);
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => BookDetailScreen(book: book, heroTag: tag)),
    );
  }

  Widget _buildGrid(NewReleasesProvider provider) {
    return GridView.builder(
      controller: _scrollController,
      physics:
          const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      // Rejilla adaptativa: el ancho de celda se mantiene ~130px y el alto es
      // fijo, así las portadas no se disparan en pantallas anchas (web/tablet)
      // y siguen entrando 3 por fila en móvil.
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 136,
        mainAxisExtent: 232,
        crossAxisSpacing: 12,
        mainAxisSpacing: 18,
      ),
      itemCount: provider.books.length + (provider.isLoadingMore ? 3 : 0),
      itemBuilder: (context, index) {
        if (index >= provider.books.length) {
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.primary),
            ),
          );
        }
        final book = provider.books[index];
        return BookCard(
          book: book,
          style: BookCardStyle.gridItem,
          onTap: () => _openBook(book),
        );
      },
    );
  }

  Widget _buildList(NewReleasesProvider provider) {
    return ListView.builder(
      controller: _scrollController,
      physics:
          const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: provider.books.length + (provider.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= provider.books.length) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
                child: CircularProgressIndicator(color: AppTheme.primary)),
          );
        }
        final book = provider.books[index];
        final tag = BookCard.heroTagFor('newreleases', book);
        return BookCard(
          book: book,
          style: BookCardStyle.largeFeed,
          heroTag: tag,
          onTap: () => _openBook(book),
        );
      },
    );
  }

  Widget _buildEmpty(NewReleasesProvider provider) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              children: [
                const Icon(Icons.auto_stories_outlined,
                    size: 60, color: Colors.grey),
                const SizedBox(height: 14),
                Text(
                  provider.error != null
                      ? 'No se pudo cargar'
                      : 'Sin novedades',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  provider.error != null
                      ? 'Revisa la conexión con el servidor e inténtalo de nuevo.'
                      : 'No hay libros publicados en ${provider.year} '
                          '${provider.region == 'ES' ? 'en español' : ''} con estos filtros.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                  onPressed: provider.refresh,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
