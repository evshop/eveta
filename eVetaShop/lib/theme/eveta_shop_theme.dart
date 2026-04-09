import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Identidad eVeta: verde acento (#22C55E) solo en CTAs, precios destacados y estados activos.
/// Superficies neutras premium (light/dark) — sin verde dominante.
abstract final class EvetaShopColors {
  static const Color brand = Color(0xFF22C55E);
  /// Mismo acento en oscuro; evitamos variantes neón.
  static const Color brandDarkMode = Color(0xFF22C55E);

  static const Color lightScaffold = Color(0xFFF7F8FA);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE8EAF0);
  static const Color lightText = Color(0xFF111827);
  static const Color lightTextMuted = Color(0xFF6B7280);

  static const Color darkScaffold = Color(0xFF111318);
  static const Color darkCard = Color(0xFF1A1D24);
  static const Color darkCardElevated = Color(0xFF1C2028);
  static const Color darkBorder = Color(0xFF2A2F3A);
  static const Color darkText = Color(0xFFF5F5F5);
  static const Color darkTextMuted = Color(0xFFA6AAB4);
}

/// Radios, sombras y espaciado base del rediseño marketplace.
abstract final class EvetaShopDimens {
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 24;

  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 20;
  static const double space2xl = 24;

  static List<BoxShadow> cardShadowLight(BuildContext context) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> cardShadowDark(BuildContext context) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.28),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
}

abstract final class EvetaShopTheme {
  static ThemeData light() {
    const brand = EvetaShopColors.brand;
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: brand,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFD1FAE5),
      onPrimaryContainer: const Color(0xFF064E3B),
      secondary: EvetaShopColors.lightTextMuted,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFE5E7EB),
      onSecondaryContainer: EvetaShopColors.lightText,
      tertiary: const Color(0xFFEA580C),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFFFEDD5),
      onTertiaryContainer: const Color(0xFF7C2D12),
      error: const Color(0xFFDC2626),
      onError: Colors.white,
      surface: EvetaShopColors.lightScaffold,
      onSurface: EvetaShopColors.lightText,
      onSurfaceVariant: EvetaShopColors.lightTextMuted,
      outline: EvetaShopColors.lightBorder,
      outlineVariant: const Color(0xFFF0F2F6),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: EvetaShopColors.darkScaffold,
      onInverseSurface: EvetaShopColors.darkText,
      inversePrimary: brand,
      surfaceTint: Colors.transparent,
      surfaceContainerHighest: EvetaShopColors.lightCard,
      surfaceContainerHigh: const Color(0xFFF0F2F5),
      surfaceContainer: const Color(0xFFECEFF3),
      surfaceContainerLow: const Color(0xFFE8EBF0),
      surfaceBright: Colors.white,
      surfaceDim: const Color(0xFFE2E5EA),
    );

    return _base(scheme, Brightness.light);
  }

  static ThemeData dark() {
    const brand = EvetaShopColors.brandDarkMode;
    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: brand,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF14532D),
      onPrimaryContainer: const Color(0xFFBBF7D0),
      secondary: EvetaShopColors.darkTextMuted,
      onSecondary: EvetaShopColors.darkScaffold,
      secondaryContainer: EvetaShopColors.darkCardElevated,
      onSecondaryContainer: EvetaShopColors.darkText,
      tertiary: const Color(0xFFFDBA74),
      onTertiary: const Color(0xFF431407),
      tertiaryContainer: const Color(0xFF7C2D12),
      onTertiaryContainer: const Color(0xFFFFEDD5),
      error: const Color(0xFFF87171),
      onError: const Color(0xFF450A0A),
      surface: EvetaShopColors.darkScaffold,
      onSurface: EvetaShopColors.darkText,
      onSurfaceVariant: EvetaShopColors.darkTextMuted,
      outline: EvetaShopColors.darkBorder,
      outlineVariant: const Color(0xFF232830),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: const Color(0xFFE5E7EB),
      onInverseSurface: const Color(0xFF111318),
      inversePrimary: brand,
      surfaceTint: Colors.transparent,
      surfaceContainerHighest: EvetaShopColors.darkCardElevated,
      surfaceContainerHigh: EvetaShopColors.darkCard,
      surfaceContainer: const Color(0xFF151820),
      surfaceContainerLow: const Color(0xFF12151C),
      surfaceBright: const Color(0xFF2A3038),
      surfaceDim: const Color(0xFF0F1115),
    );

    return _base(scheme, Brightness.dark);
  }

  static ThemeData _base(ColorScheme scheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EvetaShopDimens.radiusLg),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(EvetaShopDimens.radiusXl),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(EvetaShopDimens.radiusXl),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.55)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(EvetaShopDimens.radiusXl),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: EvetaShopDimens.spaceLg, vertical: EvetaShopDimens.spaceMd),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.72), fontSize: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EvetaShopDimens.radiusLg),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EvetaShopDimens.radiusLg),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EvetaShopDimens.radiusLg),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(EvetaShopDimens.radiusXl)),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outline.withValues(alpha: 0.4), thickness: 1),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          color: scheme.onSurface,
          height: 1.15,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.35,
          color: scheme.onSurface,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.35, color: scheme.onSurface),
        bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: scheme.onSurfaceVariant),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.primary),
      ),
    );
  }
}
