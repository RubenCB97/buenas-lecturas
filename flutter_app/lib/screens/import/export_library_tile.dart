import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/file_saver.dart';

/// Opción de perfil para descargar la biblioteca en CSV (formato Goodreads).
class ExportLibraryTile extends StatefulWidget {
  const ExportLibraryTile({super.key});

  @override
  State<ExportLibraryTile> createState() => _ExportLibraryTileState();
}

class _ExportLibraryTileState extends State<ExportLibraryTile> {
  bool _exporting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);

    final response = await ApiClient().download('/import/export/goodreads');
    if (!mounted) return;

    if (!response.success || response.data == null) {
      setState(() => _exporting = false);
      messenger.showSnackBar(SnackBar(
        backgroundColor: Colors.redAccent,
        content: Text(response.errorMessage ?? 'No se pudo exportar la biblioteca'),
      ));
      return;
    }

    final date = DateTime.now().toIso8601String().substring(0, 10);
    try {
      await saveFile(
        bytes: response.data!,
        fileName: 'buenaslecturas_biblioteca_$date.csv',
        mimeType: 'text/csv',
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('No se pudo guardar el archivo')));
    }
    if (mounted) setState(() => _exporting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: _exporting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
              )
            : const Icon(Icons.upload_rounded, color: AppTheme.primary),
        title: const Text('Exportar mi biblioteca',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
        subtitle: const Text('Copia de seguridad en CSV, compatible con Goodreads',
            style: TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: _exporting ? null : _export,
      ),
    );
  }
}
