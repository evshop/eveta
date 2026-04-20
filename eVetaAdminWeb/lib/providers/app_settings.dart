import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeModeKey = 'eveta_admin_theme_mode';

/// Preferencias globales del panel (tema, etc.).
class AppSettings extends ChangeNotifier {
  AppSettings() {
    _load();
  }

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kThemeModeKey);
    if (raw == 'light') {
      _themeMode = ThemeMode.light;
    } else if (raw == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    switch (_themeMode) {
      case ThemeMode.light:
        await p.setString(_kThemeModeKey, 'light');
        break;
      case ThemeMode.dark:
        await p.setString(_kThemeModeKey, 'dark');
        break;
      case ThemeMode.system:
        await p.remove(_kThemeModeKey);
        break;
    }
  }

  void cycleTheme() {
    if (_themeMode == ThemeMode.system) {
      _themeMode = ThemeMode.light;
    } else if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
    // ignore: unawaited_futures
    _persist();
  }
}
