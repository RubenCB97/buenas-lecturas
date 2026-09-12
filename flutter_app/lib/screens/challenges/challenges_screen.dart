import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/challenge_model.dart';
import '../../providers/challenges_provider.dart';
import 'challenge_detail_screen.dart';
import 'create_challenge_sheet.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ChallengesProvider>(context, listen: false).fetchMine();
    });
  }

  void _openCreate() async {
    final created = await showModalBottomSheet<ChallengeSummaryModel?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const CreateChallengeSheet(),
    );
    if (created != null && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChallengeDetailScreen(challengeId: created.id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ChallengesProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reto Lector'),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded), tooltip: 'Nuevo reto', onPressed: _openCreate),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: provider.fetchMine,
        child: provider.isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : provider.myChallenges.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 80),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(30),
                          child: Column(
                            children: [
                              const Icon(Icons.emoji_events_outlined, size: 70, color: Colors.grey),
                              const SizedBox(height: 14),
                              const Text('Sin retos aún', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 6),
                              const Text(
                                'Crea un reto lector con tus amigos. Tú y ellos rellenaréis una tabla eligiendo un libro para cada categoría.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.rocket_launch_rounded),
                                label: const Text('Crear primer reto'),
                                onPressed: _openCreate,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.myChallenges.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _card(provider.myChallenges[i]),
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Nuevo reto'),
      ),
    );
  }

  Widget _card(ChallengeSummaryModel c) {
    final color = Color(int.parse(c.coverColor.replaceFirst('#', 'FF'), radix: 16));
    final progress = c.categoriesCount == 0 ? 0.0 : (c.myCompletedCount / c.categoriesCount).clamp(0.0, 1.0);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ChallengeDetailScreen(challengeId: c.id)));
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 82,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(child: Icon(Icons.emoji_events_rounded, color: Colors.white, size: 30)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    if (c.description != null && c.description!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(c.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.people_alt_rounded, size: 12, color: color),
                        const SizedBox(width: 3),
                        Text('${c.participantsCount}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: color)),
                        const SizedBox(width: 10),
                        const Icon(Icons.category_rounded, size: 12, color: Colors.grey),
                        const SizedBox(width: 3),
                        Text('${c.categoriesCount} categorías', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                        if (c.endDate != null) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.flag_rounded, size: 12, color: Colors.grey),
                          const SizedBox(width: 3),
                          Text(DateFormatter.formatShort(c.endDate), style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${c.myCompletedCount}/${c.categoriesCount} completadas',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
