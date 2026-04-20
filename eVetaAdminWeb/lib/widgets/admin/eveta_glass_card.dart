import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/admin_theme.dart';

/// Tarjeta con borde suave y sombra ligera (estilo panel SaaS).
class EvetaGlassCard extends StatelessWidget {
  const EvetaGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.radius = AdminTokens.radiusMd,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = scheme.outline.withValues(alpha: isDark ? 0.45 : 0.1);
    final shadow = Colors.black.withValues(alpha: isDark ? 0.35 : 0.06);

    Widget box = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: scheme.surfaceContainerHighest.withValues(alpha: isDark ? 1 : 1),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: shadow,
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Padding(padding: padding, child: child),
      ),
    );

    if (onTap != null) {
      box = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: box,
        ),
      );
    }

    return box;
  }
}

/// Variante con blur opcional (solo efecto visual ligero en web/desktop).
class EvetaBackdropCard extends StatelessWidget {
  const EvetaBackdropCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = AdminTokens.radiusLg,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.88 : 0.75),
            border: Border.all(
              color: scheme.outline.withValues(alpha: isDark ? 0.4 : 0.12),
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
