import 'package:flutter/material.dart';

/// Tokens y temas del panel eVeta Admin (estilo SaaS / iOS).
abstract final class AdminTokens {
  static const Color brand = Color(0xFF3B82F6);
  static const Color accent = Color(0xFF22C55E);
  static const Color softDanger = Color(0xFFF87171);
  static const Color canvas = Color(0xFFF5F7FB);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color darkCanvas = Color(0xFF0F0F0F);
  static const Color darkSurface = Color(0xFF1A1A1C);
  static const Color darkElevated = Color(0xFF242428);
  static const double radiusSm = 14;
  static const double radiusMd = 18;
  static const double radiusLg = 24;
  static const double sidebarWidth = 260;
}

ThemeData buildAdminLightTheme() {
  const seed = AdminTokens.brand;
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
    surface: AdminTokens.canvas,
    surfaceContainerHighest: AdminTokens.pureWhite,
    secondary: const Color(0xFF7DD3FC),
    tertiary: const Color(0xFF86EFAC),
    error: AdminTokens.softDanger,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Inter',
    colorScheme: scheme,
    scaffoldBackgroundColor: AdminTokens.canvas,
    dividerColor: scheme.outline.withValues(alpha: 0.12),
    splashFactory: InkRipple.splashFactory,
    textTheme: Typography.blackMountainView.copyWith(
      titleLarge: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.4),
      titleMedium: const TextStyle(fontWeight: FontWeight.w700),
      bodyMedium: TextStyle(
        color: scheme.onSurface.withValues(alpha: 0.9),
        height: 1.4,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
    ),
    cardTheme: CardThemeData(
      elevation: 0.4,
      shadowColor: const Color(0xFF0B17361A),
      color: AdminTokens.pureWhite,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AdminTokens.radiusLg)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.92),
      elevation: 0,
      indicatorColor: seed.withValues(alpha: 0.14),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: seed.withValues(alpha: 0.14),
      selectedIconTheme: const IconThemeData(color: seed),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      selectedLabelTextStyle: const TextStyle(
        color: seed,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        backgroundColor: seed,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AdminTokens.radiusSm)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.2),
      ).copyWith(
        overlayColor: WidgetStatePropertyAll(seed.withValues(alpha: 0.08)),
        elevation: const WidgetStatePropertyAll(0),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AdminTokens.radiusSm)),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
      ).copyWith(
        overlayColor: WidgetStatePropertyAll(seed.withValues(alpha: 0.05)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: scheme.onSurfaceVariant,
        hoverColor: seed.withValues(alpha: 0.07),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AdminTokens.radiusSm)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
        borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.28)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
        borderSide: const BorderSide(color: seed, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
        borderSide: BorderSide(color: scheme.error),
      ),
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
    ),
    dataTableTheme: DataTableThemeData(
      dividerThickness: 0.7,
      headingTextStyle: TextStyle(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      dataTextStyle: TextStyle(
        color: scheme.onSurface.withValues(alpha: 0.95),
        fontWeight: FontWeight.w500,
      ),
      headingRowColor: WidgetStatePropertyAll(scheme.surface.withValues(alpha: 0.75)),
      dataRowColor: WidgetStatePropertyAll(AdminTokens.pureWhite),
      horizontalMargin: 16,
      columnSpacing: 16,
    ),
  );
}

ThemeData buildAdminDarkTheme() {
  const seed = AdminTokens.brand;
  final scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: seed,
    onPrimary: Colors.black,
    primaryContainer: seed.withValues(alpha: 0.22),
    onPrimaryContainer: Colors.white,
    secondary: const Color(0xFF8E8E93),
    onSecondary: Colors.black,
    secondaryContainer: const Color(0xFF2C2C2E),
    onSecondaryContainer: Colors.white,
    tertiary: seed,
    onTertiary: Colors.black,
    error: const Color(0xFFFF6B6B),
    onError: Colors.black,
    surface: AdminTokens.darkCanvas,
    onSurface: const Color(0xFFF2F2F7),
    surfaceContainerHighest: AdminTokens.darkElevated,
    onSurfaceVariant: const Color(0xFFAEAEB2),
    outline: const Color(0xFF3A3A3C),
    outlineVariant: const Color(0xFF48484A),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Colors.white,
    onInverseSurface: Colors.black,
    inversePrimary: seed,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Inter',
    colorScheme: scheme,
    scaffoldBackgroundColor: AdminTokens.darkCanvas,
    dividerColor: scheme.outline.withValues(alpha: 0.35),
    splashFactory: InkSparkle.splashFactory,
    cardTheme: CardThemeData(
      elevation: 0,
      color: AdminTokens.darkSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.45)),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AdminTokens.darkElevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AdminTokens.radiusLg)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AdminTokens.darkSurface.withValues(alpha: 0.94),
      elevation: 0,
      indicatorColor: seed.withValues(alpha: 0.2),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: seed.withValues(alpha: 0.2),
      selectedIconTheme: const IconThemeData(color: seed),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      selectedLabelTextStyle: const TextStyle(
        color: seed,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AdminTokens.radiusSm)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AdminTokens.radiusSm)),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.6)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AdminTokens.darkElevated,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AdminTokens.radiusSm)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
        borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.55)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
        borderSide: const BorderSide(color: seed, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
        borderSide: BorderSide(color: scheme.error),
      ),
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
    ),
  );
}
