import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class ReadingProgressBar extends StatelessWidget {
  final double progress; // 0.0 a 1.0
  final int? currentPage;
  final int? totalPages;
  final bool showLabel;
  final double height;

  const ReadingProgressBar({
    super.key,
    required this.progress,
    this.currentPage,
    this.totalPages,
    this.showLabel = true,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (progress * 100).round();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                currentPage != null && totalPages != null
                    ? 'Pág. $currentPage de $totalPages'
                    : '$percentage% completado',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                ),
              ),
              Text(
                '$percentage%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: height,
            backgroundColor: isDark ? const Color(0xFF2C2621) : const Color(0xFFE8DFD5),
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
          ),
        ),
      ],
    );
  }
}
