import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/book_model.dart';
import '../../models/user_book_model.dart';
import '../../providers/library_provider.dart';
import '../../widgets/reading_progress_bar.dart';

/// Hoja modal para actualizar el progreso de lectura de un libro,
/// al estilo Goodreads (página actual + porcentaje).
class UpdateProgressSheet extends StatefulWidget {
  final UserBookModel userBook;
  final BookModel book;

  const UpdateProgressSheet({
    super.key,
    required this.userBook,
    required this.book,
  });

  @override
  State<UpdateProgressSheet> createState() => _UpdateProgressSheetState();
}

class _UpdateProgressSheetState extends State<UpdateProgressSheet> {
  late TextEditingController _pageController;
  late int _totalPages;
  late int _currentPage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _totalPages = widget.book.effectivePageCount;
    _currentPage = widget.userBook.currentPage ?? 0;
    _pageController = TextEditingController(text: _currentPage.toString());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  double get _progress {
    if (_totalPages <= 0) return 0;
    return (_currentPage / _totalPages).clamp(0.0, 1.0);
  }

  Future<void> _save() async {
    setState(() => _isSubmitting = true);
    final libraryProvider = Provider.of<LibraryProvider>(context, listen: false);
    final ok = await libraryProvider.updateProgress(widget.userBook.id, _currentPage);
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.accentSage,
          content: Text(
            _currentPage >= _totalPages
                ? '¡Enhorabuena! Has terminado el libro 🎉'
                : 'Progreso guardado: página $_currentPage de $_totalPages',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el progreso')),
      );
    }
  }

  void _updateFromText(String value) {
    final n = int.tryParse(value.trim()) ?? 0;
    setState(() {
      _currentPage = n.clamp(0, _totalPages);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Actualizar progreso',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.book.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Text(
            widget.book.authorDisplay,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 20),

          // Progreso circular grande
          Center(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 130,
                      height: 130,
                      child: CircularProgressIndicator(
                        value: _progress,
                        strokeWidth: 10,
                        backgroundColor: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                        valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '${(_progress * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primary,
                          ),
                        ),
                        Text(
                          '$_currentPage / $_totalPages',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Deslizador para ajustar rápido
          Row(
            children: [
              const Icon(Icons.menu_book_rounded, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Text(
                'Ajustar página',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const Spacer(),
              Text(
                'Total: $_totalPages',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: _currentPage.toDouble().clamp(0.0, _totalPages.toDouble()),
            min: 0,
            max: _totalPages.toDouble(),
            divisions: _totalPages > 0 ? _totalPages : 1,
            activeColor: AppTheme.primary,
            label: _currentPage.toString(),
            onChanged: (v) {
              setState(() {
                _currentPage = v.round();
                _pageController.text = _currentPage.toString();
              });
            },
          ),

          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pageController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Página actual',
                    filled: true,
                    fillColor: isDark ? AppTheme.surfaceDarkSecondary : AppTheme.surfaceLightSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: _updateFromText,
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.done_all_rounded),
                label: const Text('Terminado'),
                onPressed: () {
                  setState(() {
                    _currentPage = _totalPages;
                    _pageController.text = _currentPage.toString();
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 12),
          ReadingProgressBar(
            progress: _progress,
            currentPage: _currentPage,
            totalPages: _totalPages,
            height: 6,
            showLabel: false,
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _save,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_isSubmitting ? 'Guardando…' : 'Guardar progreso'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
