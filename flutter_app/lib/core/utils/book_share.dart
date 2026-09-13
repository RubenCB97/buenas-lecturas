import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/book_model.dart';
import '../theme/app_theme.dart';
import 'deep_link.dart';

/// Compartir un libro: menú nativo del sistema o copia al portapapeles.
class BookShare {
  BookShare._();

  /// Web pública de la app.
  static const String appUrl = DeepLink.appUrl;

  /// Enlace que abre la ficha del libro dentro de BuenasLecturas.
  static String? appLink(BookModel book) {
    final id = book.googleId?.trim();
    if (id == null || id.isEmpty) return null;
    return RegExp(r'^[\w-]{1,64}$').hasMatch(id) ? DeepLink.bookUrl(id) : null;
  }

  /// Ficha del libro en el catálogo del que procede (Google Books / Open Library).
  static String? publicLink(BookModel book) {
    final id = book.googleId?.trim();
    if (id != null && id.isNotEmpty) {
      // Las obras de Open Library tienen ids tipo "OL12345W"
      if (RegExp(r'^OL\d+W$').hasMatch(id)) {
        return 'https://openlibrary.org/works/$id';
      }
      if (!id.startsWith('custom_') && !id.startsWith('ol_') && !id.startsWith('gr_')) {
        return 'https://books.google.com/books?id=${Uri.encodeComponent(id)}';
      }
    }
    final isbn = book.isbn?.trim();
    if (isbn != null && isbn.isNotEmpty) {
      return 'https://openlibrary.org/isbn/${Uri.encodeComponent(isbn)}';
    }
    return null;
  }

  static String buildText(BookModel book) {
    final link = appLink(book);
    final buffer = StringBuffer()
      ..writeln('📖 «${book.title}»')
      ..writeln('de ${book.authorDisplay}')
      ..writeln();
    if (link != null) {
      buffer.write('Míralo en BuenasLecturas: $link');
    } else {
      buffer.write('Descúbrelo en BuenasLecturas: $appUrl');
    }
    return buffer.toString();
  }

  /// Muestra las opciones de compartir.
  static Future<void> showOptions(BuildContext context, BookModel book) {
    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.ios_share_rounded, color: AppTheme.primary),
                title: const Text('Enviar a…'),
                subtitle: const Text('WhatsApp, correo, mensajes y otras apps'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _shareNative(context, book);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: AppTheme.primary),
                title: const Text('Copiar al portapapeles'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  copy(context, book);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _shareNative(BuildContext context, BookModel book) async {
    // Origen del popover, obligatorio en iPad
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;

    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text: buildText(book),
          subject: book.title,
          title: book.title,
          sharePositionOrigin: origin,
          // En web, si el navegador no soporta compartir, share_plus abriría
          // un correo nuevo. Preferimos copiar al portapapeles.
          mailToFallbackEnabled: false,
        ),
      );
      if (result.status == ShareResultStatus.unavailable && context.mounted) {
        await copy(context, book, reason: 'Este navegador no permite compartir.');
      }
    } catch (_) {
      if (context.mounted) {
        await copy(context, book, reason: 'No se pudo abrir el menú de compartir.');
      }
    }
  }

  /// Copia el texto del libro al portapapeles y lo confirma.
  static Future<void> copy(BuildContext context, BookModel book, {String? reason}) async {
    await Clipboard.setData(ClipboardData(text: buildText(book)));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.accentSage,
        content: Text(reason == null ? 'Copiado al portapapeles' : '$reason Lo hemos copiado al portapapeles.'),
      ),
    );
  }
}
