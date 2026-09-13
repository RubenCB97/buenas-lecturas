import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/book_model.dart';
import '../../widgets/book_card.dart';
import '../book_detail/book_detail_screen.dart';

/// Reconocer un libro con una foto de su portada (lo analiza el servidor).
class CoverRecognition {
  CoverRecognition._();

  static bool? _enabled;

  /// Si el servidor tiene configurado el reconocimiento de portadas.
  static Future<bool> isEnabled() async {
    if (_enabled != null) return _enabled!;
    final r = await ApiClient().get('/search/cover/enabled', requiresAuth: false);
    final enabled = r.success && r.data is Map && r.data['enabled'] == true;
    // Solo recordamos la respuesta si llegó: sin red lo volveremos a preguntar
    if (r.success) _enabled = enabled;
    return enabled;
  }

  /// Pide una foto (cámara o galería), la analiza y muestra los resultados.
  static Future<void> start(BuildContext context, {ImageSource source = ImageSource.camera}) async {
    final XFile? photo;
    try {
      photo = await ImagePicker().pickImage(
        source: source,
        // Tamaño suficiente para leer la portada sin subir fotos enormes
        maxWidth: 1568,
        maxHeight: 1568,
        imageQuality: 85,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir la cámara')),
        );
      }
      return;
    }
    if (photo == null || !context.mounted) return;

    final bytes = await photo.readAsBytes();
    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CoverResultsSheet(
        bytes: bytes,
        filename: photo!.name.isEmpty ? 'portada.jpg' : photo.name,
        contentType: photo.mimeType,
      ),
    );
  }
}

class _CoverResultsSheet extends StatefulWidget {
  final List<int> bytes;
  final String filename;
  final String? contentType;

  const _CoverResultsSheet({required this.bytes, required this.filename, this.contentType});

  @override
  State<_CoverResultsSheet> createState() => _CoverResultsSheetState();
}

class _CoverResultsSheetState extends State<_CoverResultsSheet> {
  bool _loading = true;
  String? _error;
  String? _detected;
  List<BookModel> _results = const [];

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    final r = await ApiClient().uploadFile(
      '/search/cover',
      fieldName: 'image',
      bytes: widget.bytes,
      filename: widget.filename,
      contentType: widget.contentType,
      timeout: const Duration(seconds: 90),
    );
    if (!mounted) return;

    if (!r.success || r.data is! Map) {
      setState(() {
        _loading = false;
        _error = r.statusCode == null
            ? 'No se pudo enviar la foto. Revisa tu conexión.'
            : (r.errorMessage ?? 'No se pudo analizar la foto');
      });
      return;
    }

    final data = r.data as Map;
    final reading = data['reading'] is Map ? data['reading'] as Map : const {};
    final results = data['results'] is List
        ? (data['results'] as List).whereType<Map<String, dynamic>>().map(BookModel.fromJson).toList()
        : <BookModel>[];

    String? detected;
    if (reading['title'] is String) {
      final authors = reading['authors'] is List ? (reading['authors'] as List).join(', ') : '';
      detected = authors.isEmpty ? '«${reading['title']}»' : '«${reading['title']}» de $authors';
    }

    setState(() {
      _loading = false;
      _detected = detected;
      _results = results;
      if (reading['isBook'] == false) {
        _error = 'No parece la portada de un libro. Prueba con una foto más de cerca y con buena luz.';
      } else if (results.isEmpty) {
        _error = detected == null
            ? 'No hemos podido leer el título. Prueba con otra foto.'
            : 'Hemos leído $detected, pero no aparece en el catálogo.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: _results.isEmpty ? 0.45 : 0.8,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Text('Reconocer portada', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 17)),
          ),
          if (_detected != null && _results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Hemos leído $_detected. ¿Es alguno de estos?',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ),
          Expanded(
            child: _loading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppTheme.primary),
                        SizedBox(height: 14),
                        Text('Leyendo la portada…'),
                      ],
                    ),
                  )
                : _results.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.image_search_rounded, size: 48, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text(_error ?? '', textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: controller,
                        padding: const EdgeInsets.all(16),
                        itemCount: _results.length,
                        itemBuilder: (context, i) {
                          final book = _results[i];
                          return BookCard(
                            book: book,
                            style: BookCardStyle.largeFeed,
                            onTap: () {
                              final navigator = Navigator.of(context);
                              navigator.pop();
                              navigator.push(MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)));
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
