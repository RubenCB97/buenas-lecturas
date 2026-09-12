import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/challenges_provider.dart';
import '../../providers/explore_provider.dart';
import '../../providers/library_provider.dart';
import '../../widgets/book_card.dart';
import '../../widgets/custom_search_bar.dart';

class PickBookForCellScreen extends StatefulWidget {
  final int challengeId;
  final int categoryId;

  const PickBookForCellScreen(
      {super.key, required this.challengeId, required this.categoryId});

  @override
  State<PickBookForCellScreen> createState() => _PickBookForCellScreenState();
}

class _PickBookForCellScreenState extends State<PickBookForCellScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final explore = Provider.of<ExploreProvider>(context);
    final library = Provider.of<LibraryProvider>(context);
    final challenges = Provider.of<ChallengesProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Elegir libro'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Buscar'),
            Tab(text: 'Mi biblioteca'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // TAB 1: Buscar
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: CustomSearchBar(
                  placeholder: 'Buscar libro…',
                  onChanged: explore.onSearchQueryChanged,
                  onClear: explore.clearSearch,
                ),
              ),
              Expanded(
                child: explore.isSearching
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: AppTheme.primary))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: explore.searchResults.length,
                        itemBuilder: (context, i) {
                          final b = explore.searchResults[i];
                          return BookCard(
                            book: b,
                            style: BookCardStyle.largeFeed,
                            onTap: () async {
                              await challenges.setBookForCell(
                                  widget.challengeId, widget.categoryId, b);
                              if (mounted) Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),

          // TAB 2: Mi biblioteca
          library.libraryBooks.isEmpty
              ? const Center(
                  child: Text('Tu biblioteca está vacía',
                      style: TextStyle(color: Colors.grey)))
              : GridView.builder(
                  padding: const EdgeInsets.all(14),
                  // Rejilla adaptativa para que las portadas no crezcan en web
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 136,
                    mainAxisExtent: 226,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: library.libraryBooks.length,
                  itemBuilder: (context, i) {
                    final ub = library.libraryBooks[i];
                    return BookCard(
                      book: ub.book,
                      userBook: ub,
                      style: BookCardStyle.gridItem,
                      onTap: () async {
                        await challenges.setBookForCell(
                            widget.challengeId, widget.categoryId, ub.book);
                        if (mounted) Navigator.pop(context);
                      },
                    );
                  },
                ),
        ],
      ),
    );
  }
}
