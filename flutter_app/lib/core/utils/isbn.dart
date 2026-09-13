/// Validación de ISBN. Debe coincidir con `SearchService.normalizeIsbn` del
/// backend.
class Isbn {
  Isbn._();

  /// Limpia el código y comprueba el dígito de control. Acepta ISBN-10 e
  /// ISBN-13 (EAN que empiezan por 978/979). Devuelve `null` si no es válido,
  /// por ejemplo el código de barras de precio o de un producto que no es un
  /// libro.
  static String? normalize(String raw) {
    final clean = raw.toUpperCase().replaceAll(RegExp(r'[^0-9X]'), '');

    if (RegExp(r'^\d{13}$').hasMatch(clean)) {
      if (!clean.startsWith('978') && !clean.startsWith('979')) return null;
      var sum = 0;
      for (var i = 0; i < 12; i++) {
        sum += int.parse(clean[i]) * (i.isEven ? 1 : 3);
      }
      final check = (10 - (sum % 10)) % 10;
      return check == int.parse(clean[12]) ? clean : null;
    }

    if (RegExp(r'^\d{9}[\dX]$').hasMatch(clean)) {
      var sum = 0;
      for (var i = 0; i < 10; i++) {
        final value = clean[i] == 'X' ? 10 : int.parse(clean[i]);
        sum += value * (10 - i);
      }
      return sum % 11 == 0 ? clean : null;
    }

    return null;
  }
}
