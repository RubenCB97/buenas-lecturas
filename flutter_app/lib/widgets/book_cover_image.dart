import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme/app_theme.dart';

class BookCoverImage extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final double borderRadius;
  final String? title;
  final bool hasShadow;

  const BookCoverImage({
    super.key,
    required this.imageUrl,
    this.width = 80,
    this.height = 120,
    this.borderRadius = 8,
    this.title,
    this.hasShadow = true,
  });

  bool get _hasUrl => imageUrl != null && imageUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                  blurRadius: 10,
                  offset: const Offset(2, 6),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: !_hasUrl
            ? _buildPlaceholderFallback(context)
            // En Flutter Web, CachedNetworkImage es poco fiable (usa XHR +
            // IndexedDB y pierde las imágenes al navegar). Ahí usamos
            // Image.network, que delega en la caché nativa del navegador.
            : kIsWeb
                ? _buildWebImage(context, isDark)
                : _buildNativeImage(context, isDark),
      ),
    );
  }

  Widget _buildWebImage(BuildContext context, bool isDark) {
    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      width: width,
      height: height,
      // Conserva el fotograma anterior mientras recarga: evita parpadeos
      // y huecos en blanco al volver a una pantalla.
      gaplessPlayback: true,
      // Clave estable para que el framework reutilice el mismo elemento
      // cuando la lista se reconstruye tras navegar.
      key: ValueKey('cover_${imageUrl!}'),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _buildShimmer(isDark);
      },
      errorBuilder: (context, error, stack) => _buildPlaceholderFallback(context),
    );
  }

  Widget _buildNativeImage(BuildContext context, bool isDark) {
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: BoxFit.cover,
      width: width,
      height: height,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (context, url) => _buildShimmer(isDark),
      errorWidget: (context, url, error) => _buildPlaceholderFallback(context),
    );
  }

  Widget _buildShimmer(bool isDark) {
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF272A20) : const Color(0xFFDBE1CB),
      highlightColor: isDark ? const Color(0xFF343827) : const Color(0xFFEDF0E1),
      child: Container(color: Colors.white),
    );
  }

  Widget _buildPlaceholderFallback(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: AppTheme.primaryLight,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.menu_book_rounded,
            color: AppTheme.primaryDark,
            size: 28,
          ),
          if (title != null && title!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                title!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryLight,
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }
}
