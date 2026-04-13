import 'package:flutter/material.dart';

/// Espaciado (grid 8px) y radios para eVeta Portal (estilo iOS + M3).
abstract final class PortalTokens {
  static const double space1 = 8;
  static const double space2 = 16;
  static const double space3 = 24;
  static const double space4 = 32;

  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 24;
  static const double radius2xl = 28;

  static const Duration motionFast = Duration(milliseconds: 200);
  static const Duration motionNormal = Duration(milliseconds: 280);

  static List<BoxShadow> softShadowLight(ColorScheme scheme) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 24,
          offset: const Offset(0, 10),
          spreadRadius: -4,
        ),
      ];

  static List<BoxShadow> softShadowDark(ColorScheme scheme) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 28,
          offset: const Offset(0, 12),
          spreadRadius: -6,
        ),
      ];
}
