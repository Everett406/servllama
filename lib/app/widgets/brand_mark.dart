import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';

/// The app's identity mark: a soft eight-armed burst in the brand orange.
///
/// Drawn rather than shipped as an asset so it stays crisp at any size and
/// takes its colour from the theme. The arms are rounded capsules of
/// differing lengths — even lengths would read as a gear, which is the
/// wrong association for something that runs models.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 22, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BurstPainter(color ?? ClaudeColors.accent),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  const _BurstPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..color = color;

    // Arms alternate long/short so the silhouette is a burst, not a gear.
    const armPattern = [1.0, 0.52, 0.86, 0.52, 1.0, 0.52, 0.86, 0.52];
    final maxReach = size.width / 2;
    final stroke = size.width * 0.155;

    for (var i = 0; i < armPattern.length; i++) {
      final reach = maxReach * armPattern[i];
      final angle = (math.pi * 2 / armPattern.length) * i - math.pi / 2;
      final end = center + Offset(math.cos(angle), math.sin(angle)) * reach;
      canvas.drawLine(
        center,
        end,
        paint
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Wordmark: the burst plus the product name. The name is set in the display
/// serif because that pairing is the clearest signal this is a considered
/// wordmark rather than a default app-bar title.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.size = 22, this.showName = true});

  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final mark = BrandMark(size: size);
    if (!showName) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.42),
        Text(
          'ServLlama',
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: size * 0.78,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: context.ink,
          ),
        ),
      ],
    );
  }
}
