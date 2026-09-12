import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/book_model.dart';
import '../../models/user_book_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/book_detail_provider.dart';
import '../../providers/library_provider.dart';
import '../../widgets/book_card.dart';
import '../../widgets/book_cover_image.dart';
import '../../widgets/rating_breakdown.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/reading_progress_bar.dart';
import '../author/author_screen.dart';
import '../challenges/add_to_challenge_sheet.dart';
import '../social/add_quote_sheet.dart';
import '../social/pick_shelf_sheet.dart';
import '../social/recommend_sheet.dart';
import 'notes_sheet.dart';
import 'update_progress_sheet.dart';
import 'write_review_sheet.dart';

class BookDetailScreen extends StatefulWidget {
  final BookModel book;

  /// Tag del Hero de origen para animar la portada. Debe coincidir con el que
  /// usó la tarjeta desde la que se navegó. Si es `null`, no hay animación
  /// (evita el error de tags duplicados cuando un libro sale en varias listas).
  final Object? heroTag;

  const BookDetailScreen({super.key, required this.book, this.heroTag});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  bool _isSynopsisExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<BookDetailProvider>(context, listen: false);
      provider.fetchReviews(widget.book.googleId ?? widget.book.id?.toString());
      provider.fetchSimilarBooks(widget.book);
      provider.fetchSeriesBooks(widget.book);
    });
  }

  void _showStatusBottomSheet(BuildContext context, UserBookModel? userBook) {
    final libraryProvider = Provider.of<LibraryProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Cambiar estado de lectura',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.bookmark_added_rounded, color: Color(0xFF4B5563)),
                  title: const Text('Quiero leer'),
                  trailing: userBook?.status == ReadingStatus.wantToRead
                      ? const Icon(Icons.check_rounded, color: AppTheme.primary)
                      : null,
                  onTap: () {
                    if (userBook != null) {
                      libraryProvider.updateStatus(userBook.id, ReadingStatus.wantToRead);
                    } else {
                      libraryProvider.addBook(widget.book, status: ReadingStatus.wantToRead);
                    }
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.auto_stories_rounded, color: AppTheme.primary),
                  title: const Text('Leyendo actualmente'),
                  trailing: userBook?.status == ReadingStatus.reading
                      ? const Icon(Icons.check_rounded, color: AppTheme.primary)
                      : null,
                  onTap: () {
                    if (userBook != null) {
                      libraryProvider.updateStatus(userBook.id, ReadingStatus.reading);
                    } else {
                      libraryProvider.addBook(widget.book, status: ReadingStatus.reading);
                    }
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.check_circle_rounded, color: AppTheme.accentSage),
                  title: const Text('Leído'),
                  trailing: userBook?.status == ReadingStatus.read
                      ? const Icon(Icons.check_rounded, color: AppTheme.accentSage)
                      : null,
                  onTap: () {
                    if (userBook != null) {
                      libraryProvider.updateStatus(userBook.id, ReadingStatus.read);
                    } else {
                      libraryProvider.addBook(widget.book, status: ReadingStatus.read);
                    }
                    Navigator.pop(ctx);
                  },
                ),
                if (userBook != null) ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    title: const Text('Eliminar de mi Biblioteca', style: TextStyle(color: Colors.redAccent)),
                    onTap: () {
                      libraryProvider.removeBook(userBook.id);
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _openWriteReviewSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => WriteReviewSheet(book: widget.book),
    );
  }

  void _openUpdateProgressSheet(UserBookModel userBook) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => UpdateProgressSheet(userBook: userBook, book: widget.book),
    );
  }

  void _openNotesSheet(UserBookModel userBook) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => NotesSheet(userBook: userBook),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final libraryProvider = Provider.of<LibraryProvider>(context);
    final detailProvider = Provider.of<BookDetailProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final userBook = libraryProvider.getUserBook(widget.book);
    final inLibrary = userBook != null;

    final avgRating = widget.book.averageRating ?? 4.5;
    final totalRatings = widget.book.ratingsCount ?? 12500;
    final distribution = detailProvider.getRatingDistribution(avgRating);
    final myReview = detailProvider.myReviewFor(authProvider.currentUser?.id);
    final currentUserId = authProvider.currentUser?.id?.toString();
    final otherReviews = detailProvider.reviews
        .where((r) => currentUserId == null || r.user?.id?.toString() != currentUserId)
        .toList();

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (inLibrary)
            IconButton(
              icon: Icon(
                userBook.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: userBook.isFavorite ? Colors.redAccent : null,
              ),
              tooltip: userBook.isFavorite ? 'Quitar de favoritos' : 'Añadir a favoritos',
              onPressed: () {
                libraryProvider.toggleFavorite(userBook.id);
              },
            ),
          IconButton(
            icon: Icon(
              inLibrary ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: inLibrary ? AppTheme.primary : null,
            ),
            onPressed: () {
              if (inLibrary) {
                libraryProvider.removeBook(userBook.id);
              } else {
                libraryProvider.addBook(widget.book, status: ReadingStatus.wantToRead);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enlace copiado al portapapeles')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera con Portada y Datos Principales
            Center(
              child: Column(
                children: [
                  _coverWithOptionalHero(),
                  const SizedBox(height: 16),
                  Text(
                    widget.book.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          height: 1.2,
                        ),
                  ),
                  if (widget.book.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.book.subtitle!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  _buildAuthorLinks(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RatingStars(rating: avgRating, size: 16, showScoreText: true),
                      const SizedBox(width: 16),
                      if (widget.book.hasPageCount)
                        Text(
                          widget.book.pageCountDisplay!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // Botón principal de estado
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: inLibrary ? AppTheme.accentSage : AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: Icon(
                      inLibrary ? Icons.check_circle_rounded : Icons.bookmark_add_rounded,
                      size: 20,
                    ),
                    label: Text(
                      inLibrary ? userBook.status.label : 'Añadir a mi Biblioteca',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _showStatusBottomSheet(context, userBook),
                  ),
                ),
                if (inLibrary) ...[
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.arrow_drop_down_rounded, size: 28),
                    onPressed: () => _showStatusBottomSheet(context, userBook),
                  ),
                ],
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  tooltip: 'Añadir a un reto lector',
                  icon: const Icon(Icons.emoji_events_rounded, size: 20, color: Color(0xFFF59E0B)),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                      builder: (_) => AddToChallengeSheet(book: widget.book),
                    );
                  },
                ),
              ],
            ),

            // Sección exclusiva de progreso si el libro se está leyendo
            if (inLibrary && userBook.status == ReadingStatus.reading) ...[
              const SizedBox(height: 16),
              _buildProgressCard(context, userBook),
            ],

            // Fechas de lectura al estilo Goodreads
            if (inLibrary && (userBook.startedAt != null || userBook.finishedAt != null)) ...[
              const SizedBox(height: 8),
              _buildReadingDates(context, userBook),
            ],

            const SizedBox(height: 18),

            // Selector interactivo de Tu Puntuación
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surfaceDarkSecondary : AppTheme.surfaceLightSecondary,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tu calificación:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  RatingStars(
                    rating: userBook?.rating ?? 0,
                    size: 24,
                    isInteractive: true,
                    allowHalf: true,
                    onRatingUpdate: (rating) {
                      if (inLibrary) {
                        libraryProvider.updateRating(userBook.id, rating);
                      } else {
                        libraryProvider.addBook(widget.book, status: ReadingStatus.read).then((_) {
                          final ub = libraryProvider.getUserBook(widget.book);
                          if (ub != null) libraryProvider.updateRating(ub.id, rating);
                        });
                      }
                    },
                  ),
                ],
              ),
            ),

            // Acciones rápidas del libro (notas, escribir reseña, progreso)
            if (inLibrary) ...[
              const SizedBox(height: 14),
              _buildQuickActions(context, userBook),
            ],

            const SizedBox(height: 24),

            // Sinopsis con expansión elegante
            if (widget.book.description != null && widget.book.description!.isNotEmpty) ...[
              Text('Sinopsis', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                widget.book.description!,
                maxLines: _isSynopsisExpanded ? null : 4,
                overflow: _isSynopsisExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.6,
                  color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isSynopsisExpanded = !_isSynopsisExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _isSynopsisExpanded ? 'Mostrar menos' : 'Leer más sinopsis',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Desglose de Puntuación estilo Goodreads
            Text('Calificaciones de la comunidad', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            RatingBreakdown(
              averageRating: avgRating,
              totalRatings: totalRatings,
              distribution: distribution,
            ),

            const SizedBox(height: 24),

            // Metadatos y Detalles del libro
            Text('Detalles de la edición', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildMetaRow('Editorial', widget.book.publisher),
                    _buildMetaRow('Fecha de publicación', widget.book.publishedDate),
                    _buildMetaRow('Géneros', widget.book.categories.isNotEmpty ? widget.book.categories.join(', ') : null),
                    _buildMetaRow('Idioma', widget.book.language?.toUpperCase()),
                    _buildMetaRow('ISBN', widget.book.isbn),
                    _buildMetaRow('ASIN', widget.book.asin),
                    _buildMetaRow('Premios', widget.book.awards),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Reseña propia
            if (myReview != null) ...[
              Text('Tu reseña', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Card(
                color: isDark ? AppTheme.surfaceDarkSecondary : AppTheme.primaryLight.withValues(alpha: 0.35),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          RatingStars(rating: myReview.rating, size: 14),
                          const SizedBox(width: 8),
                          Text(
                            DateFormatter.timeAgo(myReview.createdAt),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        myReview.content,
                        style: const TextStyle(fontSize: 13.5, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Reseñas de la Comunidad
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Reseñas de lectores', style: Theme.of(context).textTheme.titleLarge),
                if (myReview == null)
                  TextButton.icon(
                    onPressed: _openWriteReviewSheet,
                    icon: const Icon(Icons.rate_review_outlined, size: 18),
                    label: const Text('Escribir'),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (detailProvider.isLoadingReviews)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              )
            else if (otherReviews.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Aún no hay reseñas de la comunidad para este libro. ¡Sé el primero en compartir tu opinión!',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: otherReviews.length,
                separatorBuilder: (_, __) => const Divider(height: 24),
                itemBuilder: (context, index) {
                  final rev = otherReviews[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundImage: rev.user?.picture != null ? NetworkImage(rev.user!.avatarUrl) : null,
                            child: rev.user?.picture == null ? const Icon(Icons.person, size: 18) : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rev.user?.fullName ?? 'Lector anónimo',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                                Row(
                                  children: [
                                    RatingStars(rating: rev.rating, size: 12),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormatter.timeAgo(rev.createdAt),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        rev.content,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.4,
                          color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                        ),
                      ),
                    ],
                  );
                },
              ),

            const SizedBox(height: 28),

            // Libros de la misma saga / serie
            if (detailProvider.seriesBooks.isNotEmpty || detailProvider.isLoadingSeries) ...[
              Row(
                children: [
                  const Icon(Icons.auto_awesome_motion_rounded, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text('De la misma saga',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 240,
                child: detailProvider.isLoadingSeries
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                    : detailProvider.seriesBooks.isEmpty
                        ? const Center(child: Text('Sin libros de la misma saga detectados', style: TextStyle(color: Colors.grey, fontSize: 12)))
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: detailProvider.seriesBooks.length,
                            itemBuilder: (context, index) {
                              final b = detailProvider.seriesBooks[index];
                              final tag = BookCard.heroTagFor('series', b);
                              return BookCard(
                                book: b,
                                style: BookCardStyle.miniCarousel,
                                heroTag: tag,
                                onTap: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (_) => BookDetailScreen(book: b, heroTag: tag)),
                                  );
                                },
                              );
                            },
                          ),
              ),
              const SizedBox(height: 24),
            ],

            // Libros similares (Readers also enjoyed)
            if (detailProvider.similarBooks.isNotEmpty || detailProvider.isLoadingSimilar) ...[
              Row(
                children: [
                  const Icon(Icons.recommend_rounded, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text('Los lectores también disfrutaron',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 240,
                child: detailProvider.isLoadingSimilar
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: detailProvider.similarBooks.length,
                        itemBuilder: (context, index) {
                          final b = detailProvider.similarBooks[index];
                          final tag = BookCard.heroTagFor('similar', b);
                          return BookCard(
                            book: b,
                            style: BookCardStyle.miniCarousel,
                            heroTag: tag,
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => BookDetailScreen(book: b, heroTag: tag)),
                              );
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }

  /// Autores del libro como enlaces a su ficha. Si hay varios, cada uno es
  /// pulsable por separado.
  Widget _buildAuthorLinks() {
    final authors = widget.book.authors.where((a) => a.trim().isNotEmpty).toList();

    if (authors.isEmpty) {
      return Text(
        widget.book.authorDisplay,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.primary),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        for (int i = 0; i < authors.length; i++) ...[
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AuthorScreen(authorName: authors[i])),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    authors[i],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.north_east_rounded, size: 12, color: AppTheme.primary),
                ],
              ),
            ),
          ),
          if (i < authors.length - 1)
            const Text('·', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ],
    );
  }

  /// Portada de cabecera, envuelta en Hero solo si la pantalla anterior
  /// aportó un tag (evita heroes duplicados entre carruseles).
  Widget _coverWithOptionalHero() {
    final cover = BookCoverImage(
      imageUrl: widget.book.thumbnail,
      width: 140,
      height: 210,
      borderRadius: 12,
      title: widget.book.title,
    );
    if (widget.heroTag == null) return cover;
    return Hero(tag: widget.heroTag!, child: cover);
  }

  Widget _buildProgressCard(BuildContext context, UserBookModel userBook) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalPages = widget.book.effectivePageCount;
    final currentPage = userBook.currentPage ?? 0;

    return Card(
      color: isDark ? AppTheme.surfaceDarkSecondary : AppTheme.primaryLight.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_stories_rounded, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text('Estás leyendo este libro',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const Spacer(),
                Text(
                  '${(userBook.progressPercentage * 100).round()}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ReadingProgressBar(
              progress: userBook.progressPercentage,
              currentPage: currentPage,
              totalPages: totalPages,
              height: 6,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('Actualizar progreso'),
                    onPressed: () => _openUpdateProgressSheet(userBook),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingDates(BuildContext context, UserBookModel userBook) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;

    Widget dateItem(IconData icon, String label, DateTime date, Color color) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            '$label ${DateFormatter.formatShort(date)}',
            style: TextStyle(fontSize: 12, color: secondaryColor, fontWeight: FontWeight.w500),
          ),
        ],
      );
    }

    return Row(
      children: [
        if (userBook.startedAt != null)
          dateItem(Icons.play_arrow_rounded, 'Empezado', userBook.startedAt!, AppTheme.primary),
        if (userBook.startedAt != null && userBook.finishedAt != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('·', style: TextStyle(color: secondaryColor, fontWeight: FontWeight.bold)),
          ),
        if (userBook.finishedAt != null)
          dateItem(Icons.flag_rounded, 'Terminado', userBook.finishedAt!, AppTheme.accentSage),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, UserBookModel userBook) {
    Widget action(IconData icon, String label, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: OutlinedButton.icon(
          icon: Icon(icon, size: 16),
          label: Text(label, style: const TextStyle(fontSize: 12)),
          onPressed: onTap,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          action(Icons.lock_outline_rounded, userBook.notes != null && userBook.notes!.isNotEmpty ? 'Ver notas' : 'Notas', () => _openNotesSheet(userBook)),
          action(Icons.rate_review_outlined, 'Reseñar', _openWriteReviewSheet),
          action(Icons.format_quote_rounded, 'Cita', () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (_) => AddQuoteSheet(book: widget.book),
            );
          }),
          action(Icons.recommend_rounded, 'Recomendar', () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (_) => RecommendSheet(book: widget.book),
            );
          }),
          action(Icons.library_books_outlined, 'Estantería', () {
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (_) => PickShelfSheet(book: widget.book),
            );
          }),
          action(Icons.emoji_events_outlined, 'Añadir a reto', () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (_) => AddToChallengeSheet(book: widget.book),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
