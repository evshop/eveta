import 'package:flutter/material.dart';

/// Cabecera fija (pinned) para pantallas tipo categorías / inicio: título, buscador y chips.
class StickyCategoryHeader extends SliverPersistentHeaderDelegate {
  StickyCategoryHeader({
    required this.minHeight,
    required this.maxHeight,
    required this.backgroundColor,
    required this.borderColor,
    required this.builder,
  });

  final double minHeight;
  final double maxHeight;
  final Color backgroundColor;
  final Color borderColor;
  final Widget Function(BuildContext context, double progress) builder;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final showDivider = overlapsContent || shrinkOffset > 0.5;
    final range = (maxExtent - minExtent).abs();
    final progress = range <= 0.001 ? 0.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    return Material(
      color: backgroundColor,
      elevation: showDivider ? 0.5 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: showDivider ? borderColor : Colors.transparent,
              width: 1,
            ),
          ),
        ),
        child: SizedBox(
          height: maxExtent,
          width: double.infinity,
          child: builder(context, progress),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant StickyCategoryHeader oldDelegate) {
    // El [builder] no forma parte de la igualdad: sin esto, chips/filtros no se
    // repintan cuando cambia el estado pero extent/colores siguen iguales.
    return true;
  }
}
