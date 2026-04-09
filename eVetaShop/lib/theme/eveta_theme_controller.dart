import 'package:flutter/material.dart';

/// Control global del [ThemeMode] de la app (sistema / claro / oscuro).
final ValueNotifier<ThemeMode> evetaThemeMode = ValueNotifier<ThemeMode>(ThemeMode.system);
