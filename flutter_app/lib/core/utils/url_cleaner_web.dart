import 'package:web/web.dart' as web;

void resetBrowserPath() {
  final location = web.window.location;
  // Conservamos parámetros de login (?token=…) si los hubiera
  final params = Uri.parse(location.href).queryParameters
    ..removeWhere((key, _) => key == 'libro');
  final query = params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';
  web.window.history.replaceState(null, '', '/$query${location.hash}');
}
