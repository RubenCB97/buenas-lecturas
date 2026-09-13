import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';

/// Estadísticas de lectura de un año, calculadas en el backend.
class ReadingStats {
  final int year;
  final int booksRead;
  final int pagesRead;
  final int booksWithoutPages;
  final double? averageRating;
  final int? averagePagesPerBook;
  final int? averageDaysToFinish;
  final List<({int month, int books, int pages})> byMonth;
  final List<({String name, int count})> topGenres;
  final List<({String name, int count})> topAuthors;
  /// Libros por nota en tramos de medio punto: índice 0 = 0,5★ … índice 9 = 5★.
  final List<int> ratingDistribution;
  final ({String title, int pages})? longestBook;
  final ({String title, int pages})? shortestBook;
  final Map<String, int> statusCounts;
  final List<int> availableYears;

  ReadingStats({
    required this.year,
    required this.booksRead,
    required this.pagesRead,
    required this.booksWithoutPages,
    required this.averageRating,
    required this.averagePagesPerBook,
    required this.averageDaysToFinish,
    required this.byMonth,
    required this.topGenres,
    required this.topAuthors,
    required this.ratingDistribution,
    required this.longestBook,
    required this.shortestBook,
    required this.statusCounts,
    required this.availableYears,
  });

  factory ReadingStats.fromJson(Map<String, dynamic> json) {
    int i(dynamic v) => (v as num?)?.toInt() ?? 0;
    List<({String name, int count})> ranking(dynamic list) => (list as List? ?? [])
        .map((e) => (name: e['name'].toString(), count: i(e['count'])))
        .toList();
    ({String title, int pages})? bookOf(dynamic v) =>
        v is Map ? (title: v['title'].toString(), pages: i(v['pages'])) : null;

    return ReadingStats(
      year: i(json['year']),
      booksRead: i(json['booksRead']),
      pagesRead: i(json['pagesRead']),
      booksWithoutPages: i(json['booksWithoutPages']),
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      averagePagesPerBook: (json['averagePagesPerBook'] as num?)?.toInt(),
      averageDaysToFinish: (json['averageDaysToFinish'] as num?)?.toInt(),
      byMonth: (json['byMonth'] as List? ?? [])
          .map((e) => (month: i(e['month']), books: i(e['books']), pages: i(e['pages'])))
          .toList(),
      topGenres: ranking(json['topGenres']),
      topAuthors: ranking(json['topAuthors']),
      ratingDistribution: halfStarDistribution((json['ratingDistribution'] as List? ?? []).map(i).toList()),
      longestBook: bookOf(json['longestBook']),
      shortestBook: bookOf(json['shortestBook']),
      statusCounts: (json['statusCounts'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), i(v))),
      availableYears: (json['availableYears'] as List? ?? []).map(i).toList(),
    );
  }

  /// Normaliza la distribución a 10 tramos de medio punto. Acepta también el
  /// formato antiguo de 5 tramos (estrellas enteras).
  static List<int> halfStarDistribution(List<int> raw) {
    final result = List<int>.filled(10, 0);
    if (raw.length == 5) {
      for (var star = 1; star <= 5; star++) {
        result[star * 2 - 1] = raw[star - 1];
      }
    } else {
      for (var k = 0; k < raw.length && k < 10; k++) {
        result[k] = raw[k];
      }
    }
    return result;
  }

  /// Etiqueta de un tramo: 9 → «5 ★», 8 → «4,5 ★».
  static String ratingLabel(int index) {
    final value = (index + 1) / 2;
    final text = value == value.roundToDouble() ? value.toInt().toString() : value.toString().replaceAll('.', ',');
    return '$text ★';
  }
}

class ReadingStatsScreen extends StatefulWidget {
  const ReadingStatsScreen({super.key});

  @override
  State<ReadingStatsScreen> createState() => _ReadingStatsScreenState();
}

