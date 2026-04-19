import 'dart:ui';

import 'package:flutter/material.dart';

/// Cápsula con vidrio (blur + opacidad) y sombra suave, mismo estilo que el indicador de carrusel.
class EvetaGlassPill extends StatelessWidget {
  const EvetaGlassPill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = isDark ? _GlassShellPalette.dark : _GlassShellPalette.light;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
            spreadRadius: -1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: p.hairlineBorder, width: 0.5),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: p.glassGradient,
              ),
            ),
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassShellPalette {
  const _GlassShellPalette({
    required this.glassGradient,
    required this.hairlineBorder,
  });

  final List<Color> glassGradient;
  final Color hairlineBorder;

  static final _GlassShellPalette dark = _GlassShellPalette(
    glassGradient: [
      Colors.white.withValues(alpha: 0.12),
      Colors.white.withValues(alpha: 0.06),
    ],
    hairlineBorder: Colors.white.withValues(alpha: 0.20),
  );

  static final _GlassShellPalette light = _GlassShellPalette(
    glassGradient: [
      Colors.white.withValues(alpha: 0.78),
      Colors.white.withValues(alpha: 0.58),
    ],
    hairlineBorder: Colors.black.withValues(alpha: 0.05),
  );
}
