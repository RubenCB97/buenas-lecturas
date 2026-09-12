import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/explore_provider.dart';
import '../../providers/groups_provider.dart';
import '../../widgets/book_card.dart';
import '../../widgets/custom_search_bar.dart';

class SelectBookForGroupScreen extends StatefulWidget {
  final int groupId;

  const SelectBookForGroupScreen({super.key, required this.groupId});

  @override
  State<SelectBookForGroupScreen> createState() => _SelectBookForGroupScreenState();
}

class _SelectBookForGroupScreenState extends State<SelectBookForGroupScreen> {
  DateTime? _targetDate;

  @override
  Widget build(BuildContext context) {
    final explore = Provider.of<ExploreProvider>(context);
    final groups = Provider.of<GroupsProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Elegir libro del club')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: CustomSearchBar(
              placeholder: 'Buscar libro para el club…',
              onChanged: explore.onSearchQueryChanged,
              onClear: explore.clearSearch,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                const Icon(Icons.flag_rounded, color: AppTheme.accentSage, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _targetDate == null ? 'Sin fecha objetivo' : 'Meta: ${_targetDate!.toIso8601String().substring(0, 10)}',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _targetDate = picked);
                  },
                  icon: const Icon(Icons.event_rounded, size: 16),
                  label: const Text('Fecha meta'),
                ),
              ],
            ),
          ),
          Expanded(
            child: explore.isSearching
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: explore.searchResults.length,
                    itemBuilder: (context, index) {
                      final book = explore.searchResults[index];
                      return BookCard(
                        book: book,
                        style: BookCardStyle.largeFeed,
                        onTap: () async {
                          await groups.addBookToGroup(widget.groupId, book, targetEndDate: _targetDate);
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(backgroundColor: AppTheme.accentSage, content: Text('${book.title} añadido al club 📚')),
                            );
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
