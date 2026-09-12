import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../core/theme/app_theme.dart';

class RatingStars extends StatelessWidget {
  final double rating;
  final double size;
  final bool isInteractive;
  final ValueChanged<double>? onRatingUpdate;
  final bool showScoreText;
  final bool allowHalf;

  const RatingStars({
    super.key,
    required this.rating,
    this.size = 18,
    this.isInteractive = false,
    this.onRatingUpdate,
    this.showScoreText = false,
    this.allowHalf = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        RatingBar.builder(
          initialRating: rating.clamp(0.0, 5.0),
          minRating: allowHalf ? 0.5 : 1.0,
          direction: Axis.horizontal,
          allowHalfRating: allowHalf,
          itemCount: 5,
          itemSize: size,
          ignoreGestures: !isInteractive,
          unratedColor: AppTheme.starGold.withValues(alpha: 0.25),
          itemPadding: const EdgeInsets.symmetric(horizontal: 1.0),
          itemBuilder: (context, _) => const Icon(
            Icons.star_rounded,
            color: AppTheme.starGold,
          ),
          onRatingUpdate: (val) {
            if (onRatingUpdate != null) onRatingUpdate!(val);
          },
        ),
        if (showScoreText) ...[
          const SizedBox(width: 6),
          Text(
            rating.toStringAsFixed(rating == rating.roundToDouble() ? 0 : 1),
            style: TextStyle(
              fontSize: size * 0.85,
              fontWeight: FontWeight.bold,
              color: AppTheme.starGold,
            ),
          ),
        ],
      ],
    );
  }
}
