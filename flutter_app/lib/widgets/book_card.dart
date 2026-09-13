import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/date_formatter.dart';
import '../models/book_model.dart';
import '../models/user_book_model.dart';
import '../providers/library_provider.dart';
import 'book_cover_image.dart';
import 'rating_stars.dart';
import 'reading_progress_bar.dart';
import 'status_badge.dart';

enum BookCardStyle {
  miniCarousel,
  largeFeed,
  libraryRow,
  gridItem,
}

class BookCard extends StatelessWidget {
  final BookModel book;
  final UserBookModel? userBook;
  final BookCardStyle style;
  final VoidCallback onTap;
  final VoidCallback? onToggleLibrary;

  /// Tag del Hero para animar la portada hacia la ficha del libro.
  ///
  /// Debe ser único dentro de la pantalla: un mismo libro puede aparecer en
  /// varias listas a la vez (Tendencias + Novedades, Saga + Similares...) y
  /// dos Heroes con el mismo tag rompen la animación. Usa
  /// [BookCard.heroTagFor] para construirlo con un prefijo por lista.
  /// Si es `null` no se envuelve en Hero (comportamiento seguro por defecto).
  final Object? heroTag;

  const BookCard({
    super.key,
    required this.book,
    this.userBook,
    this.style = BookCardStyle.largeFeed,
    required this.onTap,
    this.onToggleLibrary,
    this.heroTag,
  });

  /// Construye un tag de Hero único combinando el nombre de la lista con la
  /// identidad del libro. Ej: `BookCard.heroTagFor('trending', book)`.
  static String heroTagFor(String listName, BookModel book) {
    final id = book.googleId ?? book.id?.toString() ?? book.title;
    return 'cover_${listName}_$id';
  }

  /// Envuelve [child] en un Hero solo si hay [heroTag].
  Widget _maybeHero(Widget child) {
    if (heroTag == null) return child;
    return Hero(tag: heroTag!, child: child);
  }

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case BookCardStyle.miniCarousel:
        return _buildMiniCarouselCard(context);
      case BookCardStyle.largeFeed:
        return _buildLargeFeedCard(context);
      case BookCardStyle.libraryRow:
        return _buildLibraryRowCard(context);
      case BookCardStyle.gridItem:
        return _buildGridItemCard(context);
    }
  }

  // Tarjeta compacta para carruseles horizontales
  Widget _buildMiniCarouselCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 14),
        // La portada usa el espacio sobrante para que la tarjeta encaje en
        // cualquier altura de carrusel (240, 265...) sin desbordar.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: _maybeHero(
                BookCoverImage(
                  imageUrl: book.thumbnail,
                  width: 120,
                  height: double.infinity,
                  borderRadius: 10,
                  title: book.title,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              book.authorDisplay,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: isDark
                    ? AppTheme.textSecondaryDark
                    : AppTheme.textSecondaryLight,
              ),
            ),
            if (book.averageRating != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.star_rounded,
                      size: 13, color: AppTheme.starGold),
                  const SizedBox(width: 3),
                  Text(
                    book.averageRating!.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Tarjeta destacada en feed principal
  Widget _buildLargeFeedCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final libraryProvider = Provider.of<LibraryProvider>(context);
    final inLibrary = libraryProvider.isInLibrary(book);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _maybeHero(
                BookCoverImage(
                  imageUrl: book.thumbnail,
                  width: 90,
                  height: 135,
                  borderRadius: 10,
                  title: book.title,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (book.categories.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          book.genreDisplay,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      book.authorDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight,
                      ),
                    ),
                    if (book.description != null &&
                        book.description!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        book.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondaryLight,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (book.averageRating != null)
                          RatingStars(
                              rating: book.averageRating!,
                              size: 13,
                              showScoreText: true)
                        else
                          const SizedBox.shrink(),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            inLibrary
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_add_outlined,
                            color: inLibrary
                                ? AppTheme.primary
                                : (isDark
                                    ? AppTheme.textSecondaryDark
                                    : AppTheme.textSecondaryLight),
                            size: 24,
                          ),
                          onPressed: onToggleLibrary ??
                              () {
                                if (inLibrary) {
                                  final ub = libraryProvider.getUserBook(book);
                                  if (ub != null)
                                    libraryProvider.removeBook(ub.id);
                                } else {
                                  libraryProvider.addBook(book,
                                      status: ReadingStatus.wantToRead);
                                }
                              },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Fila de biblioteca personal con estado y progreso
  Widget _buildLibraryRowCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = userBook?.status ?? ReadingStatus.wantToRead;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              BookCoverImage(
                imageUrl: book.thumbnail,
                width: 65,
                height: 95,
                borderRadius: 8,
                title: book.title,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            StatusBadge(status: status, isSmall: true),
                            if (userBook?.isFavorite == true) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.favorite_rounded,
                                  size: 14, color: Colors.redAccent),
                            ],
                          ],
                        ),
                        if (userBook?.rating != null)
                          RatingStars(rating: userBook!.rating!, size: 13)
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.authorDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight,
                      ),
                    ),
                    if (status == ReadingStatus.reading) ...[
                      const SizedBox(height: 8),
                      ReadingProgressBar(
                        progress: userBook?.progressPercentage ?? 0.0,
                        currentPage: userBook?.currentPage ?? 0,
                        totalPages: book.effectivePageCount,
                        height: 5,
                      ),
                    ] else if (status == ReadingStatus.read &&
                        userBook?.finishedAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Terminado ${DateFormatter.formatShort(userBook!.finishedAt)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondaryLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Vista en cuadrícula de la biblioteca
  Widget _buildGridItemCard(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _maybeHero(
                    BookCoverImage(
                      imageUrl: book.thumbnail,
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: 10,
                      title: book.title,
                    ),
                  ),
                ),
                if (userBook != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: StatusBadge(status: userBook!.status, isSmall: true),
                  ),
                if (userBook?.isFavorite == true)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite_rounded,
                          size: 12, color: Colors.redAccent),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
          ),
          Text(
            book.authorDisplay,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
