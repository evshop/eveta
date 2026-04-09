import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';

class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final base = dark ? scheme.surfaceContainerHigh : scheme.surfaceContainerHighest;
    final hi = dark ? scheme.surfaceContainerHighest : scheme.surfaceContainerHigh;
    final fill = scheme.surfaceContainerHighest;

    return Container(
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: scheme.outline.withValues(alpha: dark ? 0.35 : 0.45), width: 0.5),
        borderRadius: BorderRadius.circular(EvetaShopDimens.radiusLg),
        boxShadow: dark ? null : EvetaShopDimens.cardShadowLight(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: hi,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 138,
              width: double.infinity,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(EvetaShopDimens.radiusLg)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 14,
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: MediaQuery.sizeOf(context).width * 0.25,
                    height: 14,
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 80,
                    height: 18,
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 60,
                    height: 12,
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
