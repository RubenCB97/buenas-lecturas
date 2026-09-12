import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/challenge_model.dart';
import '../../providers/challenges_provider.dart';
import '../../widgets/book_cover_image.dart';
import '../../widgets/rating_stars.dart';

/// Hoja modal para puntuar (★★★★★) y comentar el libro de una celda del reto.
class CellReviewSheet extends StatefulWidget {
  final int challengeId;
  final ChallengeEntryModel entry;
  final ChallengeCategoryModel category;

  const CellReviewSheet({
    super.key,
    required this.challengeId,
    required this.entry,
    required this.category,
  });

  @override
  State<CellReviewSheet> createState() => _CellReviewSheetState();
}

class _CellReviewSheetState extends State<CellReviewSheet> {
  late TextEditingController _comment;
  late double _rating;
  bool _saving = false;

  static const int _maxCommentLength = 140;

  @override
  void initState() {
    super.initState();
    _rating = widget.entry.rating ?? 0.0;
    _comment = TextEditingController(text: widget.entry.comment ?? '');
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final provider = Provider.of<ChallengesProvider>(context, listen: false);
    await provider.reviewCell(
      widget.challengeId,
      widget.entry.id,
      rating: _rating,
      comment: _comment.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: AppTheme.accentSage, content: Text('Reseña guardada ⭐')),
    );
  }

  Future<void> _clear() async {
    setState(() => _saving = true);
    final provider = Provider.of<ChallengesProvider>(context, listen: false);
    await provider.reviewCell(widget.challengeId, widget.entry.id, rating: 0.0, comment: '');
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.entry.book;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(widget.category.icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.category.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 8),
          if (book != null)
            Row(
              children: [
                BookCoverImage(
                  imageUrl: book.thumbnail,
                  width: 46,
                  height: 68,
                  borderRadius: 5,
                  title: book.title,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      const SizedBox(height: 2),
                      Text(book.authorDisplay,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 18),
          Center(
            child: RatingStars(
              rating: _rating,
              size: 34,
              isInteractive: true,
              allowHalf: true,
              onRatingUpdate: (v) => setState(() => _rating = v),
            ),
          ),
          if (_rating > 0) ...[
            const SizedBox(height: 4),
            Center(
              child: Text(
                _rating.toStringAsFixed(_rating == _rating.roundToDouble() ? 0 : 1) + ' de 5',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.starGold),
              ),
            ),
          ],
          if (_rating > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.close_rounded, size: 14),
                  label: const Text('Quitar puntuación', style: TextStyle(fontSize: 12)),
                  onPressed: () => setState(() => _rating = 0.0),
                ),
              ),
            ),
          const SizedBox(height: 14),
          TextField(
            controller: _comment,
            minLines: 2,
            maxLines: 4,
            maxLength: _maxCommentLength,
            decoration: InputDecoration(
              hintText: 'Comentario breve (máx. $_maxCommentLength caracteres)…',
              filled: true,
              fillColor: isDark ? AppTheme.surfaceDarkSecondary : AppTheme.surfaceLightSecondary,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if ((widget.entry.rating ?? 0) > 0 || (widget.entry.comment?.isNotEmpty ?? false))
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Vaciar reseña'),
                    onPressed: _saving ? null : _clear,
                  ),
                ),
              if ((widget.entry.rating ?? 0) > 0 || (widget.entry.comment?.isNotEmpty ?? false))
                const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_rounded),
                  label: Text(_saving ? 'Guardando…' : 'Guardar'),
                  onPressed: _saving ? null : _save,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
