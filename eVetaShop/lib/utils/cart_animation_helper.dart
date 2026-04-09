import 'package:flutter/material.dart';

class CartAnimationHelper {
  static void runFlyToCartAnimation({
    required BuildContext context,
    required GlobalKey sourceKey,
    required GlobalKey destKey,
    required Widget child,
    void Function()? onAnimationComplete,
  }) {
    final OverlayState overlayState = Overlay.of(context);
    
    final RenderObject? sourceObject = sourceKey.currentContext?.findRenderObject();
    if (sourceObject is! RenderBox) return;
    final Offset sourceOffset = sourceObject.localToGlobal(Offset.zero);
    final Size sourceSize = sourceObject.size;

    final RenderObject? destObject = destKey.currentContext?.findRenderObject();
    if (destObject is! RenderBox) return;
    final Offset destOffset = destObject.localToGlobal(Offset.zero);
    final Size destSize = destObject.size;

    final double destCenterX = destOffset.dx + destSize.width / 2;
    final double destCenterY = destOffset.dy + destSize.height / 2;
    final double sourceCenterX = sourceOffset.dx + sourceSize.width / 2;
    final double sourceCenterY = sourceOffset.dy + sourceSize.height / 2;

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return _ThreePhaseAnimation(
          sourceCenterX: sourceCenterX,
          sourceCenterY: sourceCenterY,
          sourceSize: sourceSize,
          destCenterX: destCenterX,
          destCenterY: destCenterY,
          child: child,
          onComplete: () {
            overlayEntry.remove();
            if (onAnimationComplete != null) onAnimationComplete();
          },
        );
      },
    );

    overlayState.insert(overlayEntry);
  }
}

class _ThreePhaseAnimation extends StatefulWidget {
  final double sourceCenterX;
  final double sourceCenterY;
  final Size sourceSize;
  final double destCenterX;
  final double destCenterY;
  final Widget child;
  final VoidCallback onComplete;

  const _ThreePhaseAnimation({
    required this.sourceCenterX,
    required this.sourceCenterY,
    required this.sourceSize,
    required this.destCenterX,
    required this.destCenterY,
    required this.child,
    required this.onComplete,
  });

  @override
  State<_ThreePhaseAnimation> createState() => _ThreePhaseAnimationState();
}

class _ThreePhaseAnimationState extends State<_ThreePhaseAnimation> with TickerProviderStateMixin {
  // Phase 1: Shrink from full size to thumbnail
  late AnimationController _shrinkController;
  late Animation<double> _shrinkSize;

  // Phase 2: Bounce in place
  late AnimationController _bounceController;
  late Animation<double> _bounceScale;

  // Phase 3: Fly to cart
  late AnimationController _flyController;
  late Animation<double> _flyProgress;

  static const double _thumbSize = 55.0;

  int _currentPhase = 1; // 1 = shrink, 2 = bounce, 3 = fly

  @override
  void initState() {
    super.initState();

    // --- Phase 1: Shrink from source size to thumbnail ---
    // Duration scales with source size: bigger image = more time to shrink
    final double startSize = widget.sourceSize.width < widget.sourceSize.height
        ? widget.sourceSize.width
        : widget.sourceSize.height;
    final int shrinkMs = (300 + (startSize / 400 * 500)).clamp(400, 900).toInt();

    _shrinkController = AnimationController(
      duration: Duration(milliseconds: shrinkMs),
      vsync: this,
    );

    _shrinkSize = Tween<double>(
      begin: startSize.clamp(_thumbSize, 500),
      end: _thumbSize,
    ).chain(CurveTween(curve: Curves.easeInOutCubic)).animate(_shrinkController);

    // --- Phase 2: Bounce ---
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _bounceScale = TweenSequence<double>([
      // Squish down
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.7).chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
      // Spring up
      TweenSequenceItem(
        tween: Tween(begin: 0.7, end: 1.15).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      // Settle
      TweenSequenceItem(
        tween: Tween(begin: 1.15, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
    ]).animate(_bounceController);

    // --- Phase 3: Fly ---
    _flyController = AnimationController(
      duration: const Duration(milliseconds: 650),
      vsync: this,
    );

    _flyProgress = CurvedAnimation(
      parent: _flyController,
      curve: Curves.easeInOutCubic,
    );

    // Chain: Phase 1 → Phase 2 → Phase 3
    _shrinkController.forward().then((_) {
      if (!mounted) return;
      setState(() => _currentPhase = 2);
      _bounceController.forward().then((_) {
        if (!mounted) return;
        setState(() => _currentPhase = 3);
        _flyController.forward().then((_) => widget.onComplete());
      });
    });
  }

  @override
  void dispose() {
    _shrinkController.dispose();
    _bounceController.dispose();
    _flyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_shrinkController, _bounceController, _flyController]),
      builder: (context, child) {
        double size;
        double cx = widget.sourceCenterX;
        double cy = widget.sourceCenterY;
        double opacity = 1.0;

        if (_currentPhase == 1) {
          // Phase 1: Shrinking in place
          size = _shrinkSize.value;
        } else if (_currentPhase == 2) {
          // Phase 2: Bounce at thumbnail size
          size = _thumbSize * _bounceScale.value;
        } else {
          // Phase 3: Fly to cart
          final double t = _flyProgress.value;

          // Shrink further while flying
          size = _thumbSize * (1.0 - t * 0.85); // 55 → ~8

          // Move from source center to dest center
          cx = widget.sourceCenterX + (widget.destCenterX - widget.sourceCenterX) * t;
          cy = widget.sourceCenterY + (widget.destCenterY - widget.sourceCenterY) * t;

          // Parabolic arc
          cy += -120 * (4 * t * (1 - t));

          // Fade at the end
          if (t > 0.8) {
            opacity = 1.0 - (t - 0.8) / 0.2;
          }
        }

        final double left = cx - size / 2;
        final double top = cy - size / 2;

        return Positioned(
          left: left,
          top: top,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: size.clamp(1.0, 500.0),
                  height: size.clamp(1.0, 500.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15 * opacity),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
