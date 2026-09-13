import '../../models/user_book_model.dart';

/// Saga detectada en el título de un libro.
class SeriesInfo {
  final String name;

  /// Número dentro de la saga; puede ser decimal en relatos (#0.5, #2.5).
  final double number;

  const SeriesInfo(this.name, this.number);

  /// Clave para agrupar variantes del mismo nombre.
  String get key => Series.normalize(name);

  String get numberLabel =>
      number == number.roundToDouble() ? number.toStringAsFixed(0) : number.toString();
}

/// Un libro de la biblioteca dentro de una saga.
class SeriesBook {
  final UserBookModel userBook;
  final double number;

  const SeriesBook(this.userBook, this.number);

  bool get isRead => userBook.status == ReadingStatus.read;
}

/// Progreso del usuario en una saga.
class SeriesProgress {
  final String name;
  final List<SeriesBook> books;

  /// Siguiente número entero que no ha leído (puede que no lo tenga).
  final int nextNumber;

  /// El libro con ese número, si está en su biblioteca.
  final SeriesBook? nextBook;

  const SeriesProgress({
    required this.name,
    required this.books,
    required this.nextNumber,
    required this.nextBook,
  });

  int get readCount => books.where((b) => b.isRead).length;

  /// Números enteros por debajo del mayor conocido que no están en la biblioteca.
  List<int> get missingNumbers {
    final have = books.map((b) => b.number).toSet();
    final maxKnown = books.map((b) => b.number).fold<double>(0, (a, b) => b > a ? b : a).floor();
    return [for (var n = 1; n < maxKnown; n++) if (!have.contains(n.toDouble())) n];
  }

  bool get isComplete => books.every((b) => b.isRead) && missingNumbers.isEmpty;

  /// Autor principal de la saga (el más repetido).
  String? get author {
    final counts = <String, int>{};
    for (final b in books) {
      for (final a in b.userBook.book.authors) {
        counts[a] = (counts[a] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    return (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
  }
}

class Series {
  Series._();

  // "(The Hunger Games, #1)"  "(Dune, #0.5)"
  static final _hashPattern = RegExp(r'\(([^()]+?),?\s*#\s*(\d+(?:\.\d+)?)\s*\)');
  // "(Mistborn, Book 2)"  "(Saga, Libro 3)"  "(Saga, Vol. 4)"
  static final _wordPattern = RegExp(
    r'\(([^()]+?),?\s*(?:book|libro|vol\.?|volume|volumen|tomo|part|parte)\s*(\d+(?:\.\d+)?)\s*\)',
    caseSensitive: false,
  );
  // "(Las crónicas de Dune 5)"
  static final _trailingNumberPattern = RegExp(r'\(([^()]*[^\d\s()][^()]*?)\s+(\d{1,2})\s*\)');

  /// Nombres entre paréntesis que no son sagas.
  static final _notSeries = RegExp(
    r'^(edici[oó]n|edition|ed\.|volumen|volume|tomo|spanish|english|español|ilustrad|illustrated|reissue)',
    caseSensitive: false,
  );

  static String normalize(String name) {
    const from = 'áàäâéèëêíìïîóòöôúùüûñ';
    const to = 'aaaaeeeeiiiioooouuuun';
    var s = name.toLowerCase().trim();
    for (var i = 0; i < from.length; i++) {
      s = s.replaceAll(from[i], to[i]);
    }
    return s.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  /// Detecta saga y número en un título, o `null` si no aparece.
  static SeriesInfo? parse(String title) {
    for (final pattern in [_hashPattern, _wordPattern, _trailingNumberPattern]) {
      final m = pattern.firstMatch(title);
      if (m == null) continue;
      final name = m.group(1)!.trim();
      final number = double.tryParse(m.group(2)!);
      // Descartamos años ("Edición 2020") y cosas que no son sagas
      if (number == null || number <= 0 || number > 60 || name.isEmpty || _notSeries.hasMatch(name)) {
        continue;
      }
      return SeriesInfo(name, number);
    }
    return null;
  }

  /// Agrupa la biblioteca por sagas, de la más avanzada a la menos.
  static List<SeriesProgress> fromLibrary(List<UserBookModel> library) {
    final groups = <String, List<SeriesBook>>{};
    final names = <String, String>{};

    for (final ub in library) {
      final info = parse(ub.book.title);
      if (info == null) continue;
      groups.putIfAbsent(info.key, () => []);
      // Si hay dos ediciones del mismo número, nos quedamos con la más avanzada
      final existing = groups[info.key]!.indexWhere((b) => b.number == info.number);
      final candidate = SeriesBook(ub, info.number);
      if (existing == -1) {
        groups[info.key]!.add(candidate);
      } else if (candidate.isRead && !groups[info.key]![existing].isRead) {
        groups[info.key]![existing] = candidate;
      }
      names.putIfAbsent(info.key, () => info.name);
    }

    final result = groups.entries.map((entry) {
      final books = entry.value..sort((a, b) => a.number.compareTo(b.number));
      final readNumbers = books.where((b) => b.isRead).map((b) => b.number).toSet();
      final maxKnown = books.last.number.floor();

      var next = 1;
      while (next <= maxKnown && readNumbers.contains(next.toDouble())) {
        next++;
      }
      SeriesBook? nextBook;
      for (final b in books) {
        if (b.number == next.toDouble()) nextBook = b;
      }

      return SeriesProgress(name: names[entry.key]!, books: books, nextNumber: next, nextBook: nextBook);
    }).toList();

    result.sort((a, b) {
      final byRead = b.readCount.compareTo(a.readCount);
      return byRead != 0 ? byRead : a.name.compareTo(b.name);
    });
    return result;
  }
}
