import 'package:flutter/material.dart';

class Categoriadart extends StatefulWidget {
  const Categoriadart({
    super.key,
    this.width,
    this.height,
  });

  final double? width;
  final double? height;

  @override
  State<Categoriadart> createState() => CategoriadartState();
}

class CategoriadartState extends State<Categoriadart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = (widget.width ?? widget.height ?? 30).clamp(22.0, 38.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stroke = isDark ? Colors.white : Colors.black;
    final fillA = isDark ? Colors.white.withValues(alpha: 0.95) : Colors.black;
    const fillB = Colors.transparent;

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(_controller.value);
        final u = size * 0.41;
        final g = size * 0.07;
        final x2 = u + g;
        final y2 = u + g;

        Widget tile({
          required double w,
          required double h,
          required double left,
          required double top,
          required Color color,
        }) {
          return Positioned(
            left: left,
            top: top,
            child: Container(
              width: w,
              height: h,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(size * 0.11),
                border: Border.all(color: stroke, width: 1.8),
              ),
            ),
          );
        }

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              tile(
                w: u,
                h: u,
                left: 0,
                top: 0,
                color: Color.lerp(fillB, fillA, t)!,
              ),
              tile(
                w: u,
                h: u * 0.54,
                left: x2,
                top: 0,
                color: Color.lerp(fillA, fillB, t)!,
              ),
              tile(
                w: u,
                h: u * 0.54,
                left: 0,
                top: y2,
                color: Color.lerp(fillA, fillB, t)!,
              ),
              tile(
                w: u,
                h: u,
                left: x2,
                top: y2,
                color: Color.lerp(fillB, fillA, 1 - t)!,
              ),
            ],
          ),
        );
      },
    );
  }
}
