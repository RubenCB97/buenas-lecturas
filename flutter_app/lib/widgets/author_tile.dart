import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/author_model.dart';
import '../screens/author/author_screen.dart';

/// Fila de resultado de búsqueda de autor.
class AuthorTile extends StatelessWidget {
  final AuthorModel author;
  final VoidCallback? onTap;

  const AuthorTile({super.key, required this.author, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap ??
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AuthorScreen(authorName: author.name)),
              );
            },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.primaryLight,
                backgroundImage: author.photoUrl != null ? NetworkImage(author.photoUrl!) : null,
                onBackgroundImageError: author.photoUrl != null ? (_, __) {} : null,
                child: author.photoUrl == null
                    ? Text(
                        author.name.isNotEmpty ? author.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryDark,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                    if (author.lifespan != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        author.lifespan!,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                        ),
                      ),
                    ],
                    if (author.topWork != null && author.topWork!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.auto_stories_rounded, size: 12, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              author.topWork!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (author.workCount != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${author.workCount} obras publicadas',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
