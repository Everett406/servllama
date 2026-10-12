import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Hand-drawn icon set.
///
/// Material's icons are filled and geometric; at the sizes this app uses
/// them read as slightly loud next to the type. Everything here is a single
/// hairline stroke on a 24-unit grid with round caps and joins, which is
/// what lets the composer and the action bar sit next to the text without
/// competing with it.
class ClaudeIcons {
  const ClaudeIcons._();

  static const String _family = 'ClaudeIcons';

  /// Renders [icon] through whichever backend it needs.
  ///
  /// Call sites that accept an arbitrary IconData have to use this: [Icon]
  /// resolves a glyph through a font family, and ours has no font behind it,
  /// so a custom IconData handed to [Icon] draws nothing at all.
  static Widget render(
    IconData icon, {
    required double size,
    Color? color,
    String? semanticsLabel,
  }) {
    if (icon.fontFamily == _family) {
      return ClaudeIcon(
        icon,
        size: size,
        color: color,
        semanticsLabel: semanticsLabel,
      );
    }
    return Icon(icon, size: size, color: color);
  }

  static IconData get send => const _ClaudeSend();
  static IconData get stop => const _ClaudeStop();
  static IconData get plus => const _ClaudePlus();
  static IconData get image => const _ClaudeImage();
  static IconData get ghost => const _ClaudeGhost();
  static IconData get menu => const _ClaudeMenu();
  static IconData get copy => const _ClaudeCopy();
  static IconData get edit => const _ClaudeEdit();
  static IconData get regenerate => const _ClaudeRegenerate();
  static IconData get trash => const _ClaudeTrash();
  static IconData get chip => const _ClaudeChip();
  static IconData get search => const _ClaudeSearch();
  static IconData get chevronRight => const _ClaudeChevronRight();
  static IconData get close => const _ClaudeClose();
  static IconData get info => const _ClaudeInfo();
  static IconData get sliders => const _ClaudeSliders();
  static IconData get layers => const _ClaudeLayers();
  static IconData get download => const _ClaudeDownload();
  static IconData get play => const _ClaudePlay();
  static IconData get chevronDown => const _ClaudeChevronDown();

  /// Stroke weight scales with the rendered size so a 16px icon keeps the
  /// same visual density as a 24px one.
  static double strokeFor(double size) => math.max(1.3, size / 15);

  static IconData chevronDownFor(bool expanded) =>
      expanded ? _ClaudeChevronUp() : _ClaudeChevronDown();
}

class _ClaudeSend extends IconData {
  const _ClaudeSend() : super(0xe900, fontFamily: 'ClaudeIcons');
}

class _ClaudeStop extends IconData {
  const _ClaudeStop() : super(0xe901, fontFamily: 'ClaudeIcons');
}

class _ClaudePlus extends IconData {
  const _ClaudePlus() : super(0xe902, fontFamily: 'ClaudeIcons');
}

class _ClaudeImage extends IconData {
  const _ClaudeImage() : super(0xe903, fontFamily: 'ClaudeIcons');
}

class _ClaudeGhost extends IconData {
  const _ClaudeGhost() : super(0xe904, fontFamily: 'ClaudeIcons');
}

class _ClaudeMenu extends IconData {
  const _ClaudeMenu() : super(0xe905, fontFamily: 'ClaudeIcons');
}

class _ClaudeCopy extends IconData {
  const _ClaudeCopy() : super(0xe906, fontFamily: 'ClaudeIcons');
}

class _ClaudeEdit extends IconData {
  const _ClaudeEdit() : super(0xe907, fontFamily: 'ClaudeIcons');
}

class _ClaudeRegenerate extends IconData {
  const _ClaudeRegenerate() : super(0xe908, fontFamily: 'ClaudeIcons');
}

class _ClaudeTrash extends IconData {
  const _ClaudeTrash() : super(0xe909, fontFamily: 'ClaudeIcons');
}

class _ClaudeChip extends IconData {
  const _ClaudeChip() : super(0xe90c, fontFamily: 'ClaudeIcons');
}

class _ClaudeSearch extends IconData {
  const _ClaudeSearch() : super(0xe90d, fontFamily: 'ClaudeIcons');
}

class _ClaudeChevronRight extends IconData {
  const _ClaudeChevronRight() : super(0xe90e, fontFamily: 'ClaudeIcons');
}

