import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';

/// Vela's mark: a speech balloon knocked out of a clay tile.
///
/// The same geometry as the launcher icon, drawn rather than shipped as an
/// asset so it stays crisp at any size and picks up the theme's accent
/// instead of carrying a baked-in colour.
///
/// The balloon is a real hole, not a shape in a second colour. Anything
/// behind the mark shows through it — which is the whole conceit, and also
/// why the empty state uses a muted tint rather than the full accent: at
/// full strength the hole competes with the message.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 22, this.color, this.tiled = true});

  final double size;
  final Color? color;
  final bool tiled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BalloonMarkPainter(
          color ?? ClaudeColors.accent,
          tiled: tiled,
          punchColor: context.canvas,
        ),
      ),
    );
  }
}

class _BalloonMarkPainter extends CustomPainter {
  const _BalloonMarkPainter(
    this.color, {
    required this.tiled,
    required this.punchColor,
  });

  final Color color;
  final bool tiled;

  /// Only consulted for [tiled] marks, where a composited copy of the mark
  /// is punched out. An untiled mark draws the balloon on its own.
  final Color punchColor;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    final balloon = _balloonPath(unit);

    if (!tiled) {
      canvas.drawPath(
        balloon,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * 0.085
          ..strokeJoin = StrokeJoin.round,
      );
      return;
    }

    // Clear has to act on a composited layer, otherwise it erases whatever
    // the canvas already had rather than the tile we just drew.
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(unit * 0.2227),
      ),
      Paint()..color = color,
    );
    canvas.drawPath(balloon, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
  }

  /// Proportions match the launcher icon exactly, so the in-app mark and
  /// the icon on the home screen are the same drawing at two sizes.
  static ui.Path _balloonPath(double unit) {
    final body = ui.Path()
      ..addRRect(
        ui.RRect.fromRectAndRadius(
          Rect.fromLTRB(unit * 0.245, unit * 0.275, unit * 0.755, unit * 0.575),
          Radius.circular(unit * 0.072),
        ),
      );

    // The tail's base sits on the balloon's bottom edge rather than inside
    // its corner arc: inside the arc, the rounding eats the width and the
    // tail comes out as a spike.
    body
      ..moveTo(unit * 0.382, unit * 0.575)
      ..lineTo(unit * 0.548, unit * 0.575)
      ..lineTo(unit * 0.452, unit * 0.668)
      ..close();
    return body;
  }

  @override
  bool shouldRepaint(_BalloonMarkPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.tiled != tiled ||
      oldDelegate.punchColor != punchColor;
}

/// Wordmark: the mark plus the product name.
///
/// Set in the display serif, because a hand-drawn balloon next to the app's
/// default sans reads as a mismatched pair; a serif name gives the lockup a
/// spine and stops it looking like a default app-bar title with a glyph
/// stuck in front.
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
          'Vela',
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: size * 0.82,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: context.ink,
          ),
        ),
      ],
    );
  }
}
