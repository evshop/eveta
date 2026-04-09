import 'package:flutter/material.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';

/// Contenedor hero para carruseles o promos (degradado sutil + borde).
class EvetaPromoBannerShell extends StatelessWidget {
  const EvetaPromoBannerShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(EvetaShopDimens.spaceLg, 0, EvetaShopDimens.spaceLg, EvetaShopDimens.spaceLg),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: padding,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(EvetaShopDimens.radiusXl),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    scheme.surfaceContainerHigh,
                    scheme.surfaceContainer,
                  ]
                : [
                    scheme.primaryContainer.withValues(alpha: 0.45),
                    scheme.surfaceContainerHighest,
                  ],
          ),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
          boxShadow: isDark ? EvetaShopDimens.cardShadowDark(context) : EvetaShopDimens.cardShadowLight(context),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
