import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/author_model.dart';
import '../../providers/authors_provider.dart';
import '../../widgets/book_card.dart';
import '../book_detail/book_detail_screen.dart';

class AuthorScreen extends StatefulWidget {
  final String authorName;

  const AuthorScreen({super.key, required this.authorName});

  @override
  State<AuthorScreen> createState() => _AuthorScreenState();
}

class _AuthorScreenState extends State<AuthorScreen> {
  bool _bioExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthorsProvider>(context, listen: false).loadAuthor(widget.authorName);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AuthorsProvider>(context);
    final author = provider.current;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(widget.authorName, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: provider.isLoadingDetail
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : author == null
              ? _buildEmpty()
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader(author, isDark)),
                    if (author.bio != null && author.bio!.trim().isNotEmpty)
                      SliverToBoxAdapter(child: _buildBio(author, isDark)),
                    if (author.subjects.isNotEmpty)
                      SliverToBoxAdapter(child: _buildSubjects(author, isDark)),
                    SliverToBoxAdapter(child: _buildBooksHeader(author)),
                    if (author.books.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(30),
                          child: Center(
                            child: Text('No se han encontrado libros de este autor',
                                style: TextStyle(color: Colors.grey)),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final book = author.books[index];
                              final tag = BookCard.heroTagFor('author', book);
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
                            childCount: author.books.length,
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ),
    );
  }

  Widget _buildHeader(AuthorModel author, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppTheme.surfaceDarkSecondary, AppTheme.bgDark]
              : [AppTheme.primaryLight, AppTheme.bgLight],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 52,
            backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
            backgroundImage: author.photoUrl != null ? NetworkImage(author.photoUrl!) : null,
            onBackgroundImageError: author.photoUrl != null ? (_, __) {} : null,
            child: author.photoUrl == null
                ? Text(
                    author.name.isNotEmpty ? author.name[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  )
                : null,
          ),
          const SizedBox(height: 14),
          Text(
            author.name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 23, height: 1.15),
          ),
          if (author.lifespan != null) ...[
            const SizedBox(height: 4),
            Text(
              author.lifespan!,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _stat('${author.booksCount}', 'Libros'),
              _divider(isDark),
              _stat(
                author.averageRating != null ? author.averageRating!.toStringAsFixed(1) : '—',
                'Nota media',
              ),
              if (author.workCount != null) ...[
                _divider(isDark),
                _stat('${author.workCount}', 'Obras'),
              ],
            ],
          ),
          if (author.topWork != null && author.topWork!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, size: 14, color: AppTheme.starGold),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Obra más conocida: ${author.topWork}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) => Container(
        width: 1,
        height: 30,
        color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
      );

  Widget _buildBio(AuthorModel author, bool isDark) {
    final bio = author.bio!.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Biografía', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            bio,
            maxLines: _bioExpanded ? null : 5,
            overflow: _bioExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              height: 1.55,
              color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
            ),
          ),
          if (bio.length > 220)
            GestureDetector(
              onTap: () => setState(() => _bioExpanded = !_bioExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _bioExpanded ? 'Mostrar menos' : 'Leer biografía completa',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubjects(AuthorModel author, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Temas recurrentes', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: author.subjects
                .map((s) => Chip(
                      label: Text(s),
                      backgroundColor: isDark ? AppTheme.surfaceDarkSecondary : AppTheme.surfaceLightSecondary,
                      side: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                      labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBooksHeader(AuthorModel author) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Libros de ${author.name.split(' ').first}',
              style: Theme.of(context).textTheme.titleLarge),
          Text('${author.books.length}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_search_rounded, size: 60, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Autor no encontrado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              'No hemos podido cargar la ficha de "${widget.authorName}".',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
