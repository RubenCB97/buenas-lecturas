import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/book_model.dart';
import '../../models/user_book_model.dart';
import '../../providers/discover_provider.dart';
import '../../providers/library_provider.dart';
import '../../widgets/book_card.dart';
import '../../widgets/book_cover_image.dart';
import '../book_detail/book_detail_screen.dart';
import '../explore/new_releases_screen.dart';

/// Pestaña Descubrir: recomendaciones personales y lo más leído/nuevo.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  /// Firma de los libros que sirven de base a las recomendaciones. Cuando
  /// cambia (puntúas un libro, lo marcas favorito o lo terminas) se recargan.
  String? _seedSignature;

  static const _monthNames = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<DiscoverProvider>(context, listen: false);
      // Las recomendaciones son por usuario: se piden de nuevo en cada inicio
      // de sesión para no mostrar las del usuario anterior.
      provider.loadForYou(force: true);
      provider.load();
    });
  }

  String _signatureOf(List<UserBookModel> library) {
    final ids = library
        .where((ub) =>
            (ub.rating ?? 0) >= 4 || ub.isFavorite || ub.status == ReadingStatus.read)
        .map((ub) => '${ub.book.id}:${ub.rating}:${ub.isFavorite}:${ub.status.name}')
        .toList()
      ..sort();
    return ids.join('|');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final library = Provider.of<LibraryProvider>(context).libraryBooks;
    final signature = _signatureOf(library);
    if (_seedSignature != null && signature != _seedSignature) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Provider.of<DiscoverProvider>(context, listen: false).loadForYou(force: true);
      });
    }
    _seedSignature = signature;
  }

  void _openBook(BookModel book, String heroTag) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookDetailScreen(book: book, heroTag: heroTag)),
    );
  }

  String _recentTitle(RecentReleases recent) {
    switch (recent.windowMonths) {
      case 0:
      case 1:
        return 'Lanzados este mes';
      default:
        return 'Lanzados en los últimos ${recent.windowMonths} meses';
    }
  }

  String? _recentSubtitle(RecentReleases recent) {
    if (recent.windowMonths <= 1 || recent.since.length < 7) return null;
    final month = int.tryParse(recent.since.substring(5, 7));
    if (month == null || month < 1 || month > 12) return null;
    return 'Desde ${_monthNames[month - 1]} · aún hay pocos libros de este mes catalogados';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DiscoverProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final year = DateTime.now().year;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Descubrir'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _RegionToggle(
              region: provider.region,
              onChanged: provider.setRegion,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () => provider.load(force: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            // ---- Para ti ----
            ..._buildForYou(provider, isDark),

            // ---- Lo más leído esta semana ----
            _SectionHeader(
              icon: Icons.local_fire_department_rounded,
              title: 'Lo más leído esta semana',
              subtitle: provider.region == 'ES'
                  ? 'Literatura en español con más lectores'
                  : 'Lo que más se lee en todo el mundo',
            ),
            _Carousel(
              books: provider.weekBooks,
              loading: provider.isLoadingWeek,
              emptyText: 'No hay datos de esta semana ahora mismo',
              heroPrefix: 'discover_week_${provider.region}',
              onTap: _openBook,
            ),

            // ---- Lanzados este mes ----
            _SectionHeader(
              icon: Icons.fiber_new_rounded,
              title: _recentTitle(provider.recent),
              subtitle: _recentSubtitle(provider.recent),
            ),
            _Carousel(
              books: provider.recent.books,
              loading: provider.isLoadingRecent,
              emptyText: 'Todavía no hay lanzamientos recientes catalogados',
              heroPrefix: 'discover_recent_${provider.region}',
              onTap: _openBook,
            ),

            // ---- Lanzados este año ----
            _SectionHeader(
              icon: Icons.calendar_month_rounded,
              title: 'Lanzados en $year',
              actionLabel: 'Ver todos',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NewReleasesScreen(initialRegion: provider.region),
                ),
              ),
            ),
            _Carousel(
              books: provider.yearBooks,
              loading: provider.isLoadingYear,
              emptyText: 'No hay novedades de $year disponibles',
              heroPrefix: 'discover_year_${provider.region}',
              onTap: _openBook,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildForYou(DiscoverProvider provider, bool isDark) {
    if (provider.isLoadingForYou && !provider.forYouLoaded) {
      return [
        const _SectionHeader(icon: Icons.auto_awesome_rounded, title: 'Recomendados para ti'),
        const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        ),
      ];
    }

    if (!provider.hasSeeds) {
      return [
        const _SectionHeader(icon: Icons.auto_awesome_rounded, title: 'Recomendados para ti'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDarkSecondary : AppTheme.primaryLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.star_rate_rounded, color: AppTheme.starGold, size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Puntúa con 4★ o más los libros que te gusten, o márcalos como favoritos, '
                    'y aquí te recomendaremos otros parecidos.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    if (provider.forYou.isEmpty) {
      // Tiene libros de base pero no encontramos parecidos (o falló la carga)
      return const [];
    }

    return [
      for (final section in provider.forYou) ...[
        _ForYouHeader(section: section, onTapSeed: _openBook),
        _Carousel(
          books: section.books,
          loading: false,
          emptyText: '',
          heroPrefix: 'discover_foryou_${section.seed.googleId ?? section.seed.id ?? section.seed.title}',
          onTap: _openBook,
        ),
      ],
    ];
  }
}

// ---------------------------------------------------------------------------
// Widgets de la pantalla
// ---------------------------------------------------------------------------

class _RegionToggle extends StatelessWidget {
  final String region;
  final ValueChanged<String> onChanged;

  const _RegionToggle({required this.region, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget chip(String value, String label) {
      final selected = region == value;
      return GestureDetector(
        onTap: () => onChanged(value),
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
                  : (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
            ),
          ),
        ),
      );
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDarkSecondary : AppTheme.surfaceLightSecondary,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            chip('ES', '🇪🇸 España'),
            const SizedBox(width: 2),
            chip('GLOBAL', '🌍 Mundial'),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 12, 10),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _ForYouHeader extends StatelessWidget {
  final ForYouSection section;
  final void Function(BookModel book, String heroTag) onTapSeed;

  const _ForYouHeader({required this.section, required this.onTapSeed});

  String get _reasonText {
    switch (section.reason) {
      case 'rated':
        final r = section.rating ?? 0;
        final value = r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(1).replaceAll('.', ',');
        return 'Lo puntuaste con $value★';
      case 'favorite':
        return 'Está en tus favoritos';
      default:
        return 'Lo has leído';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final seed = section.seed;
    final seedTag = 'discover_seed_${seed.googleId ?? seed.id ?? seed.title}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => onTapSeed(seed, seedTag),
            child: Hero(
              tag: seedTag,
              child: BookCoverImage(
                imageUrl: seed.thumbnail,
                width: 34,
                height: 50,
                borderRadius: 5,
                title: seed.title,
                hasShadow: false,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Porque te gustó '),
                      TextSpan(
                        text: '«${seed.title}»',
                        style: const TextStyle(color: AppTheme.primary),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 2),
                Text(
                  _reasonText,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Carousel extends StatelessWidget {
  final List<BookModel> books;
  final bool loading;
  final String emptyText;
  final String heroPrefix;
  final void Function(BookModel book, String heroTag) onTap;

  const _Carousel({
    required this.books,
    required this.loading,
    required this.emptyText,
    required this.heroPrefix,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return SizedBox(
        height: loading ? 265 : 70,
        child: Center(
          child: loading
              ? const CircularProgressIndicator(color: AppTheme.primary)
              : Text(emptyText, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ),
      );
    }

    return SizedBox(
      height: 265,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: books.length,
        itemBuilder: (context, index) {
          final book = books[index];
          final tag = BookCard.heroTagFor(heroPrefix, book);
          return BookCard(
            book: book,
            style: BookCardStyle.miniCarousel,
            heroTag: tag,
            onTap: () => onTap(book, tag),
          );
        },
      ),
    );
  }
}
