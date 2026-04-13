import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'portal_soft_card.dart';
import 'portal_tokens.dart';

/// Gráfico de barras simple (sin dependencias extra).
class PortalSalesChart extends StatelessWidget {
  const PortalSalesChart({
    super.key,
    required this.labels,
    required this.values,
  });

  final List<String> labels;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxV = values.isEmpty ? 1.0 : values.reduce(math.max);
    final norm = maxV <= 0 ? 1.0 : maxV;

    return PortalSoftCard(
      padding: const EdgeInsets.all(PortalTokens.space2),
      radius: PortalTokens.radius2xl,
      child: SizedBox(
        height: 200,
        child: CustomPaint(
          painter: _BarsPainter(
            labels: labels,
            values: values,
            norm: norm,
            primary: scheme.primary,
            muted: scheme.onSurfaceVariant.withValues(alpha: 0.35),
            labelColor: scheme.onSurfaceVariant,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.labels,
    required this.values,
    required this.norm,
    required this.primary,
    required this.muted,
    required this.labelColor,
  });

  final List<String> labels;
  final List<double> values;
  final double norm;
  final Color primary;
  final Color muted;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final n = math.max(labels.length, values.length);
    if (n == 0) return;

    final chartH = size.height - 28;
    final gap = 6.0;
    final barW = (size.width - gap * (n + 1)) / n;

    for (var i = 0; i < n; i++) {
      final x = gap + i * (barW + gap);
      final v = i < values.length ? values[i] : 0.0;
      final h = chartH * (v / norm).clamp(0.04, 1.0);
      final y = chartH - h;

      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barW, h),
        const Radius.circular(8),
      );
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            primary.withValues(alpha: 0.55),
            primary.withValues(alpha: 0.95),
          ],
        ).createShader(Rect.fromLTWH(x, y, barW, h));
      canvas.drawRRect(r, paint);

      final tp = TextPainter(
        text: TextSpan(
          text: i < labels.length ? labels[i] : '',
          style: TextStyle(color: labelColor, fontSize: 10, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: barW + gap);
      tp.paint(canvas, Offset(x + (barW - tp.width) / 2, chartH + 6));
    }

    // Línea base
    final base = Paint()
      ..color = muted
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, chartH), Offset(size.width, chartH), base);
  }

  @override
  bool shouldRepaint(covariant _BarsPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.labels != labels || oldDelegate.norm != norm;
  }
}
