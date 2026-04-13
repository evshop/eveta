import 'package:flutter/material.dart';

import 'portal_tokens.dart';

/// Tarjeta con sombra suave y bordes redondeados (claro / oscuro).
class PortalSoftCard extends StatelessWidget {
  const PortalSoftCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.radius = PortalTokens.radiusXl,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final bg = scheme.surfaceContainerHighest;
    final shadow = isDark ? PortalTokens.softShadowDark(scheme) : PortalTokens.softShadowLight(scheme);

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow,
        border: Border.all(color: scheme.outline.withValues(alpha: isDark ? 0.12 : 0.08)),
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        splashColor: scheme.primary.withValues(alpha: 0.12),
        highlightColor: scheme.primary.withValues(alpha: 0.06),
        child: content,
      ),
    );
  }
}
