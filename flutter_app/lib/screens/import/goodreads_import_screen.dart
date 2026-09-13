import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/discover_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/social_provider.dart';

/// Resultado de la importación devuelto por el backend.
class ImportSummary {
  final int totalRows;
  final int imported;
  final int updated;
  final int skipped;
  final int reviews;
  final int shelvesCreated;
  final List<String> errors;

  ImportSummary({
    required this.totalRows,
    required this.imported,
    required this.updated,
    required this.skipped,
    required this.reviews,
    required this.shelvesCreated,
    required this.errors,
  });

  factory ImportSummary.fromJson(Map<String, dynamic> json) {
    int n(String key) => (json[key] as num?)?.toInt() ?? 0;
    return ImportSummary(
      totalRows: n('totalRows'),
      imported: n('imported'),
      updated: n('updated'),
      skipped: n('skipped'),
      reviews: n('reviews'),
      shelvesCreated: n('shelvesCreated'),
      errors: (json['errors'] as List? ?? [])
          .map((e) => 'Fila ${e['row']}: «${e['title']}»')
          .toList(),
    );
  }
}

/// Importa la biblioteca exportada desde Goodreads (archivo .csv).
class GoodreadsImportScreen extends StatefulWidget {
  const GoodreadsImportScreen({super.key});

  @override
  State<GoodreadsImportScreen> createState() => _GoodreadsImportScreenState();
}

class _GoodreadsImportScreenState extends State<GoodreadsImportScreen> {
  static final Uri _exportUrl = Uri.parse('https://www.goodreads.com/review/import');

  bool _importing = false;
  String? _fileName;
  String? _error;
  ImportSummary? _summary;

  Future<void> _pickAndImport() async {
    const csvType = XTypeGroup(
      label: 'CSV',
      extensions: ['csv'],
      mimeTypes: ['text/csv', 'text/comma-separated-values', 'application/vnd.ms-excel'],
      uniformTypeIdentifiers: ['public.comma-separated-values-text'],
      webWildCards: ['.csv'],
    );

    final XFile? file;
    try {
      file = await openFile(acceptedTypeGroups: const [csvType]);
    } catch (e) {
      setState(() => _error = 'No se pudo abrir el selector de archivos.');
      return;
    }
    if (file == null) return;

    setState(() {
      _importing = true;
      _fileName = file!.name;
      _error = null;
      _summary = null;
    });

    final bytes = await file.readAsBytes();
    final response = await ApiClient().uploadFile(
      '/import/goodreads',
      fieldName: 'file',
      bytes: bytes,
      filename: file.name.isNotEmpty ? file.name : 'goodreads_library_export.csv',
      contentType: 'text/csv',
      // Una biblioteca de miles de libros puede tardar un rato
      timeout: const Duration(minutes: 5),
    );
    if (!mounted) return;

    if (response.success && response.data is Map<String, dynamic>) {
      final summary = ImportSummary.fromJson(response.data as Map<String, dynamic>);
      setState(() {
        _importing = false;
        _summary = summary;
      });
      // Refrescamos lo que depende de la biblioteca
      Provider.of<LibraryProvider>(context, listen: false).fetchLibrary();
      Provider.of<SocialProvider>(context, listen: false).fetchShelves();
      Provider.of<DiscoverProvider>(context, listen: false).loadForYou(force: true);
    } else {
      setState(() {
        _importing = false;
        _error = response.errorMessage ?? 'No se pudo importar el archivo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Importar de Goodreads')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            'Trae tu biblioteca, puntuaciones, reseñas y estanterías de Goodreads.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 20),

          _Step(
            number: 1,
            title: 'Exporta tu biblioteca en Goodreads',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Entra en Goodreads (mejor desde un ordenador), pulsa «Export Library» '
                  'y espera a que aparezca el enlace de descarga. Puede tardar unos minutos.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Abrir Goodreads'),
                  onPressed: () => launchUrl(_exportUrl, mode: LaunchMode.externalApplication),
                ),
              ],
            ),
          ),
          const _Step(
            number: 2,
            title: 'Descarga el archivo',
            child: Text(
              'Se llama goodreads_library_export.csv. Guárdalo donde puedas encontrarlo.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
          _Step(
            number: 3,
            title: 'Súbelo aquí',
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _importing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.upload_file_rounded),
                label: Text(_importing ? 'Importando…' : 'Elegir archivo .csv'),
                onPressed: _importing ? null : _pickAndImport,
              ),
            ),
          ),

          if (_importing && _fileName != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Importando $_fileName. Si tienes muchos libros puede tardar un poco; no cierres esta pantalla.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13))),
                ],
              ),
            ),
          ],

          if (_summary != null) ...[
            const SizedBox(height: 20),
            _SummaryCard(summary: _summary!, onDone: () => Navigator.pop(context)),
          ],

          const SizedBox(height: 24),
          Text(
            'Qué se importa: estado (leído, leyendo, quiero leer), puntuación, fecha de lectura, '
            'reseña, notas privadas, favoritos y estanterías personalizadas. Puedes volver a importar '
            'más adelante: los libros que ya tengas se actualizan, no se duplican.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String title;
  final Widget child;

  const _Step({required this.number, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppTheme.primary,
            child: Text('$number',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 6),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final ImportSummary summary;
  final VoidCallback onDone;

  const _SummaryCard({required this.summary, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5))),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDarkSecondary : AppTheme.primaryLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppTheme.accentSage),
              SizedBox(width: 8),
              Text('Importación terminada', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          line(Icons.library_add_rounded, '${summary.imported} libros nuevos en tu biblioteca'),
          if (summary.updated > 0) line(Icons.sync_rounded, '${summary.updated} libros que ya tenías, actualizados'),
          if (summary.reviews > 0) line(Icons.rate_review_rounded, '${summary.reviews} reseñas'),
          if (summary.shelvesCreated > 0)
            line(Icons.shelves, '${summary.shelvesCreated} estanterías nuevas'),
          if (summary.skipped > 0) line(Icons.remove_circle_outline_rounded, '${summary.skipped} filas omitidas'),
          if (summary.errors.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('No se pudieron importar:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            ...summary.errors.map((e) => Text('• $e', style: const TextStyle(fontSize: 12))),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: onDone, child: const Text('Listo')),
          ),
        ],
      ),
    );
  }
}
