/// Guarda un archivo generado por la app.
///
/// En web lo descarga con el navegador; en móvil y escritorio abre el menú del
/// sistema para guardarlo en Archivos, enviarlo por correo, etc.
export 'file_saver_io.dart' if (dart.library.js_interop) 'file_saver_web.dart';
