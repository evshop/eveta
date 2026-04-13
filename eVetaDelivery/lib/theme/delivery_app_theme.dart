import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tema alineado con eVeta Portal (login y shell).
ThemeData deliveryAppTheme() {
  const brand = Color(0xFF09CB6B);
  final scheme = ColorScheme(
    brightness: Brightness.light,
    primary: brand,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFC8F5DD),
    onPrimaryContainer: const Color(0xFF045C3A),
    secondary: const Color(0xFF636366),
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFE5E7EB),
    onSecondaryContainer: const Color(0xFF1C1C1E),
    tertiary: const Color(0xFFEA580C),
    onTertiary: Colors.white,
    tertiaryContainer: const Color(0xFFFFEDD5),
    onTertiaryContainer: const Color(0xFF7C2D12),
    error: const Color(0xFFDC2626),
    onError: Colors.white,
    surface: const Color(0xFFF7F7F7),
    onSurface: const Color(0xFF1C1C1E),
    onSurfaceVariant: const Color(0xFF636366),
    outline: const Color(0xFFE5E5EA),
    outlineVariant: const Color(0xFFEBEBED),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: const Color(0xFF121212),
    onInverseSurface: Colors.white,
    inversePrimary: brand,
    surfaceTint: Colors.transparent,
    surfaceContainerHighest: Colors.white,
    surfaceContainerHigh: const Color(0xFFEFEFF2),
    surfaceContainer: const Color(0xFFE8E8EC),
    surfaceContainerLow: const Color(0xFFE3E3E8),
    surfaceBright: Colors.white,
    surfaceDim: const Color(0xFFDCDCE0),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: InkRipple.splashFactory,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.65), fontSize: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.85), width: 1.5),
      ),
    ),
  );

  final inter = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  return base.copyWith(
    textTheme: inter.copyWith(
      headlineLarge: inter.headlineLarge?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        height: 1.15,
      ),
    ),
  );
}
