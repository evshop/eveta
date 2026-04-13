import 'package:flutter/material.dart';

import '../theme/eveta_theme_controller.dart';
import '../widgets/portal/portal_tokens.dart';

/// Solo aquí: selector segmentado (como antes). El perfil muestra una fila que abre esta pantalla.
class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  static String labelFor(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'Claro',
      ThemeMode.dark => 'Oscuro',
      _ => 'Automático',
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apariencia'),
      ),
      body: SafeArea(
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: evetaThemeMode,
          builder: (context, mode, _) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: PortalTokens.space3, vertical: PortalTokens.space2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tema',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Claro, oscuro o según el sistema',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: PortalTokens.space3),
                  SegmentedButton<int>(
                    style: SegmentedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(PortalTokens.radiusLg),
                      ),
                    ),
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        icon: Icon(Icons.brightness_auto, size: 20),
                        label: Text('Auto'),
                      ),
                      ButtonSegment(
                        value: 1,
                        icon: Icon(Icons.light_mode_outlined, size: 20),
                        label: Text('Claro'),
                      ),
                      ButtonSegment(
                        value: 2,
                        icon: Icon(Icons.dark_mode_outlined, size: 20),
                        label: Text('Oscuro'),
                      ),
                    ],
                    selected: {
                      switch (mode) {
                        ThemeMode.light => 1,
                        ThemeMode.dark => 2,
                        _ => 0,
                      },
                    },
                    onSelectionChanged: (s) {
                      final v = s.first;
                      setEvetaThemeMode(switch (v) {
                        1 => ThemeMode.light,
                        2 => ThemeMode.dark,
                        _ => ThemeMode.system,
                      });
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
