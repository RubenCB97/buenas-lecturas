import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/challenge_model.dart';
import '../../providers/challenges_provider.dart';

/// Hoja modal para editar el texto libre de la columna "Notas" del reto.
class NotesCellSheet extends StatefulWidget {
  final int challengeId;
  final ChallengeParticipantModel participant;

  const NotesCellSheet({super.key, required this.challengeId, required this.participant});

  @override
  State<NotesCellSheet> createState() => _NotesCellSheetState();
}

class _NotesCellSheetState extends State<NotesCellSheet> {
  late TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.participant.notes ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final provider = Provider.of<ChallengesProvider>(context, listen: false);
    await provider.updateMyNotes(widget.challengeId, _ctrl.text.trim());
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sticky_note_2_rounded, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text('Mis notas del reto', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 17)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Escribe anotaciones, ideas, aprendizajes o reflexiones globales sobre este reto lector. Estas notas se verán en la columna "Notas" del reto.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: 'Ejemplo: "Este reto me hizo salir de mi género favorito"…',
              filled: true,
              fillColor: isDark ? AppTheme.surfaceDarkSecondary : AppTheme.surfaceLightSecondary,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Guardando…' : 'Guardar notas'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
