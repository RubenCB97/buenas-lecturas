import 'package:intl/intl.dart';

class DateFormatter {
  static String timeAgo(dynamic dateInput) {
    if (dateInput == null) return '';
    DateTime? date;
    if (dateInput is DateTime) {
      date = dateInput;
    } else if (dateInput is String) {
      date = DateTime.tryParse(dateInput);
    }
    if (date == null) return '';

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return 'hace ${(difference.inDays / 365).floor()} años';
    } else if (difference.inDays > 30) {
      return 'hace ${(difference.inDays / 30).floor()} meses';
    } else if (difference.inDays > 0) {
      return difference.inDays == 1 ? 'ayer' : 'hace ${difference.inDays} días';
    } else if (difference.inHours > 0) {
      return 'hace ${difference.inHours} h';
    } else if (difference.inMinutes > 0) {
      return 'hace ${difference.inMinutes} min';
    } else {
      return 'hace unos momentos';
    }
  }

  static String formatShort(dynamic dateInput) {
    if (dateInput == null) return '';
    DateTime? date;
    if (dateInput is DateTime) {
      date = dateInput;
    } else if (dateInput is String) {
      date = DateTime.tryParse(dateInput);
    }
    if (date == null) return '';

    // Nombres de meses abreviados en español (evita depender de initializeDateFormatting)
    const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    try {
      return DateFormat('d MMM yyyy', 'es').format(date);
    } catch (_) {
      final m = meses[date.month - 1];
      return '${date.day} $m ${date.year}';
    }
  }
}
