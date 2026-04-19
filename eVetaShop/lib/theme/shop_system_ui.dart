import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:eveta/theme/eveta_shop_theme.dart';
import 'package:eveta/theme/eveta_theme_controller.dart';

/// Resuelve el [ColorScheme] de la tienda según [evetaThemeMode] y el brillo del sistema.
/// Top-level (evita problemas raros de hot reload con métodos estáticos en `abstract final class`).
ColorScheme evetaResolvedShopColorScheme() {
  final mode = evetaThemeMode.value;
  final platformBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  final useDark =
      mode == ThemeMode.dark || (mode == ThemeMode.system && platformBrightness == Brightness.dark);
  return useDark ? EvetaShopTheme.dark().colorScheme : EvetaShopTheme.light().colorScheme;
}

/// Barras del sistema alineadas al navbar inferior (`surfaceContainerHighest`).
SystemUiOverlayStyle evetaShopShellOverlayStyle([ColorScheme? scheme]) {
  final s = scheme ?? evetaResolvedShopColorScheme();
  final isDark = s.brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: s.surfaceContainerHighest,
    systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );
}
