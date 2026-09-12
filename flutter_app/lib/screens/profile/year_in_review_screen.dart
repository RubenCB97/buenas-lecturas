import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';

class YearInReviewScreen extends StatefulWidget {
  final int? year;
  const YearInReviewScreen({super.key, this.year});

  @override
  State<YearInReviewScreen> createState() => _YearInReviewScreenState();
}

class _YearInReviewScreenState extends State<YearInReviewScreen> {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = ApiClient();
    final r = await client.get('/library/stats/year', queryParams: widget.year != null ? {'year': widget.year} : null);
    if (r.success && r.data is Map<String, dynamic>) {
      _stats = r.data as Map<String, dynamic>;
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final year = widget.year ?? DateTime.now().year;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primary, AppTheme.primaryDark],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          Text('Mi año literario $year',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          const Spacer(),
                          const SizedBox(width: 40),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            _hero('${_stats?['booksRead'] ?? 0}', 'libros terminados'),
                            const SizedBox(height: 24),
                            _hero(_formatPages(_stats?['totalPages'] ?? 0), 'páginas devoradas'),
                            const SizedBox(height: 24),
                            _hero('${(_stats?['avgRating'] ?? 0).toString()} ★', 'tu calificación media'),
                            const SizedBox(height: 24),
                            if (_stats?['topGenre'] != null)
                              _hero('${_stats!['topGenre']}', 'género más leído'),
                            const SizedBox(height: 30),
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.emoji_events_rounded, color: Colors.white, size: 40),
                                  SizedBox(height: 8),
                                  Text('¡Enhorabuena!',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                                  SizedBox(height: 4),
                                  Text('Cada libro es un mundo. Gracias por leer y compartir.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _hero(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 54, fontWeight: FontWeight.w900, height: 1.0)),
        const SizedBox(height: 4),
        Text(label.toUpperCase(),
            style: const TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
      ],
    );
  }

  String _formatPages(dynamic p) {
    final n = p is int ? p : int.tryParse('$p') ?? 0;
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