class _ClaudeClose extends IconData {
  const _ClaudeClose() : super(0xe90f, fontFamily: 'ClaudeIcons');
}

class _ClaudeInfo extends IconData {
  const _ClaudeInfo() : super(0xe910, fontFamily: 'ClaudeIcons');
}

class _ClaudeSliders extends IconData {
  const _ClaudeSliders() : super(0xe911, fontFamily: 'ClaudeIcons');
}

class _ClaudeLayers extends IconData {
  const _ClaudeLayers() : super(0xe912, fontFamily: 'ClaudeIcons');
}

class _ClaudeDownload extends IconData {
  const _ClaudeDownload() : super(0xe913, fontFamily: 'ClaudeIcons');
}

class _ClaudePlay extends IconData {
  const _ClaudePlay() : super(0xe914, fontFamily: 'ClaudeIcons');
}

class _ClaudeChevronDown extends IconData {
  const _ClaudeChevronDown() : super(0xe90a, fontFamily: 'ClaudeIcons');
}

class _ClaudeChevronUp extends IconData {
  const _ClaudeChevronUp() : super(0xe90b, fontFamily: 'ClaudeIcons');
}

/// Paints the glyphs in [ClaudeIcons].
///
/// A single painter rather than one class per glyph: they share a stroke
/// setup, and a font entry point for each one would mean registering a
/// family the build would otherwise have to bundle.
class ClaudeIconPainter extends CustomPainter {
  const ClaudeIconPainter(this.codePoint, {required this.color, required this.size});

  final int codePoint;
  final Color color;
  final double size;

  @override
  void paint(Canvas canvas, Size sz) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = ClaudeIcons.strokeFor(size)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Work in the 24-unit design grid, then scale to whatever size was asked
    // for. `sz` is ignored deliberately: the icon is laid out by its box, and
    // a square box is what callers pass.
    final s = size / 24;
    canvas
      ..save()
      ..scale(s, s);

    switch (codePoint) {
      case 0xe900:
        _send(canvas, paint);
      case 0xe901:
        _stop(canvas, paint);
      case 0xe902:
        _plus(canvas, paint);
      case 0xe903:
        _image(canvas, paint);
      case 0xe904:
        _ghost(canvas, paint);
      case 0xe905:
        _menu(canvas, paint);
      case 0xe906:
        _copy(canvas, paint);
      case 0xe907:
        _edit(canvas, paint);
      case 0xe908:
        _regenerate(canvas, paint);
      case 0xe909:
        _trash(canvas, paint);
      case 0xe90a:
        _chevron(canvas, paint, 1);
      case 0xe90b:
        _chevron(canvas, paint, -1);
      case 0xe90c:
        _chip(canvas, paint);
      case 0xe90d:
        _search(canvas, paint);
      case 0xe90e:
        _chevronRight(canvas, paint);
      case 0xe90f:
        _close(canvas, paint);
      case 0xe910:
        _info(canvas, paint);
      case 0xe911:
        _sliders(canvas, paint);
      case 0xe912:
        _layers(canvas, paint);
      case 0xe913:
        _download(canvas, paint);
      case 0xe914:
        _play(canvas, paint);
    }

