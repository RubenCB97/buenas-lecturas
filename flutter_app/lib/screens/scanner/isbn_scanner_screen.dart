import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/isbn.dart';
import '../../models/book_model.dart';
import '../book_detail/book_detail_screen.dart';

/// Escanea el código de barras (ISBN) de un libro y abre su ficha.
class IsbnScannerScreen extends StatefulWidget {
  const IsbnScannerScreen({super.key});

  @override
  State<IsbnScannerScreen> createState() => _IsbnScannerScreenState();
}

class _IsbnScannerScreenState extends State<IsbnScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    // Los ISBN van en EAN-13; UPC-A lo usan algunas ediciones de EE. UU.
    formats: const [BarcodeFormat.ean13, BarcodeFormat.upcA],
    detectionSpeed: DetectionSpeed.normal,
  );

  bool _busy = false;
  String? _hint;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;

      // Un UPC-A de 12 dígitos es un EAN-13 con un 0 delante
      final candidate = raw.length == 12 ? '0$raw' : raw;
      final isbn = Isbn.normalize(candidate);
      if (isbn != null) {
        _lookup(isbn);
        return;
      }
    }
    // Se leyó un código, pero no es de un libro (p. ej. el de precio)
    if (_hint == null && mounted) {
      setState(() => _hint = 'Ese código no es un ISBN. Enfoca el código de barras que empieza por 978 o 979.');
    }
  }

  Future<void> _lookup(String isbn) async {
    setState(() {
      _busy = true;
      _hint = null;
    });
    HapticFeedback.mediumImpact();
    await _controller.stop();

    final response = await ApiClient().get('/search/isbn/$isbn', requiresAuth: false);
    if (!mounted) return;

    if (response.success && response.data is Map<String, dynamic>) {
      final book = BookModel.fromJson(response.data as Map<String, dynamic>);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)),
      );
      return;
    }

    final notFound = response.statusCode == 404;
    await _showNotFound(
      isbn,
      notFound
          ? 'No hemos encontrado ningún libro con el ISBN $isbn.'
          : 'No se pudo buscar el libro. Revisa tu conexión e inténtalo de nuevo.',
    );
  }

  Future<void> _showNotFound(String isbn, String message) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Escanear otro'),
                  onPressed: () => Navigator.pop(sheetContext),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _enterManually();
                },
                child: const Text('Escribir el ISBN a mano'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    await _controller.start();
  }

  Future<void> _enterManually() async {
    final controller = TextEditingController();
    final isbn = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? error;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Introducir ISBN'),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '978…',
                helperText: 'Lo encontrarás en la contraportada o en la página de créditos',
                helperMaxLines: 2,
                errorText: error,
              ),
              onSubmitted: (_) {},
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () {
                  final value = Isbn.normalize(controller.text);
                  if (value == null) {
                    setDialogState(() => error = 'No es un ISBN válido');
                    return;
                  }
                  Navigator.pop(dialogContext, value);
                },
                child: const Text('Buscar'),
              ),
            ],
          ),
        );
      },
    );
    if (isbn != null && mounted) await _lookup(isbn);
  }

  Widget _buildError(BuildContext context, MobileScannerException error) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(denied ? Icons.no_photography_rounded : Icons.videocam_off_rounded, color: Colors.white70, size: 56),
          const SizedBox(height: 16),
          Text(
            denied
                ? 'Necesitamos permiso para usar la cámara. Actívalo en los ajustes del dispositivo.'
                : 'No hay ninguna cámara disponible en este dispositivo.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.keyboard_rounded),
            label: const Text('Escribir el ISBN a mano'),
            onPressed: _enterManually,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Escanear libro', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'Linterna',
            icon: const Icon(Icons.flashlight_on_rounded),
            onPressed: () async {
              try {
                await _controller.toggleTorch();
              } catch (_) {
                // Sin linterna (web, escritorio o cámara frontal)
              }
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: _buildError,
          ),

          // Marco guía para colocar el código de barras
          IgnorePointer(
            child: Center(
              child: Container(
                width: 280,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primary, width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          // Instrucciones y acción manual
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _busy
                          ? 'Buscando el libro…'
                          : (_hint ?? 'Enfoca el código de barras de la contraportada'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_busy)
                    const CircularProgressIndicator(color: AppTheme.primary)
                  else
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      icon: const Icon(Icons.keyboard_rounded),
                      label: const Text('Escribir el ISBN a mano'),
                      onPressed: _enterManually,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
