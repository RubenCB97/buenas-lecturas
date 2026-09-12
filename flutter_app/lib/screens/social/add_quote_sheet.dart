import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/book_model.dart';
import '../../providers/social_provider.dart';

class AddQuoteSheet extends StatefulWidget {
  final BookModel book;

  const AddQuoteSheet({super.key, required this.book});

  @override
  State<AddQuoteSheet> createState() => _AddQuoteSheetState();
}

class _AddQuoteSheetState extends State<AddQuoteSheet> {
  final _text = TextEditingController();
  final _page = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    _page.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_text.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final social = Provider.of<SocialProvider>(context, listen: false);
    final ok = await social.addQuote(widget.book, _text.text.trim(), page: int.tryParse(_page.text.trim()));
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: AppTheme.accentSage, content: Text('Cita guardada ✍')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Añadir cita', style: Theme.of(context).textTheme.titleLarge),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ],
          ),
          const SizedBox(height: 4),
          Text(widget.book.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          const SizedBox(height: 16),
          TextField(
            controller: _text,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'Escribe la cita que quieras recordar...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _page,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Página (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.format_quote_rounded),
              label: Text(_saving ? 'Guardando…' : 'Guardar cita'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
