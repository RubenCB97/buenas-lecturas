import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/library_provider.dart';
import '../../widgets/book_cover_image.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/reading_progress_bar.dart';
import '../auth/login_screen.dart';
import '../book_detail/book_detail_screen.dart';
import '../../providers/theme_provider.dart';
import '../social/shelves_screen.dart';
import '../import/export_library_tile.dart';
import '../import/goodreads_import_screen.dart';
import 'avatar_picker_sheet.dart';
import 'reading_stats_screen.dart';
import 'edit_profile_sheet.dart';
import 'theme_settings_sheet.dart';
import 'year_in_review_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _openAvatarPicker(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AvatarPickerSheet(user: user),
    );
  }

  void _openEditSheet(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser != null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => EditProfileSheet(user: authProvider.currentUser!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);
    final libraryProvider = Provider.of<LibraryProvider>(context);
    final user = authProvider.currentUser;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_circle_outlined, size: 70, color: AppTheme.primary),
              const SizedBox(height: 16),
              const Text('Inicia sesión para ver tu perfil', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                },
                child: const Text('Iniciar sesión'),
              ),
            ],
          ),
        ),
      );
    }

    final year = DateTime.now().year;
    final booksReadThisYear = libraryProvider.booksReadThisYear;
    final readingGoal = user.readingGoal;
    final goalProgress = (booksReadThisYear / readingGoal).clamp(0.0, 1.0);
    final genres = user.favoriteGenre?.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList() ?? ['Ficción', 'Clásicos'];
    final currentlyReading = libraryProvider.currentlyReading;
    final avgUserRating = libraryProvider.userAverageRating;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, theme, _) => IconButton(
              tooltip: 'Apariencia',
              icon: Icon(theme.mode.icon),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                  builder: (_) => const ThemeSettingsSheet(),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar perfil',
            onPressed: () => _openEditSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Cerrar sesión'),
                  content: const Text('¿Deseas salir de tu cuenta?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Salir'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await authProvider.logout();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Avatar, Nombre y Bio
            Row(
              children: [
                // Avatar pulsable para cambiar la foto de perfil
                GestureDetector(
                  onTap: () => _openAvatarPicker(context, user),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppTheme.primaryLight,
                        backgroundImage: user.hasAvatar ? NetworkImage(user.avatarUrl) : null,
                        child: !user.hasAvatar
                            ? Text(
                                user.initial,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryDark,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? AppTheme.bgDark : AppTheme.bgLight,
                              width: 2,
                            ),
                          ),
                          child: const Icon(Icons.photo_camera_rounded, size: 13, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '📚 Lector Ávido',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (user.bio != null && user.bio!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                user.bio!,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Tarjeta Reto de Lectura Anual (Firma de Goodreads)
            Card(
              color: isDark ? AppTheme.surfaceDarkSecondary : AppTheme.surfaceLightSecondary,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.emoji_events_rounded, color: AppTheme.starGold, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Reto de Lectura $year',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16),
                            ),
                          ],
                        ),
                        Text(
                          '$booksReadThisYear de $readingGoal libros',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ReadingProgressBar(
                      progress: goalProgress,
                      showLabel: false,
                      height: 8,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      booksReadThisYear >= readingGoal
                          ? '¡Enhorabuena! Has completado tu reto anual 🎉'
                          : 'Llevas el ${(goalProgress * 100).round()}% de tu objetivo del año. ¡Sigue así!',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Estadísticas Rápidas
            Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    context,
                    title: 'Total',
                    value: '${libraryProvider.totalBooks}',
                    icon: Icons.collections_bookmark_rounded,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatBox(
                    context,
                    title: 'Leídos',
                    value: '${libraryProvider.countRead}',
                    icon: Icons.check_circle_rounded,
                    color: AppTheme.accentSage,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatBox(
                    context,
                    title: 'Páginas',
                    value: _formatPages(libraryProvider.totalPagesRead),
                    icon: Icons.auto_stories_rounded,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatBox(
                    context,
                    title: 'Prom. ★',
                    value: avgUserRating == 0 ? '—' : avgUserRating.toStringAsFixed(1),
                    icon: Icons.star_rounded,
                    color: AppTheme.starGold,
                  ),
                ),
              ],
            ),

            // Puntuación media dada por el lector (visual)
            if (avgUserRating > 0) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceDarkSecondary : AppTheme.surfaceLightSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.reviews_rounded, color: AppTheme.primary),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Tu puntuación media al calificar',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    RatingStars(rating: avgUserRating, size: 16, showScoreText: true),
                  ],
                ),
              ),
            ],

            // Actualmente leyendo (Estantería visible en el perfil)
            if (currentlyReading.isNotEmpty) ...[
              const SizedBox(height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_stories_rounded, size: 18, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Text('Leyendo ahora', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
                    ],
                  ),
                  Text(
                    '${currentlyReading.length} libros',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                children: currentlyReading.take(3).map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => BookDetailScreen(book: item.book)),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Row(
                        children: [
                          BookCoverImage(
                            imageUrl: item.book.thumbnail,
                            width: 50,
                            height: 75,
                            borderRadius: 6,
                            title: item.book.title,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.book.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.book.authorDisplay,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ReadingProgressBar(
                                  progress: item.progressPercentage,
                                  currentPage: item.currentPage ?? 0,
                                  totalPages: item.book.effectivePageCount,
                                  height: 5,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 20),

            // Accesos rápidos: Mi año literario + Estanterías personalizadas
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const YearInReviewScreen()));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
                          SizedBox(width: 8),
                          Expanded(child: Text('Mi año literario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                          Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ShelvesScreen()));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.surfaceDarkSecondary : AppTheme.surfaceLightSecondary,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.library_books_rounded, color: AppTheme.primary, size: 22),
                          SizedBox(width: 8),
                          Expanded(child: Text('Mis estanterías', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.insights_rounded, color: AppTheme.primary),
                title: const Text('Estadísticas de lectura',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                subtitle: const Text('Páginas por mes, géneros, autores y ritmo',
                    style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReadingStatsScreen()),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.download_rounded, color: AppTheme.primary),
                title: const Text('Importar desde Goodreads',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                subtitle: const Text('Trae tus libros, puntuaciones, reseñas y estanterías',
                    style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GoodreadsImportScreen()),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const ExportLibraryTile(),

            const SizedBox(height: 24),

            // Géneros Favoritos
            Text('Géneros Favoritos', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: genres.map((g) {
                return Chip(
                  label: Text(g),
                  backgroundColor: isDark ? AppTheme.surfaceDarkSecondary : AppTheme.surfaceLightSecondary,
                  side: BorderSide(
                    color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                  ),
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Mis Libros en la biblioteca (Miniatura)
            if (libraryProvider.libraryBooks.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Mis Libros Recientes', style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    '${libraryProvider.totalBooks} guardados',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 130,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: libraryProvider.libraryBooks.length,
                  itemBuilder: (context, index) {
                    final item = libraryProvider.libraryBooks[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => BookDetailScreen(book: item.book)),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        child: BookCoverImage(
                          imageUrl: item.book.thumbnail,
                          width: 85,
                          height: 130,
                          borderRadius: 8,
                          title: item.book.title,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _formatPages(int pages) {
    if (pages >= 1000) {
      return '${(pages / 1000).toStringAsFixed(pages >= 10000 ? 0 : 1)}K';
    }
    return '$pages';
  }

  Widget _buildStatBox(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDarkSecondary : AppTheme.surfaceLightSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