    canvas.restore();
  }

  // A paper plane, tilted so the nose points up-right like a "go".
  void _send(Canvas canvas, Paint paint) {
    final path = Path()
      ..moveTo(4.2, 11.4)
      ..lineTo(20, 4.4)
      ..lineTo(12.6, 20)
      ..lineTo(10.4, 13.2)
      ..close()
      ..moveTo(10.4, 13.2)
      ..lineTo(20, 4.4);
    canvas.drawPath(path, paint);
  }

  void _stop(Canvas canvas, Paint paint) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6.5, 6.5, 11, 11),
        const Radius.circular(2.6),
      ),
      paint,
    );
  }

  void _plus(Canvas canvas, Paint paint) {
    canvas
      ..drawLine(const Offset(12, 5.2), const Offset(12, 18.8), paint)
      ..drawLine(const Offset(5.2, 12), const Offset(18.8, 12), paint);
  }

  void _image(Canvas canvas, Paint paint) {
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(3.4, 5, 17.2, 14),
          const Radius.circular(3),
        ),
        paint,
      )
      // Horizon.
      ..drawLine(const Offset(3.4, 15.4), const Offset(3.4, 19), paint)
      ..drawLine(const Offset(3.4, 19), const Offset(20.6, 19), paint)
      ..drawLine(const Offset(20.6, 19), const Offset(20.6, 15.4), paint)
      // A low sun, kept off the frame so it reads as scenery not UI.
      ..drawCircle(const Offset(8.6, 9.8), 1.5, paint);
    // Two overlapping peaks, hanging below the frame's bottom edge.
    canvas.drawPath(
      Path()
        ..moveTo(3.4, 15.4)
        ..lineTo(9.4, 10.6)
        ..lineTo(13.4, 14)
        ..lineTo(16.2, 11.8)
        ..lineTo(20.6, 15.4),
      paint,
    );
  }

  void _ghost(Canvas canvas, Paint paint) {
    final body = Path()
      ..moveTo(5.2, 18.6)
      ..lineTo(5.2, 10.2)
      // Rounded dome.
      ..cubicTo(5.2, 5.4, 18.8, 5.4, 18.8, 10.2)
      ..lineTo(18.8, 18.6)
      ..lineTo(16.1, 16.7)
      ..lineTo(13.4, 18.6)
      ..lineTo(10.6, 16.7)
      ..lineTo(8.0, 18.6)
      ..close();
    canvas
      ..drawPath(body, paint)
      ..drawCircle(const Offset(9.9, 11.4), 0.95, paint..style = PaintingStyle.fill)
      ..drawCircle(const Offset(14.1, 11.4), 0.95, paint);
  }

  void _menu(Canvas canvas, Paint paint) {
    canvas
      ..drawLine(const Offset(4, 7.4), const Offset(20, 7.4), paint)
      ..drawLine(const Offset(4, 12), const Offset(20, 12), paint)
      ..drawLine(const Offset(4, 16.6), const Offset(20, 16.6), paint);
  }



  void _copy(Canvas canvas, Paint paint) {
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(8.4, 3.6, 11.4, 11.4),
          const Radius.circular(2.6),
        ),
        paint,
      )
      ..drawPath(
        // Offset sheet behind it, drawn as three sides so the corners do
        // not collide with the front one.
        Path()
          ..moveTo(5.6, 7.4)
          ..lineTo(5.6, 17.2)
          ..lineTo(15.4, 17.2),
        paint,
      );
  }

  void _edit(Canvas canvas, Paint paint) {
    canvas.drawPath(
        Path()
          ..moveTo(4.6, 19.4)
          ..lineTo(5.0, 15.6)
          ..lineTo(15.6, 5.0)
          ..lineTo(19.0, 8.4)
          ..lineTo(8.4, 19.0)
          ..close(),
        paint,
      );
    canvas.drawLine(const Offset(13.4, 7.2), const Offset(16.8, 10.6), paint);
  }

  void _regenerate(Canvas canvas, Paint paint) {
    canvas.drawArc(
      const Rect.fromLTWH(4.6, 4.6, 14.8, 14.8),
      -math.pi * 0.62,
      math.pi * 1.55,
      false,
      paint,
    );
    // Arrowhead closing the gap in the ring.
    canvas.drawPath(
      Path()
        ..moveTo(19.6, 4.4)
        ..lineTo(18.6, 9.0)
        ..lineTo(14.2, 8.2)
        ..close(),
      paint,
    );
  }

  void _trash(Canvas canvas, Paint paint) {
    canvas
      ..drawLine(const Offset(4.6, 6.8), const Offset(19.4, 6.8), paint)
      ..drawPath(
        Path()
          ..moveTo(6.6, 6.8)
          ..lineTo(7.5, 19.2)
          ..lineTo(16.5, 19.2)
          ..lineTo(17.4, 6.8),
        paint,
      )
      // Handle, as its own path so the lid line does not cut through it.
      ..drawPath(
        Path()
          ..moveTo(9.6, 6.8)
          ..lineTo(9.6, 4.6)
          ..lineTo(14.4, 4.6)
          ..lineTo(14.4, 6.8),
        paint,
      );
  }

  // A processor: a square die with legs, the honest shorthand for "engine".
  void _chip(Canvas canvas, Paint paint) {
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(7.4, 7.4, 9.2, 9.2),
          const Radius.circular(1.8),
        ),
        paint,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(10.6, 10.6, 2.8, 2.8),
          const Radius.circular(0.7),
        ),
        paint,
      );
    for (final x in const [10.2, 13.8]) {
      canvas
        ..drawLine(Offset(x, 4.6), Offset(x, 7.4), paint)
        ..drawLine(Offset(x, 16.6), Offset(x, 19.4), paint);
    }
    for (final y in const [10.2, 13.8]) {
      canvas
        ..drawLine(Offset(4.6, y), Offset(7.4, y), paint)
        ..drawLine(Offset(16.6, y), Offset(19.4, y), paint);
    }
  }

  void _search(Canvas canvas, Paint paint) {
    canvas
      ..drawCircle(const Offset(10.8, 10.8), 6.4, paint)
      ..drawLine(const Offset(15.6, 15.6), const Offset(20, 20), paint);
  }

  void _chevronRight(Canvas canvas, Paint paint) {
    canvas.drawPath(
      Path()
        ..moveTo(9.8, 5.4)
        ..lineTo(16.4, 12)
        ..lineTo(9.8, 18.6),
      paint,
    );
  }

  void _close(Canvas canvas, Paint paint) {
    canvas
      ..drawLine(const Offset(6.2, 6.2), const Offset(17.8, 17.8), paint)
      ..drawLine(const Offset(17.8, 6.2), const Offset(6.2, 17.8), paint);
  }

  void _info(Canvas canvas, Paint paint) {
    canvas
      ..drawCircle(const Offset(12, 12), 8.2, paint)
      ..drawLine(const Offset(12, 11.2), const Offset(12, 16.4), paint);
    canvas.drawCircle(const Offset(12, 8.2), 0.95, paint..style = PaintingStyle.fill);
  }

  // Two rules with a knob on each — the settings glyph, drawn as controls
  // rather than as an abstract "tuning" metaphor.
  void _sliders(Canvas canvas, Paint paint) {
    for (final row in const [(7.4, 14.2), (16.4, 10.2)]) {
      final y = row.$1;
      final knobX = row.$2;
      canvas
        ..drawLine(Offset(4.2, y), Offset(19.8, y), paint)
        ..drawCircle(Offset(knobX, y), 2.3, paint);
    }
  }

  void _layers(Canvas canvas, Paint paint) {
    for (final dy in const [0.0, 4.4, 8.8]) {
      canvas.drawPath(
        Path()
          ..moveTo(12, 4.4 + dy)
          ..lineTo(20, 8.6 + dy)
          ..lineTo(12, 12.8 + dy)
          ..lineTo(4, 8.6 + dy)
          ..close(),
        paint,
      );
    }
  }

  void _download(Canvas canvas, Paint paint) {
    canvas.drawLine(const Offset(12, 4.4), const Offset(12, 14.6), paint);
    canvas.drawPath(
      Path()
        ..moveTo(7.6, 10.6)
        ..lineTo(12, 15.2)
        ..lineTo(16.4, 10.6),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(4.4, 15.6)
        ..lineTo(4.4, 19.2)
        ..lineTo(19.6, 19.2)
        ..lineTo(19.6, 15.6),
      paint,
    );
  }

  void _play(Canvas canvas, Paint paint) {
    canvas.drawPath(
      Path()
        ..moveTo(7.6, 5.2)
        ..lineTo(18.4, 12)
        ..lineTo(7.6, 18.8)
        ..close(),
      paint,
    );
  }

  void _chevron(Canvas canvas, Paint paint, int dir) {
    canvas.drawPath(
      Path()
        ..moveTo(6.6, 9.6)
        ..lineTo(12, 15.0)
        ..lineTo(17.4, 9.6),
      paint,
    );
    if (dir > 0) return;
  }

  @override
  bool shouldRepaint(ClaudeIconPainter oldDelegate) =>
      oldDelegate.codePoint != codePoint ||
      oldDelegate.color != color ||
      oldDelegate.size != size;
}

/// Renders one of the hand-drawn glyphs.
///
/// Drop-in for [Icon] — same constructor shape — so call sites can migrate
/// one at a time instead of all at once.
class ClaudeIcon extends StatelessWidget {
  const ClaudeIcon(
    this.icon, {
    super.key,
    this.size = 20,
    this.color,
    this.semanticsLabel,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? IconTheme.of(context).color ?? Colors.black;
    return Semantics(
      label: semanticsLabel,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: ClaudeIconPainter(icon.codePoint, color: color, size: size),
        ),
      ),
    );
  }
}