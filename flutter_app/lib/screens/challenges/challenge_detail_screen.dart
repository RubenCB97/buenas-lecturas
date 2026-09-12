import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/challenge_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/challenges_provider.dart';
import '../../widgets/book_cover_image.dart';
import '../book_detail/book_detail_screen.dart';
import 'add_category_dialog.dart';
import 'cell_review_sheet.dart';
import 'invite_to_challenge_sheet.dart';
import 'notes_cell_sheet.dart';
import 'pick_book_for_cell_screen.dart';

class ChallengeDetailScreen extends StatefulWidget {
  final int challengeId;

  const ChallengeDetailScreen({super.key, required this.challengeId});

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  static const double _colHeaderHeight = 74;

  double get _screenWidth => MediaQuery.of(context).size.width;
  bool get _isCompact => _screenWidth < 600;
  bool get _isWide => _screenWidth >= 1200;

  double get _cellWidth => _isWide ? 140 : _isCompact ? 92 : 110;
  double get _cellHeight => _isWide ? 170 : _isCompact ? 140 : 150;
  double get _notesCellWidth => _isWide ? 200 : _isCompact ? 130 : 170;
  double get _rowHeaderWidth => _isWide ? 160 : _isCompact ? 90 : 130;

  final ScrollController _horizontalHeader = ScrollController();
  final ScrollController _horizontalBody = ScrollController();
  final ScrollController _verticalRowHeader = ScrollController();
  final ScrollController _verticalBody = ScrollController();

