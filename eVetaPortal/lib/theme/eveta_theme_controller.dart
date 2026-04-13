import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clave de [SharedPreferences] para el modo de tema (persistido entre sesiones).
const String kEvetaPortalThemeModePref = 'eveta_portal_theme_mode';

const _kThemeModePref = kEvetaPortalThemeModePref;

/// Control global del [ThemeMode] (sistema / claro / oscuro), persistido.
final ValueNotifier<ThemeMode> evetaThemeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

Future<void> loadEvetaThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final i = prefs.getInt(_kThemeModePref);
  evetaThemeMode.value = switch (i) {
    1 => ThemeMode.light,
    2 => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

Future<void> setEvetaThemeMode(ThemeMode mode) async {
  evetaThemeMode.value = mode;
  final prefs = await SharedPreferences.getInstance();
  final stored = switch (mode) {
    ThemeMode.light => 1,
    ThemeMode.dark => 2,
    _ => 0,
  };
  await prefs.setInt(_kThemeModePref, stored);
}
