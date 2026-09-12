import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/theme_provider.dart';

/// Hoja modal para elegir tema: claro / oscuro / según el sistema.
class ThemeSettingsSheet extends StatelessWidget {
  const ThemeSettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget option(AppThemeMode mode, {String? subtitle}) {
      final selected = provider.mode == mode;
      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => provider.setMode(mode),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.12)
                : (isDark ? AppTheme.surfaceDarkSecondary : AppTheme.surfaceLightSecondary),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppTheme.primary : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: selected ? 0.18 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(mode.icon, color: AppTheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mode.label,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: selected ? AppTheme.primary : null,
                          fontSize: 14,
                        )),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight)),
                    ],
                  ],
                ),
              ),
              if (selected) const Icon(Icons.check_circle_rounded, color: AppTheme.primary),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.palette_rounded, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text('Apariencia', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 17)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Elige cómo se mostrará la aplicación.',
              style: TextStyle(fontSize: 12.5, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
            ),
            const SizedBox(height: 14),
            option(AppThemeMode.system, subtitle: 'Sigue la preferencia de tu dispositivo'),
            option(AppThemeMode.light, subtitle: 'Fondo verde-oliva suave, alto contraste'),
            option(AppThemeMode.dark, subtitle: 'Verde oliva profundo, cómodo para la vista'),
          ],
        ),
      ),
    );
  }
}
