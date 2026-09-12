import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/user_book_model.dart';

class StatusBadge extends StatelessWidget {
  final ReadingStatus status;
  final bool isSmall;

  const StatusBadge({
    super.key,
    required this.status,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case ReadingStatus.reading:
        bgColor = AppTheme.primary.withValues(alpha: 0.15);
        textColor = AppTheme.primary;
        icon = Icons.auto_stories_rounded;
        break;
      case ReadingStatus.read:
        bgColor = AppTheme.accentSage.withValues(alpha: 0.15);
        textColor = AppTheme.accentSage;
        icon = Icons.check_circle_rounded;
        break;
      case ReadingStatus.wantToRead:
        bgColor = const Color(0xFF6B7280).withValues(alpha: 0.15);
        textColor = const Color(0xFF4B5563);
        icon = Icons.bookmark_added_rounded;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 8 : 12,
        vertical: isSmall ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isSmall ? 12 : 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              fontSize: isSmall ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