  bool _syncingHoriz = false;
  bool _syncingVert = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ChallengesProvider>(context, listen: false).load(widget.challengeId);
    });

    _horizontalHeader.addListener(() {
      if (_syncingHoriz) return;
      _syncingHoriz = true;
      if (_horizontalBody.hasClients) _horizontalBody.jumpTo(_horizontalHeader.offset);
      _syncingHoriz = false;
    });
    _horizontalBody.addListener(() {
      if (_syncingHoriz) return;
      _syncingHoriz = true;
      if (_horizontalHeader.hasClients) _horizontalHeader.jumpTo(_horizontalBody.offset);
      _syncingHoriz = false;
    });
    _verticalRowHeader.addListener(() {
      if (_syncingVert) return;
      _syncingVert = true;
      if (_verticalBody.hasClients) _verticalBody.jumpTo(_verticalRowHeader.offset);
      _syncingVert = false;
    });
    _verticalBody.addListener(() {
      if (_syncingVert) return;
      _syncingVert = true;
      if (_verticalRowHeader.hasClients) _verticalRowHeader.jumpTo(_verticalBody.offset);
      _syncingVert = false;
    });
  }

  @override
  void dispose() {
    _horizontalHeader.dispose();
    _horizontalBody.dispose();
    _verticalRowHeader.dispose();
    _verticalBody.dispose();
    super.dispose();
  }

  Future<void> _openAddCategory() async {
    final data = await showDialog<Map<String, String>?>(
      context: context,
      builder: (_) => const AddCategoryDialog(),
    );
    if (data != null && data['name'] != null && data['name']!.isNotEmpty && mounted) {
      await Provider.of<ChallengesProvider>(context, listen: false)
          .addCategory(widget.challengeId, data['name']!, icon: data['icon'] ?? '📖');
    }
  }

  Future<void> _openInvite() {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => InviteToChallengeSheet(challengeId: widget.challengeId),
    );
  }

  Future<void> _openPickBook(int categoryId) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => PickBookForCellScreen(challengeId: widget.challengeId, categoryId: categoryId),
    ));
    if (mounted) {
      await Provider.of<ChallengesProvider>(context, listen: false).load(widget.challengeId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ChallengesProvider>(context);
    final detail = provider.selected;
    final auth = Provider.of<AuthProvider>(context);
    final meId = auth.currentUser?.id is int
        ? auth.currentUser!.id as int
        : int.tryParse('${auth.currentUser?.id}') ?? -1;

    if (provider.isLoading && detail == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primary)));
    }
    if (detail == null) {
      return const Scaffold(body: Center(child: Text('Reto no encontrado')));
    }

    final color = Color(int.parse(detail.challenge.coverColor.replaceFirst('#', 'FF'), radix: 16));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        title: Text(detail.challenge.name),
        actions: [
          IconButton(icon: const Icon(Icons.person_add_alt_1_rounded), tooltip: 'Invitar', onPressed: _openInvite),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'leave') {
                await provider.leave(widget.challengeId);
                if (mounted) Navigator.pop(context);
              }
              if (v == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('¿Eliminar reto?'),
                    content: const Text('Se borrará el reto y todas las participaciones.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                      ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
                    ],
                  ),
                );
                if (confirm == true) {
                  await provider.delete(widget.challengeId);
                  if (mounted) Navigator.pop(context);
                }
              }
            },
            itemBuilder: (_) => [
              if (!detail.isOwner && detail.isParticipant)
                const PopupMenuItem(value: 'leave', child: Text('Salir del reto')),
              if (detail.isOwner)
                const PopupMenuItem(value: 'delete', child: Text('Eliminar reto')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _summaryBar(detail, color),
          Expanded(child: _buildTable(detail, meId)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddCategory,
        backgroundColor: color,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Categoría'),
      ),
    );
  }

  Widget _summaryBar(ChallengeDetailModel detail, Color color) {
    final myCompleted = detail.completedByUser(_currentUserId());
    final total = detail.categories.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: color.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: AppTheme.starGold, size: 18),
          const SizedBox(width: 6),
          Text('$myCompleted / $total', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 12),
          Expanded(
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : myCompleted / total,
              minHeight: 6,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.people_alt_rounded, size: 15, color: color),
          const SizedBox(width: 3),
          Text('${detail.participants.length}', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          if (detail.challenge.endDate != null) ...[
            const SizedBox(width: 12),
            const Icon(Icons.flag_rounded, size: 14, color: Colors.grey),
            const SizedBox(width: 3),
            Text(DateFormatter.formatShort(detail.challenge.endDate), style: const TextStyle(fontSize: 11.5)),
          ],
        ],
      ),
    );
  }

  int _currentUserId() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final v = auth.currentUser?.id;
    if (v is int) return v;
    return int.tryParse('$v') ?? -1;
  }

  Widget _buildTable(ChallengeDetailModel detail, int meId) {
    final categories = detail.categories;
    final participants = detail.participants;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (categories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.grid_view_rounded, size: 60, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Sin categorías aún', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Añade la primera categoría del reto (ej: "Un clásico") para empezar a construir la tabla.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 14),
              ElevatedButton.icon(icon: const Icon(Icons.add_rounded), label: const Text('Añadir categoría'), onPressed: _openAddCategory),
            ],
          ),
        ),
      );
    }

    final headerRow = SizedBox(
      height: _colHeaderHeight,
      child: Row(
        children: [
          Container(
            width: _rowHeaderWidth,
            height: _colHeaderHeight,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDarkSecondary : AppTheme.surfaceLightSecondary,
              border: Border(right: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight)),
            ),
            alignment: Alignment.center,
            child: const Text('Lector \\ Categoría',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.grey)),
          ),
          Expanded(
            child: ListView.builder(
              controller: _horizontalHeader,
              scrollDirection: Axis.horizontal,
              // +1 por la columna sintética "Notas" al final
              itemCount: categories.length + 1,
              itemBuilder: (context, i) {
                if (i == categories.length) return _notesColumnHeader();
                return _categoryHeader(categories[i], detail);
              },
            ),
          ),
        ],
      ),
    );

    final body = Expanded(
      child: Row(
        children: [
          SizedBox(
            width: _rowHeaderWidth,
            child: ListView.builder(
              controller: _verticalRowHeader,
              itemCount: participants.length,
              itemBuilder: (context, i) => _userRowHeader(participants[i], detail, meId),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _horizontalBody,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                // Ancho total: N celdas normales + 1 celda de notas más ancha
                width: _cellWidth * categories.length + _notesCellWidth,
                child: ListView.builder(
                  controller: _verticalBody,
                  itemCount: participants.length,
                  itemBuilder: (context, r) {
                    final p = participants[r];
                    final userId = p.user.id is int ? p.user.id as int : int.tryParse('${p.user.id}') ?? -1;
                    final isMe = userId == meId;
                    return Row(
                      children: [
                        ...List.generate(categories.length, (c) {
                          final cat = categories[c];
                          final entry = detail.entryFor(userId, cat.id);
                          return _buildCell(entry, cat, isMe);
                        }),
                        _buildNotesCell(p, isMe),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight)),
          ),
          child: headerRow,
        ),
        body,
      ],
    );
  }

  Widget _notesColumnHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: _notesCellWidth,
      height: _colHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDarkSecondary : AppTheme.primaryLight.withValues(alpha: 0.5),
        border: Border(right: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight)),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('📝', style: TextStyle(fontSize: 18)),
          SizedBox(height: 2),
          Text('Notas', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, height: 1.15, color: AppTheme.primary)),
        ],
      ),
    );
  }

  Widget _buildNotesCell(ChallengeParticipantModel participant, bool isMe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notes = participant.notes;
    return GestureDetector(
      onTap: () {
        if (!isMe) {
          if (notes != null && notes.isNotEmpty) {
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (_) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Notas de ${participant.user.fullName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 10),
                      Text(notes, style: const TextStyle(fontSize: 13.5, height: 1.4)),
                    ],
                  ),
                ),
              ),
            );
          }
          return;
        }
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => NotesCellSheet(challengeId: widget.challengeId, participant: participant),
        );
      },
      child: Container(
        width: _notesCellWidth,
        height: _cellHeight,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primary.withValues(alpha: 0.06) : null,
          border: Border(
            right: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
            bottom: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
          ),
        ),
        child: notes == null || notes.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isMe ? Icons.edit_note_rounded : Icons.notes_rounded,
                      size: 26,
                      color: (isMe ? AppTheme.primary : Colors.grey).withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(isMe ? 'Escribir notas' : 'Sin notas',
                        style: TextStyle(fontSize: 10.5, color: (isMe ? AppTheme.primary : Colors.grey).withValues(alpha: 0.85))),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.sticky_note_2_rounded, size: 12, color: AppTheme.primary),
                      const SizedBox(width: 3),
                      Text('Notas',
                          style: TextStyle(
                              fontSize: 9.5, fontWeight: FontWeight.w800, color: AppTheme.primary.withValues(alpha: 0.85))),
                      const Spacer(),
                      if (isMe)
                        const Icon(Icons.edit_rounded, size: 11, color: Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Expanded(
                    child: Text(
                      notes,
                      style: const TextStyle(fontSize: 11, height: 1.25),
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _categoryHeader(ChallengeCategoryModel c, ChallengeDetailModel detail) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: _cellWidth,
      height: _colHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDarkSecondary : AppTheme.surfaceLightSecondary,
        border: Border(right: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight)),
      ),
      child: InkWell(
        onLongPress: () async {
          if (!detail.isOwner && c.createdBy?.id != _currentUserId()) return;
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('¿Borrar categoría?'),
              content: Text('Esto eliminará "${c.name}" y todas las elecciones asociadas.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Borrar')),
              ],
            ),
          );
          if (confirm == true && mounted) {
            Provider.of<ChallengesProvider>(context, listen: false).deleteCategory(widget.challengeId, c.id);
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(c.icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 2),
            Text(c.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, height: 1.15)),
          ],
        ),
      ),
    );
  }

  Widget _userRowHeader(ChallengeParticipantModel p, ChallengeDetailModel detail, int meId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = p.user.id is int ? p.user.id as int : int.tryParse('${p.user.id}') ?? -1;
    final completed = detail.entries.where((e) => e.userId == userId && e.status == ChallengeEntryStatus.completed).length;
    final total = detail.categories.length;
    final pct = total == 0 ? 0.0 : completed / total;
    final isMe = userId == meId;

    final compact = _isCompact;
    final avatarRadius = compact ? 16.0 : _isWide ? 24.0 : 20.0;

    return Container(
      width: _rowHeaderWidth,
      height: _cellHeight,
      padding: EdgeInsets.all(compact ? 4 : 6),
      decoration: BoxDecoration(
        color: isMe
            ? (isDark ? AppTheme.primary.withValues(alpha: 0.15) : AppTheme.primaryLight.withValues(alpha: 0.5))
            : (isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight),
        border: Border(
          right: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
          bottom: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: avatarRadius,
            backgroundColor: AppTheme.primaryLight,
            backgroundImage: p.user.picture != null && p.user.picture!.isNotEmpty ? NetworkImage(p.user.avatarUrl) : null,
            child: p.user.picture == null || p.user.picture!.isEmpty
                ? Text(p.user.fullName.isNotEmpty ? p.user.fullName[0].toUpperCase() : '?',
                    style: TextStyle(fontSize: avatarRadius * 0.7, fontWeight: FontWeight.bold, color: AppTheme.primary))
                : null,
          ),
          SizedBox(height: compact ? 4 : 6),
          Text(isMe ? 'Yo' : p.user.fullName.split(' ').first,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: compact ? 10 : 11, fontWeight: FontWeight.bold, color: isMe ? AppTheme.primary : null)),
          SizedBox(height: compact ? 2 : 4),
          Text('$completed/$total', style: TextStyle(fontSize: compact ? 9 : 10, color: Colors.grey)),
          SizedBox(height: compact ? 2 : 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: compact ? 3 : 4,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(ChallengeEntryModel? entry, ChallengeCategoryModel category, bool isMe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasBook = entry?.book != null;
    final completed = entry?.status == ChallengeEntryStatus.completed;
    final reading = entry?.status == ChallengeEntryStatus.reading;

    Color? tintColor = completed
        ? AppTheme.accentSage.withValues(alpha: 0.12)
        : reading
            ? AppTheme.primary.withValues(alpha: 0.08)
            : null;

    return GestureDetector(
      onTap: () {
        if (!isMe) {
          // Solo ver, no editar
          if (hasBook) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailScreen(book: entry!.book!)));
          }
          return;
        }
        if (!hasBook) {
          _openPickBook(category.id);
        } else {
          _showMyCellMenu(entry!, category);
        }
      },
      onLongPress: isMe && hasBook
          ? () {
              Provider.of<ChallengesProvider>(context, listen: false).clearCell(widget.challengeId, category.id);
            }
          : null,
      child: Container(
        width: _cellWidth,
        height: _cellHeight,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: tintColor,
          border: Border(
            right: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
            bottom: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
          ),
        ),
        child: hasBook
            ? Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Center(
                            child: BookCoverImage(
                              imageUrl: entry!.book!.thumbnail,
                              width: _cellWidth - 14,
                              height: _cellHeight - 54,
                              borderRadius: 5,
                              title: entry.book!.title,
                            ),
                          ),
                        ),
                        if (completed)
                          Positioned(
                            top: 2, right: 2,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(color: AppTheme.accentSage, shape: BoxShape.circle),
                              child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                            ),
                          )
                        else if (reading)
                          Positioned(
                            top: 2, right: 2,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                              child: const Icon(Icons.auto_stories_rounded, size: 12, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      entry.book!.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, height: 1.15),
                    ),
                  ),
                  _miniRatingRow(entry.rating),
                  if ((entry.comment ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        '"${(entry.comment ?? '').trim()}"',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 9, fontStyle: FontStyle.italic, color: Colors.grey),
                      ),
                    ),
                ],
              )
            : Center(
                child: isMe
                    ? Icon(Icons.add_circle_outline_rounded, size: 32, color: AppTheme.primary.withValues(alpha: 0.55))
                    : Icon(Icons.remove_rounded, size: 22, color: Colors.grey.withValues(alpha: 0.4)),
              ),
      ),
    );
  }

  Widget _miniRatingRow(double? rating) {
    if (rating == null || rating <= 0) {
      return const SizedBox(height: 12);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final position = i + 1;
        IconData icon;
        if (rating >= position) {
          icon = Icons.star_rounded;
        } else if (rating >= position - 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_border_rounded;
        }
        return Icon(
          icon,
          size: 11,
          color: rating >= position - 0.5 ? AppTheme.starGold : Colors.grey.withValues(alpha: 0.4),
        );
      }),
    );
  }

  void _showMyCellMenu(ChallengeEntryModel entry, ChallengeCategoryModel category) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Text(category.icon, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(category.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (entry.book != null)
                ListTile(
                  leading: BookCoverImage(imageUrl: entry.book!.thumbnail, width: 38, height: 56, borderRadius: 4, title: entry.book!.title),
                  title: Text(entry.book!.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(entry.book!.authorDisplay, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailScreen(book: entry.book!)));
                  },
                ),
              ListTile(
                leading: const Icon(Icons.auto_stories_rounded, color: AppTheme.primary),
                title: const Text('Marcar como leyendo'),
                selected: entry.status == ChallengeEntryStatus.reading,
                onTap: () {
                  Provider.of<ChallengesProvider>(context, listen: false).updateEntryStatus(widget.challengeId, entry.id, ChallengeEntryStatus.reading);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.check_circle_rounded, color: AppTheme.accentSage),
                title: const Text('Marcar como completado'),
                selected: entry.status == ChallengeEntryStatus.completed,
                onTap: () {
                  Provider.of<ChallengesProvider>(context, listen: false).updateEntryStatus(widget.challengeId, entry.id, ChallengeEntryStatus.completed);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.star_rate_rounded, color: AppTheme.starGold),
                title: Text(entry.rating != null ? 'Editar puntuación y comentario' : 'Puntuar y comentar'),
                subtitle: entry.rating != null || (entry.comment != null && entry.comment!.isNotEmpty)
                    ? Text(
                        '${entry.rating != null ? "${entry.rating}★" : "—"} · ${entry.comment ?? ""}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5),
                      )
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (_) => CellReviewSheet(
                      challengeId: widget.challengeId,
                      entry: entry,
                      category: category,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz_rounded),
                title: const Text('Cambiar libro'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openPickBook(category.id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text('Vaciar celda', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Provider.of<ChallengesProvider>(context, listen: false).clearCell(widget.challengeId, category.id);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
