import 'package:flutter/material.dart';
import 'package:eveta/common_widget/eveta_glass_pill.dart';

/// Indicador estilo iOS: cápsula glass compacta; cada slide es un **punto** que al activarse
/// **se expande** a barra con progreso y al terminar / cambiar vuelve a **círculo**.
class EvetaCarouselSegmentIndicator extends StatefulWidget {
  const EvetaCarouselSegmentIndicator({
    super.key,
    required this.count,
    required this.selectedIndex,
    required this.progressController,
    /// Fracción del ancho de pantalla (0.25–0.35). Por defecto 0.28.
    this.maxWidthFraction = 0.28,
  });

  final int count;
  final int selectedIndex;
  final AnimationController progressController;

  /// Límite superior de ancho respecto al ancho de pantalla (p. ej. 0.32 ≈ 32%).
  final double maxWidthFraction;

  /// Punto inactivo (diámetro) y barra activa expandida; grosor = diámetro del punto.
  static const double _dotDiameter = 6.5;
  static const double _activeBarWidth = 20;
  static const double _gapBetweenSegments = 4;

  @override
  State<EvetaCarouselSegmentIndicator> createState() => _EvetaCarouselSegmentIndicatorState();
}

class _EvetaCarouselSegmentIndicatorState extends State<EvetaCarouselSegmentIndicator> {
  late final CurvedAnimation _curvedProgress;

  @override
  void initState() {
    super.initState();
    _curvedProgress = CurvedAnimation(
      parent: widget.progressController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _curvedProgress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = isDark ? _GlassPalette.dark : _GlassPalette.light;
    final screenW = MediaQuery.sizeOf(context).width;
    final maxCapsuleW = screenW * widget.maxWidthFraction.clamp(0.25, 0.35);

    final capsule = _GlassCapsule(
      palette: p,
      curvedProgress: _curvedProgress,
      count: widget.count,
      selectedIndex: widget.selectedIndex,
    );

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxCapsuleW),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: capsule,
        ),
      ),
    );
  }
}

class _GlassCapsule extends StatelessWidget {
  const _GlassCapsule({
    required this.palette,
    required this.curvedProgress,
    required this.count,
    required this.selectedIndex,
  });

  final _GlassPalette palette;
  final CurvedAnimation curvedProgress;
  final int count;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final bars = <Widget>[];
    for (var i = 0; i < count; i++) {
      if (i > 0) {
        bars.add(SizedBox(width: EvetaCarouselSegmentIndicator._gapBetweenSegments));
      }
      final isActive = selectedIndex == i;
      bars.add(
        _SegmentDotOrBar(
          isActive: isActive,
          curvedProgress: curvedProgress,
          inactiveColor: palette.inactiveBar,
          trackColor: palette.activeTrack,
          fillColor: palette.activeFill,
        ),
      );
    }

    return EvetaGlassPill(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: bars,
      ),
    );
  }
}

class _GlassPalette {
  const _GlassPalette({
    required this.inactiveBar,
    required this.activeTrack,
    required this.activeFill,
  });

  final Color inactiveBar;
  final Color activeTrack;
  final Color activeFill;

  static final _GlassPalette dark = _GlassPalette(
    inactiveBar: Colors.white.withValues(alpha: 0.32),
    activeTrack: Colors.white.withValues(alpha: 0.16),
    activeFill: const Color(0xFFF2F2F7),
  );

  /// Misma lectura que en oscuro: track suave + relleno oscuro (sin verde).
  static final _GlassPalette light = _GlassPalette(
    inactiveBar: const Color(0xFF8E8E93).withValues(alpha: 0.34),
    activeTrack: Colors.black.withValues(alpha: 0.14),
    activeFill: const Color(0xFF000000),
  );
}

/// Inactivo: círculo. Activo: se ensancha a pastilla con llenado horizontal; al desactivarse vuelve a círculo.
class _SegmentDotOrBar extends StatelessWidget {
  const _SegmentDotOrBar({
    required this.isActive,
    required this.curvedProgress,
    required this.inactiveColor,
    required this.trackColor,
    required this.fillColor,
  });

  final bool isActive;
  final Animation<double> curvedProgress;
  final Color inactiveColor;
  final Color trackColor;
  final Color fillColor;

  static const Duration _expandDuration = Duration(milliseconds: 340);
  static const Curve _expandCurve = Curves.easeInOutCubic;

  @override
  Widget build(BuildContext context) {
    final d = EvetaCarouselSegmentIndicator._dotDiameter;
    final wBar = EvetaCarouselSegmentIndicator._activeBarWidth;

    return AnimatedContainer(
      duration: _expandDuration,
      curve: _expandCurve,
      width: isActive ? wBar : d,
      height: d,
      clipBehavior: isActive ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: isActive ? trackColor : inactiveColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: isActive
          ? AnimatedBuilder(
              animation: curvedProgress,
              builder: (context, child) {
                final t = curvedProgress.value.clamp(0.0, 1.0);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: t,
                      heightFactor: 1,
                      child: ColoredBox(color: fillColor),
                    ),
                  ),
                );
              },
            )
          : null,
    );
  }
}
