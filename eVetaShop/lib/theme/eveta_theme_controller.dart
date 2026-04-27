import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Control global del [ThemeMode] de la app (sistema / claro / oscuro).
final ValueNotifier<ThemeMode> evetaThemeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

const String _kThemeModePrefKey = 'eveta_theme_mode';

Future<void> initEvetaThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kThemeModePrefKey);
  evetaThemeMode.value = switch (raw) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

Future<void> setEvetaThemeMode(ThemeMode mode) async {
  evetaThemeMode.value = mode;
  final prefs = await SharedPreferences.getInstance();
  final raw = switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    _ => 'system',
  };
  await prefs.setString(_kThemeModePrefKey, raw);
}
