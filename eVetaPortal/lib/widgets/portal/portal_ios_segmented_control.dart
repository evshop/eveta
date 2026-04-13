import 'package:flutter/material.dart';

import 'portal_haptics.dart';
import 'portal_tokens.dart';

/// Control segmentado estilo iOS (M3 + animación suave).
class PortalIosSegmentedControl<T> extends StatelessWidget {
  const PortalIosSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<PortalSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final itemW = w / segments.length;
        final idx = segments.indexWhere((s) => s.value == selected);
        final safeIdx = idx < 0 ? 0 : idx;

        return Container(
          height: 40,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(PortalTokens.radiusLg),
            border: Border.all(color: scheme.outline.withValues(alpha: isDark ? 0.2 : 0.12)),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: PortalTokens.motionNormal,
                curve: Curves.easeOutCubic,
                left: safeIdx * itemW + 4,
                top: 4,
                width: itemW - 8,
                bottom: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(PortalTokens.radiusMd),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final seg in segments)
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            portalHapticSelect();
                            onChanged(seg.value);
                          },
                          borderRadius: BorderRadius.circular(PortalTokens.radiusLg),
                          splashColor: scheme.primary.withValues(alpha: 0.1),
                          child: Center(
                            child: Text(
                              seg.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: seg.value == selected ? FontWeight.w700 : FontWeight.w500,
                                color: seg.value == selected ? scheme.onSurface : scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class PortalSegment<T> {
  const PortalSegment({required this.value, required this.label});

  final T value;
  final String label;
}
