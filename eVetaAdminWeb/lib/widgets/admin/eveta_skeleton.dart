import 'dart:math' as math;

import 'package:flutter/material.dart';

class EvetaSkeleton extends StatefulWidget {
  const EvetaSkeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<EvetaSkeleton> createState() => _EvetaSkeletonState();
}

class _EvetaSkeletonState extends State<EvetaSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.onSurface.withValues(alpha: 0.08);
    final hi = scheme.onSurface.withValues(alpha: 0.16);

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value * math.pi * 2;
        final blend = (math.sin(t) + 1) / 2;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              colors: [
                Color.lerp(base, hi, blend)!,
                Color.lerp(hi, base, blend)!,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        );
      },
    );
  }
}

class EvetaMetricCardSkeleton extends StatelessWidget {
  const EvetaMetricCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EvetaSkeleton(width: 120, height: 12, radius: 6),
            const SizedBox(height: 14),
            const EvetaSkeleton(width: 80, height: 28, radius: 8),
            const SizedBox(height: 8),
            EvetaSkeleton(width: double.infinity, height: 10, radius: 6),
          ],
        ),
      ),
    );
  }
}
