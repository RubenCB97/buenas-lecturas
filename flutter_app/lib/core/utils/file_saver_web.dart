import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Descarga el archivo en el navegador. Devuelve `true` al iniciar la descarga.
Future<bool> saveFile({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
}) async {
  final blob = web.Blob(
    [Uint8List.fromList(bytes).toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return true;
}
