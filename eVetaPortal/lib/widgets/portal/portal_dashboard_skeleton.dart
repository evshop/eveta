import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'portal_tokens.dart';

class PortalDashboardSkeleton extends StatelessWidget {
  const PortalDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHigh;
    final bone = scheme.onSurface.withValues(alpha: 0.06);

    Widget box(double h, {double? w}) {
      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: bone,
          borderRadius: BorderRadius.circular(PortalTokens.radiusLg),
        ),
      );
    }

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: scheme.surfaceContainerHighest,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(PortalTokens.space2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            box(28, w: 200),
            const SizedBox(height: PortalTokens.space2),
            Row(
              children: [
                Expanded(child: box(120)),
                const SizedBox(width: PortalTokens.space2),
                Expanded(child: box(120)),
              ],
            ),
            const SizedBox(height: PortalTokens.space2),
            Row(
              children: [
                Expanded(child: box(120)),
                const SizedBox(width: PortalTokens.space2),
                Expanded(child: box(120)),
              ],
            ),
            const SizedBox(height: PortalTokens.space3),
            box(200),
            const SizedBox(height: PortalTokens.space3),
            box(24, w: 160),
            const SizedBox(height: PortalTokens.space2),
            box(88),
            const SizedBox(height: PortalTokens.space1),
            box(88),
            const SizedBox(height: PortalTokens.space1),
            box(88),
          ],
        ),
      ),
    );
  }
}
