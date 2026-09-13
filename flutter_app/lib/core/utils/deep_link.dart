import 'url_cleaner.dart';

/// Enlaces directos a libros: `https://<app>/libro/<id>` (o `?libro=<id>`).
class DeepLink {
  DeepLink._();

  static const String appUrl = 'https://buenas-lecturas.costacode.es';

  static String? _pendingBookId = bookIdFromUri(Uri.base);

  /// Enlace que abre la ficha de un libro dentro de la app.
  static String bookUrl(String bookId) => '$appUrl/libro/${Uri.encodeComponent(bookId)}';

  /// Extrae el id del libro de una URL, o `null` si no es un enlace a libro.
  static String? bookIdFromUri(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    String? id;
    if (segments.length >= 2 && segments[segments.length - 2] == 'libro') {
      id = segments.last;
    } else {
      id = uri.queryParameters['libro'];
    }
    if (id == null) return null;
    id = id.trim();
    // Solo ids con caracteres razonables (evita inyectar rutas raras)
    return RegExp(r'^[\w-]{1,64}$').hasMatch(id) ? id : null;
  }

  /// Devuelve el libro con el que se abrió la app, una sola vez, y limpia la
  /// dirección del navegador para que al recargar no vuelva a abrirlo.
  static String? consumePendingBookId() {
    final id = _pendingBookId;
    if (id != null) {
      _pendingBookId = null;
      resetBrowserPath();
    }
    return id;
  }
}
