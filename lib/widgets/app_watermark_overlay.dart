// Signature: dev.tswicolly03
import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppWatermarkOverlay extends StatelessWidget {
  const AppWatermarkOverlay({
    super.key,
    this.brand = 'VEREDRA',
    this.signature = 'dev.tswicolly03',
  });

  final String brand;
  final String signature;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color color = isDark
        ? const Color.fromRGBO(236, 217, 183, 0.045)
        : const Color.fromRGBO(67, 47, 22, 0.052);

    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _AppWatermarkPainter(
            label: '$brand · $signature',
            color: color,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _AppWatermarkPainter extends CustomPainter {
  const _AppWatermarkPainter({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double xStep = textPainter.width + 160;
    final double yStep = textPainter.height + 140;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-math.pi / 9);
    canvas.translate(-size.width / 2, -size.height / 2);

    int rowIndex = 0;
    for (double y = -size.height * 0.35;
        y < size.height * 1.35;
        y += yStep, rowIndex++) {
      final double rowOffset = rowIndex.isEven ? -80 : xStep / 2;
      for (double x = -size.width * 0.35 + rowOffset;
          x < size.width * 1.35;
          x += xStep) {
        textPainter.paint(canvas, Offset(x, y));
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AppWatermarkPainter oldDelegate) {
    return oldDelegate.label != label || oldDelegate.color != color;
  }
}