class _ReadingStatsScreenState extends State<ReadingStatsScreen> {
  static const _months = ['E', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

  int _year = DateTime.now().year;
  ReadingStats? _stats;
  bool _loading = true;
  String? _error;
  bool _showPages = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await ApiClient().get('/library/stats/detailed', queryParams: {'year': _year});
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.success && r.data is Map<String, dynamic>) {
        _stats = ReadingStats.fromJson(r.data as Map<String, dynamic>);
      } else {
        _error = r.errorMessage ?? 'No se pudieron cargar las estadísticas';
      }
    });
  }

  String _number(num n) {
    final s = n.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final years = stats?.availableYears ?? [_year];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: years.contains(_year) ? _year : years.first,
                borderRadius: BorderRadius.circular(12),
                items: years.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                onChanged: (y) {
                  if (y == null || y == _year) return;
                  setState(() => _year = y);
                  _load();
                },
              ),
            ),
          ),
        ],
      ),
      body: _loading && stats == null
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null && stats == null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.grey)))
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: _load,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                        children: _buildContent(context, stats!),
                      ),
                    ),
                  ),
                ),
    );
  }

  List<Widget> _buildContent(BuildContext context, ReadingStats s) {
    if (s.booksRead == 0) {
      return [
        _Tiles(items: [
          ('0', 'libros en ${s.year}'),
          ('${s.statusCounts['reading'] ?? 0}', 'leyendo ahora'),
          ('${s.statusCounts['wantToRead'] ?? 0}', 'por leer'),
        ]),
        const SizedBox(height: 32),
        const Icon(Icons.insights_rounded, size: 56, color: Colors.grey),
        const SizedBox(height: 12),
        Text(
          'Aún no has terminado ningún libro en ${s.year}. Cuando marques libros como leídos '
          'verás aquí tus páginas por mes, géneros, autores y ritmo de lectura.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 13.5, height: 1.4),
        ),
      ];
    }

    final maxValue = s.byMonth
        .map((m) => _showPages ? m.pages : m.books)
        .fold<int>(0, (a, b) => b > a ? b : a);

    return [
      _Tiles(items: [
        ('${s.booksRead}', 'libros'),
        (_number(s.pagesRead), 'páginas'),
        (s.averageRating != null ? s.averageRating!.toStringAsFixed(1).replaceAll('.', ',') : '—', 'nota media'),
      ]),
      const SizedBox(height: 10),
      _Tiles(items: [
        (s.averagePagesPerBook != null ? _number(s.averagePagesPerBook!) : '—', 'págs. por libro'),
        (s.averageDaysToFinish != null ? '${s.averageDaysToFinish}' : '—', 'días por libro'),
        ('${s.statusCounts['abandoned'] ?? 0}', 'sin terminar'),
      ]),
      if (s.booksWithoutPages > 0)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '${s.booksWithoutPages} ${s.booksWithoutPages == 1 ? 'libro no tiene' : 'libros no tienen'} '
            'número de páginas conocido y no suma${s.booksWithoutPages == 1 ? '' : 'n'} páginas.',
            style: const TextStyle(fontSize: 11.5, color: Colors.grey),
          ),
        ),

      // ---- Por meses ----
      _Section(
        title: 'Por meses',
        trailing: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Libros')),
            ButtonSegment(value: true, label: Text('Páginas')),
          ],
          selected: {_showPages},
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          onSelectionChanged: (v) => setState(() => _showPages = v.first),
        ),
        child: SizedBox(
          height: 170,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final m in s.byMonth)
                Expanded(
                  child: _Bar(
                    value: _showPages ? m.pages : m.books,
                    max: maxValue,
                    label: _months[m.month - 1],
                  ),
                ),
            ],
          ),
        ),
      ),

      if (s.topGenres.isNotEmpty)
        _Section(title: 'Géneros más leídos', child: _Ranking(items: s.topGenres)),
      if (s.topAuthors.isNotEmpty)
        _Section(title: 'Autores más leídos', child: _Ranking(items: s.topAuthors)),

      if (s.ratingDistribution.any((n) => n > 0))
        _Section(
          title: 'Tus puntuaciones',
          child: _Ranking(
            items: [
              for (var k = 9; k >= 0; k--)
                (name: ReadingStats.ratingLabel(k), count: s.ratingDistribution[k]),
            ],
            keepZeros: true,
          ),
        ),

      if (s.longestBook != null)
        _Section(
          title: 'Extremos',
          child: Column(
            children: [
              _BookLine(icon: Icons.menu_book_rounded, label: 'El más largo', book: s.longestBook!),
              if (s.shortestBook != null && s.shortestBook!.title != s.longestBook!.title)
                _BookLine(icon: Icons.bolt_rounded, label: 'El más corto', book: s.shortestBook!),
            ],
          ),
        ),
    ];
  }
}

class _Tiles extends StatelessWidget {
  final List<(String, String)> items;

  const _Tiles({required this.items});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surfaceDarkSecondary : AppTheme.primaryLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(items[i].$1,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primaryDark)),
                  const SizedBox(height: 2),
                  Text(items[i].$2,
                      textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _Section({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 17))),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final int value;
  final int max;
  final String label;

  const _Bar({required this.value, required this.max, required this.label});

  @override
  Widget build(BuildContext context) {
    final fraction = max == 0 ? 0.0 : value / max;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (value > 0)
            FittedBox(
              child: Text('$value', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 3),
          LayoutBuilder(
            builder: (context, constraints) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 120 * fraction + (value > 0 ? 4 : 2),
              decoration: BoxDecoration(
                color: value > 0 ? AppTheme.primary : Colors.grey.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _Ranking extends StatelessWidget {
  final List<({String name, int count})> items;
  final bool keepZeros;

  const _Ranking({required this.items, this.keepZeros = false});

  @override
  Widget build(BuildContext context) {
    final visible = keepZeros ? items : items.where((e) => e.count > 0).toList();
    final max = visible.fold<int>(0, (a, b) => b.count > a ? b.count : a);
    return Column(
      children: [
        for (final item in visible)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 130,
                  child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: max == 0 ? 0 : item.count / max,
                      minHeight: 10,
                      color: AppTheme.primary,
                      backgroundColor: Colors.grey.withValues(alpha: 0.15),
                    ),
                  ),
                ),
                SizedBox(
                  width: 34,
                  child: Text('${item.count}', textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BookLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final ({String title, int pages}) book;

  const _BookLine({required this.icon, required this.label, required this.book});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppTheme.primary),
      title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(label),
      trailing: Text('${book.pages} págs.', style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
