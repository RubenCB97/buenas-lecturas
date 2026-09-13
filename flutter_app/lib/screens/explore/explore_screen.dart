import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/book_model.dart';
import '../../models/user_book_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/authors_provider.dart';
import '../../providers/explore_provider.dart';
import '../../providers/library_provider.dart';
import '../../widgets/author_tile.dart';
import '../../widgets/book_card.dart';
import '../../widgets/book_cover_image.dart';
import '../../widgets/custom_search_bar.dart';
import '../../widgets/reading_progress_bar.dart';
import '../book_detail/book_detail_screen.dart';
import 'new_releases_screen.dart';

/// Ámbito de la búsqueda en Explorar.
enum SearchScope { books, authors }

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  SearchScope _scope = SearchScope.books;

  /// Botón compacto de mercado para el carrusel de tendencias.
  Widget _regionChip(
    BuildContext context,
    ExploreProvider provider,
    String region,
    String label,
  ) {
    final selected = provider.trendingRegion == region;
    return GestureDetector(
      onTap: () => provider.setTrendingRegion(region),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected
                ? Colors.white
                : (Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.textSecondaryDark
                    : AppTheme.textSecondaryLight),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);
    final exploreProvider = Provider.of<ExploreProvider>(context);
    final libraryProvider = Provider.of<LibraryProvider>(context);
    final authorsProvider = Provider.of<AuthorsProvider>(context);
    final user = authProvider.currentUser;

    final hasQuery = _scope == SearchScope.books
        ? exploreProvider.searchQuery.isNotEmpty
        : authorsProvider.query.isNotEmpty;

    // Buscar si hay algún libro que esté leyendo actualmente
    final currentlyReading = libraryProvider.libraryBooks.firstWhere(
      (b) => b.status == ReadingStatus.reading,
      orElse: () => UserBookModel(
        id: 0,
        book: BookModel(title: ''),
        status: ReadingStatus.wantToRead,
      ),
    );
    final hasActiveReading = currentlyReading.id != 0;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async {
            await Future.wait([
              exploreProvider.fetchTrending(force: true),
              exploreProvider.fetchRecommended(),
              exploreProvider.fetchNewReleases(),
              libraryProvider.fetchLibrary(),
            ]);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // Barra superior / Cabecera
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BuenasLecturas',
                            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                  fontSize: 24,
                                  color: AppTheme.primary,
                                  letterSpacing: -0.5,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user != null ? 'Hola, ${user.firstName ?? 'Lector'} 👋' : 'Descubre tu próxima lectura',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.primaryLight,
                        backgroundImage: user?.picture != null ? NetworkImage(user!.avatarUrl) : null,
                        child: user?.picture == null
                            ? const Icon(Icons.person, color: AppTheme.primary, size: 22)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),

              // Barra de búsqueda con autocompletado
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: CustomSearchBar(
                    key: ValueKey('search_${_scope.name}'),
                    placeholder: _scope == SearchScope.books
                        ? 'Buscar libros por título, autor o tema…'
                        : 'Buscar autores por nombre…',
                    onChanged: (query) {
                      if (_scope == SearchScope.books) {
                        exploreProvider.onSearchQueryChanged(query);
                      } else {
                        authorsProvider.onQueryChanged(query);
                      }
                    },
                    onClear: () {
                      if (_scope == SearchScope.books) {
                        exploreProvider.clearSearch();
                      } else {
                        authorsProvider.clearSearch();
                      }
                    },
                  ),
                ),
              ),

              // Conmutador Libros / Autores
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
                  child: SegmentedButton<SearchScope>(
                    segments: const [
                      ButtonSegment(
                        value: SearchScope.books,
                        icon: Icon(Icons.menu_book_rounded, size: 16),
                        label: Text('Libros'),
                      ),
                      ButtonSegment(
                        value: SearchScope.authors,
                        icon: Icon(Icons.person_rounded, size: 16),
                        label: Text('Autores'),
                      ),
                    ],
                    selected: {_scope},
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      textStyle: WidgetStatePropertyAll(
                        TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    onSelectionChanged: (sel) {
                      setState(() => _scope = sel.first);
                      // Limpiamos la búsqueda del otro ámbito para no mezclar
                      if (_scope == SearchScope.books) {
                        authorsProvider.clearSearch();
                      } else {
                        exploreProvider.clearSearch();
                      }
                    },
                  ),
                ),
              ),

              // ---- Resultados de AUTORES ----
              if (_scope == SearchScope.authors && hasQuery) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Autores', style: Theme.of(context).textTheme.titleLarge),
                        if (authorsProvider.isSearching)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                          )
                        else
                          Text(
                            '${authorsProvider.searchResults.length} encontrados',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (authorsProvider.searchResults.isEmpty && !authorsProvider.isSearching)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.person_search_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          const Text('No se encontraron autores',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          const Text('Prueba con el nombre completo o parte del apellido',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => AuthorTile(author: authorsProvider.searchResults[index]),
                        childCount: authorsProvider.searchResults.length,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 30)),
              ]

              // ---- Ámbito autores sin query: mensaje guía ----
              else if (_scope == SearchScope.authors) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.person_search_rounded, size: 54, color: Colors.grey.withValues(alpha: 0.45)),
                        const SizedBox(height: 14),
                        const Text('Busca un autor',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(
                          'Escribe al menos 2 letras para ver su biografía, obras y nota media.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Si está buscando libros activamente, mostrar resultados
              if (_scope == SearchScope.books && exploreProvider.searchQuery.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Resultados de búsqueda',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (exploreProvider.isSearching)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                          )
                        else
                          Text(
                            '${exploreProvider.searchResults.length} encontrados',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (exploreProvider.searchResults.isEmpty && !exploreProvider.isSearching)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.menu_book_outlined, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          const Text(
                            'No se encontraron libros',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Prueba a buscar por título, autor o tema',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final book = exploreProvider.searchResults[index];
                          final tag = BookCard.heroTagFor('search', book);
                          return BookCard(
                            book: book,
                            style: BookCardStyle.largeFeed,
                            heroTag: tag,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BookDetailScreen(book: book, heroTag: tag),
                                ),
                              );
                            },
                          );
                        },
                        childCount: exploreProvider.searchResults.length,
                      ),
                    ),
                  ),
              ] else if (_scope == SearchScope.books) ...[
                // Banner "Actualmente Leyendo" (Estilo Goodreads)
                if (hasActiveReading)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Card(
                        color: isDark ? AppTheme.surfaceDarkSecondary : AppTheme.primaryLight.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isDark ? AppTheme.borderDark : AppTheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookDetailScreen(book: currentlyReading.book),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                BookCoverImage(
                                  imageUrl: currentlyReading.book.thumbnail,
                                  width: 60,
                                  height: 85,
                                  borderRadius: 8,
                                  title: currentlyReading.book.title,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.auto_stories_rounded, size: 14, color: AppTheme.primary),
                                          SizedBox(width: 4),
                                          Text(
                                            'ACTUALMENTE LEYENDO',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                              color: AppTheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        currentlyReading.book.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        currentlyReading.book.authorDisplay,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ReadingProgressBar(
                                        progress: currentlyReading.progressPercentage,
                                        currentPage: currentlyReading.currentPage ?? 120,
                                        totalPages: currentlyReading.book.effectivePageCount,
                                        height: 5,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Carrusel de Tendencias (con selector de mercado)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text('Tendencias literarias',
                              style: Theme.of(context).textTheme.titleLarge),
                        ),
                        // Selector España / EEUU
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.surfaceDarkSecondary : AppTheme.surfaceLightSecondary,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                          ),
                          padding: const EdgeInsets.all(3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _regionChip(context, exploreProvider, 'ES', '🇪🇸 España'),
                              const SizedBox(width: 2),
                              _regionChip(context, exploreProvider, 'GLOBAL', '🌍 Mundial'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Explicación de en qué se basa el ranking
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Row(
                      children: [
                        Icon(Icons.trending_up_rounded,
                            size: 13,
                            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            exploreProvider.trendingRegion == 'ES'
                                ? 'Literatura en español con más lectores en Open Library'
                                : 'Lo más leído esta semana en todo el mundo (Open Library)',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 265,
                    child: exploreProvider.isLoadingTrending && exploreProvider.trendingBooks.isEmpty
                        ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                        : exploreProvider.trendingBooks.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 20),
                                child: Center(
                                  child: Text('No hay tendencias disponibles ahora mismo',
                                      style: TextStyle(color: Colors.grey)),
                                ),
                              )
                            : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: exploreProvider.trendingBooks.length,
                      itemBuilder: (context, index) {
                        final book = exploreProvider.trendingBooks[index];
                        final tag = BookCard.heroTagFor('trending', book);
                        return BookCard(
                          book: book,
                          style: BookCardStyle.miniCarousel,
                          heroTag: tag,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookDetailScreen(book: book, heroTag: tag),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),

                // Novedades del año
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            children: [
                              const Icon(Icons.new_releases_rounded, color: AppTheme.primary, size: 20),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text('Novedades ${DateTime.now().year}',
                                    style: Theme.of(context).textTheme.titleLarge),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Text('Ver todas', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                          label: const Icon(Icons.arrow_forward_rounded, size: 15),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NewReleasesScreen(initialRegion: 'GLOBAL'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 265,
                    child: exploreProvider.isLoadingNewReleases && exploreProvider.newReleases.isEmpty
                        ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                        : exploreProvider.newReleases.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 20),
                                child: Center(child: Text('Sin novedades disponibles', style: TextStyle(color: Colors.grey))),
                              )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: exploreProvider.newReleases.length,
                                itemBuilder: (context, index) {
                                  final book = exploreProvider.newReleases[index];
                                  final tag = BookCard.heroTagFor('new', book);
                                  return BookCard(
                                    book: book,
                                    style: BookCardStyle.miniCarousel,
                                    heroTag: tag,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => BookDetailScreen(book: book, heroTag: tag)),
                                      );
                                    },
                                  );
                                },
                              ),
                  ),
                ),

                // Chips de Categorías
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    child: SizedBox(
                      height: 38,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: exploreProvider.categories.length,
                        itemBuilder: (context, index) {
                          final cat = exploreProvider.categories[index];
                          final isSelected = cat == exploreProvider.selectedCategory;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(cat),
                              selected: isSelected,
                              showCheckmark: false,
                              labelStyle: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight),
                              ),
                              backgroundColor: isDark ? AppTheme.surfaceDarkSecondary : AppTheme.surfaceLightSecondary,
                              selectedColor: AppTheme.primary,
                              side: BorderSide(
                                color: isSelected
                                    ? AppTheme.primary
                                    : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              onSelected: (_) {
                                exploreProvider.selectCategory(cat);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // Sección Recomendados / Para ti
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                    child: Text(
                      exploreProvider.selectedCategory == 'Todos'
                          ? 'Recomendados para ti'
                          : 'Libros de ${exploreProvider.selectedCategory}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final book = exploreProvider.recommendedBooks[index];
                        final tag = BookCard.heroTagFor('recommended', book);
                        return BookCard(
                          book: book,
                          style: BookCardStyle.largeFeed,
                          heroTag: tag,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookDetailScreen(book: book, heroTag: tag),
                              ),
                            );
                          },
                        );
                      },
                      childCount: exploreProvider.recommendedBooks.length,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 30),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
