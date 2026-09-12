import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';

/// Hoja para cambiar la foto de perfil: subir una imagen propia, elegir un
/// avatar ilustrado, o quitar la actual.
class AvatarPickerSheet extends StatefulWidget {
  final UserModel user;

  const AvatarPickerSheet({super.key, required this.user});

  @override
  State<AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<AvatarPickerSheet> {
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;

  /// Avatares ilustrados generados por DiceBear (SVG servido como PNG).
  /// Sirven para quien no quiera subir una foto propia.
  static const List<String> _presetSeeds = [
    'libro', 'lectura', 'pagina', 'tinta', 'papel',
    'novela', 'poesia', 'relato', 'verso', 'prosa',
    'capitulo', 'marcapaginas',
  ];

  String _presetUrl(String seed) =>
      'https://api.dicebear.com/7.x/thumbs/png?seed=$seed&backgroundColor=e4ebd3,dbe1cb&scale=90';

  Future<void> _pickFrom(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _busy = true);
      final bytes = await picked.readAsBytes();

      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final error = await auth.uploadAvatar(
        bytes: bytes,
        filename: picked.name.isNotEmpty ? picked.name : 'avatar.jpg',
        contentType: picked.mimeType,
      );

      if (!mounted) return;
      setState(() => _busy = false);
      _finish(error, okMessage: 'Foto de perfil actualizada');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError('No se pudo abrir la imagen: $e');
    }
  }

  Future<void> _usePreset(String seed) async {
    setState(() => _busy = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final error = await auth.setAvatarUrl(_presetUrl(seed));
    if (!mounted) return;
    setState(() => _busy = false);
    _finish(error, okMessage: 'Avatar actualizado');
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final error = await auth.removeAvatar();
    if (!mounted) return;
    setState(() => _busy = false);
    _finish(error, okMessage: 'Foto de perfil eliminada');
  }

  void _finish(String? error, {required String okMessage}) {
    if (error != null) {
      _showError(error);
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppTheme.accentSage, content: Text(okMessage)),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.redAccent, content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser ?? widget.user;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_circle_rounded, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text('Foto de perfil',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 17)),
                const Spacer(),
                IconButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Vista previa actual
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppTheme.primaryLight,
                    backgroundImage: user.hasAvatar ? NetworkImage(user.avatarUrl) : null,
                    child: !user.hasAvatar
                        ? Text(user.initial,
                            style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryDark))
                        : null,
                  ),
                  if (_busy)
                    const SizedBox(
                      width: 96,
                      height: 96,
                      child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.primary),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Acciones de subida
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                    label: const Text('Galería'),
                    onPressed: _busy ? null : () => _pickFrom(ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_camera_rounded, size: 18),
                    label: const Text('Cámara'),
                    onPressed: _busy ? null : () => _pickFrom(ImageSource.camera),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            Text('O elige un avatar',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                )),
            const SizedBox(height: 10),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _presetSeeds.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final url = _presetUrl(_presetSeeds[i]);
                  final selected = user.picture == url;
                  return GestureDetector(
                    onTap: _busy ? null : () => _usePreset(_presetSeeds[i]),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? AppTheme.primary : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: AppTheme.primaryLight,
                        backgroundImage: NetworkImage(url),
                        onBackgroundImageError: (_, __) {},
                      ),
                    ),
                  );
                },
              ),
            ),

            if (user.hasAvatar) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Quitar foto de perfil'),
                  onPressed: _busy ? null : _remove,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
