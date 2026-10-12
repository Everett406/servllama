import 'package:flutter/material.dart';
import 'package:servllama/app/widgets/svg_path_data.dart';

/// Every icon in the app, drawn from Keyline.
///
/// Keyline is an open set of 1,366 drawings on one 24x24 grid, built around
/// 2px strokes with round caps and joins (MIT). It ships as SVG for React,
/// React Native, Iconify, Figma and an MCP server, but there is no Flutter
/// package — and turning stroked artwork into a font means flattening every
/// stroke to an outline first, which is a lot of tooling to carry for
/// twenty-six glyphs.
///
/// So the drawings stay as path data and are stroked onto the canvas at
/// paint time. The set's weight and terminals survive exactly as drawn, the
/// dependency list and the APK size do not move, and this file remains the
/// one place an icon is defined — which is what the app already assumed by
/// routing everything through here.
///
/// Source: github.com/keyline-icons/keyline-icons (MIT).
class ClaudeIcons {
  const ClaudeIcons._();

  /// Never resolved. The codepoint selects the drawing and nothing is ever
  /// loaded from a font; the name only has to be stable.
  static const String family = 'keyline';

  /// Paper plane — send.
  static IconData get send => const IconData(0xe900, fontFamily: family);

  /// Stop generation.
  static IconData get stop => const IconData(0xe901, fontFamily: family);

  /// Add.
  static IconData get plus => const IconData(0xe902, fontFamily: family);

  /// Image attachment.
  static IconData get image => const IconData(0xe903, fontFamily: family);

  /// Stealth / incognito, drawn as eye-off.
  static IconData get ghost => const IconData(0xe904, fontFamily: family);

  /// Open the drawer.
  static IconData get menu => const IconData(0xe905, fontFamily: family);

  /// Copy to clipboard.
  static IconData get copy => const IconData(0xe906, fontFamily: family);

  /// Edit this message and resend.
  static IconData get edit => const IconData(0xe907, fontFamily: family);

  /// Retry a reply.
  static IconData get regenerate => const IconData(0xe908, fontFamily: family);

  /// Delete.
  static IconData get trash => const IconData(0xe909, fontFamily: family);

  /// Engine and model.
  static IconData get chip => const IconData(0xe90a, fontFamily: family);

  /// Search conversations.
  static IconData get search => const IconData(0xe90b, fontFamily: family);

  /// Disclosure.
  static IconData get chevronRight =>
      const IconData(0xe90c, fontFamily: family);

  /// Dismiss.
  static IconData get close => const IconData(0xe90d, fontFamily: family);

  /// Detail and about.
  static IconData get info => const IconData(0xe90e, fontFamily: family);

  /// Engine settings.
  static IconData get sliders => const IconData(0xe90f, fontFamily: family);

  /// Context window.
  static IconData get layers => const IconData(0xe910, fontFamily: family);

  /// Fetch a model.
  static IconData get download => const IconData(0xe911, fontFamily: family);

  /// Start the server.
  static IconData get play => const IconData(0xe912, fontFamily: family);

  /// Time and duration.
  static IconData get clock => const IconData(0xe913, fontFamily: family);

  /// New conversation.
  static IconData get newChat => const IconData(0xe914, fontFamily: family);

  /// Overflow menu.
  static IconData get more => const IconData(0xe915, fontFamily: family);

  /// Stop.
  static IconData get slash => const IconData(0xe916, fontFamily: family);

  /// Edit in place.
  static IconData get penSquare => const IconData(0xe917, fontFamily: family);

  /// Chat history.
  static IconData get archive => const IconData(0xe918, fontFamily: family);

  /// Expand the thought sheet.
  static IconData get chevronDown => const IconData(0xe919, fontFamily: family);

  /// A plain [Icon] that still resolves through this set.
  ///
  /// Three call sites build an [IconData] inline rather than naming a
  /// constant, and handing one to [Icon] would draw nothing at all — which
  /// is the exact failure this painter exists to prevent.
  static Widget render(
    IconData icon, {
    double size = 20,
    Color? color,
    String? semanticsLabel,
  }) {
    return ClaudeIcon(
      icon,
      size: size,
      color: color,
      semanticsLabel: semanticsLabel,
    );
  }

  /// Strokes the drawing at [codePoint] onto [canvas] at [size] pixels.
  ///
  /// Takes the codepoint rather than an [IconData] on purpose. Rebuilding an
  /// IconData here from a value only known at runtime is non-constant, and
  /// the release tree shaker refuses to build a binary that contains one —
  /// so the painter below passes its own int straight through.
  static void draw(
    Canvas canvas,
    int codePoint, {
    required Color color,
    required double size,
  }) {
    final shapes = paths[codePoint];
    if (shapes == null || shapes.isEmpty) return;

    final scale = size / 24.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      // The set is drawn at 2 on a 24 grid. Scaling it with the icon is the
      // point of that choice: a small icon gets a proportionally lighter
      // line rather than a hairline the rasteriser cannot render honestly.
      ..strokeWidth = 2.0 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    canvas.save();
    canvas.scale(scale);
    for (final shape in shapes) {
      canvas.drawPath(shape.toPath(), paint);
    }
    canvas.restore();
  }

  /// Keyed by codepoint, because that is how a glyph is looked up.
  static const Map<int, List<SvgPathData>> paths = {
    0xe900: <SvgPathData>[
      SvgPathData(
        'M2.7164 7.7054L22 2L16.2946 21.2836C16.0554 22.0918 14.985 22.2598 14.5098 21.5637L9.9303 14.8559C9.7195 14.5471 9.4529 14.2805 9.1441 14.0697L2.4363 9.4902C1.7402 9.015 1.9082 7.9446 2.7164 7.7054ZM9.6113 14.3887L22 2',
      ),
    ],
    0xe901: <SvgPathData>[
      SvgPathData(
        'M5 7C5 5.895431 5.895431 5 7 5L17 5C18.104569 5 19 5.895431 19 7L19 17C19 18.104569 18.104569 19 17 19L7 19C5.895431 19 5 18.104569 5 17Z',
      ),
    ],
    0xe902: <SvgPathData>[SvgPathData('M5 12H19M11.995 19.005V5.005')],
    0xe903: <SvgPathData>[
      SvgPathData(
        'M6 3L18 3C19.6569 3 21 4.3431 21 6L21 18C21 19.6569 19.6569 21 18 21L6 21C4.3431 21 3 19.6569 3 18L3 6C3 4.3431 4.3431 3 6 3ZM3 18L7.9393 13.0607C8.5251 12.4749 9.4749 12.4749 10.0607 13.0607L12.0801 15.0801C12.6079 15.6079 13.4436 15.6673 14.0408 15.2194L15.9592 13.7806C16.5564 13.3327 17.3921 13.3921 17.9199 13.9199L21 17',
      ),
      SvgPathData(
        'M9.5 7.5C9.5 8.3284 8.8284 9 8 9C7.1716 9 6.5 8.3284 6.5 7.5C6.5 6.6716 7.1716 6 8 6C8.8284 6 9.5 6.6716 9.5 7.5Z',
      ),
    ],
    0xe904: <SvgPathData>[
      SvgPathData(
        'M18.035 18.035C16.3283 19.2786 14.2337 20 12 20C7.206 20 3.0523 16.6771 2 12C2.562 9.5021 4.0086 7.3904 5.965 5.965M9.8779 4.2211C10.565 4.076 11.2752 4 12 4C16.794 4 20.9477 7.3229 22 12C21.7487 13.1169 21.3206 14.1566 20.7491 15.0922M14.1213 14.1213C13.5785 14.6642 12.8285 15 12 15C10.3431 15 9 13.6569 9 12C9 11.1716 9.3358 10.4216 9.8787 9.8787M2 2L22 22',
      ),
    ],
    0xe905: <SvgPathData>[SvgPathData('M4 6H20M4 12H20M4 18H20')],
    0xe906: <SvgPathData>[
      SvgPathData(
        'M15.8284 4C15.4046 2.8015 14.2714 2 13 2H5C3.34315 2 2 3.34315 2 5V13C2 14.2714 2.8015 15.4046 4 15.8284M11 8H19C20.65684 8 22 9.34316 22 11V19C22 20.65684 20.65684 22 19 22H11C9.34316 22 8 20.65684 8 19V11C8 9.34316 9.34316 8 11 8Z',
      ),
    ],
    0xe907: <SvgPathData>[
      SvgPathData(
        'M12 3H6C4.34315 3 3 4.34315 3 6V18C3 19.6569 4.34315 21 6 21H18C19.6569 21 21 19.6569 21 18V12M10.5 13.5L14.6248 11.8501L20.4874 5.9874C21.1709 5.304 21.1709 4.196 20.4874 3.5126C19.804 2.8291 18.696 2.8291 18.0126 3.5126L12.1499 9.3752Z',
      ),
    ],
    0xe908: <SvgPathData>[
      SvgPathData(
        'M3.2117 13.9407C3.071 13.3034 3 12.6527 3 12C3 7.0294 7.0294 3 12 3C14.4831 3 16.8559 4.0259 18.5568 5.8349M19.7143 3L19.2707 6.105C19.2317 6.3784 18.9784 6.5683 18.705 6.5293L15.6 6.0857M20.7883 10.0593C20.929 10.6966 21 11.3473 21 12C21 16.9706 16.9706 21 12 21C9.5169 21 7.1441 19.9741 5.4432 18.1651M4.2857 21L4.7293 17.895C4.7683 17.6216 5.0216 17.4317 5.295 17.4707L8.4 17.9143',
      ),
    ],
    0xe909: <SvgPathData>[
      SvgPathData(
        'M2.264 11.323L8.4058 4.646C8.7845 4.2343 9.3183 4 9.8778 4L19 4C20.6569 4 22 5.3431 22 7L22 17C22 18.6569 20.6569 20 19 20L9.8778 20C9.3183 20 8.7845 19.7657 8.4058 19.354L2.264 12.677C1.912 12.2943 1.912 11.7057 2.264 11.323ZM11 9L17 15M17 9L11 15',
      ),
    ],
    0xe90a: <SvgPathData>[
      SvgPathData(
        'M7 4L17 4C18.6569 4 20 5.3431 20 7L20 17C20 18.6569 18.6569 20 17 20L7 20C5.3431 20 4 18.6569 4 17L4 7C4 5.3431 5.3431 4 7 4ZM9 8L15 8C15.5523 8 16 8.4477 16 9L16 15C16 15.5523 15.5523 16 15 16L9 16C8.4477 16 8 15.5523 8 15L8 9C8 8.4477 8.4477 8 9 8ZM9 4L9 2M9 20L9 22M4 9L2 9M20 9L22 9M15 4L15 2M15 20L15 22M4 15L2 15M20 15L22 15',
      ),
    ],
    0xe90b: <SvgPathData>[
      SvgPathData(
        'M17 10C17 13.866 13.866 17 10 17C6.13401 17 3 13.866 3 10C3 6.13401 6.13401 3 10 3C13.866 3 17 6.13401 17 10ZM15 15L21 21',
      ),
    ],
    0xe90c: <SvgPathData>[SvgPathData('M9 6L15 12L9 18')],
    0xe90d: <SvgPathData>[SvgPathData('M7 7L17 17M17 7L7 17')],
    0xe90e: <SvgPathData>[
      SvgPathData(
        'M12 2C17.5228 2 22 6.47715 22 12C22 17.5228 17.5228 22 12 22C6.47715 22 2 17.5228 2 12C2 6.47715 6.47715 2 12 2Z',
      ),
      SvgPathData('M12 12V16'),
      SvgPathData(
        'M13 8C13 8.5523 12.5523 9 12 9C11.4477 9 11 8.5523 11 8C11 7.4477 11.4477 7 12 7C12.5523 7 13 7.4477 13 8Z',
      ),
    ],
    0xe90f: <SvgPathData>[
      SvgPathData(
        'M8 2L16 2C18.2091 2 20 3.7909 20 6C20 8.2091 18.2091 10 16 10L8 10M16 22L8 22C5.7909 22 4 20.2091 4 18C4 15.7909 5.7909 14 8 14L16 14M12 6C12 8.2091 10.2091 10 8 10C5.7909 10 4 8.2091 4 6C4 3.7909 5.7909 2 8 2C10.2091 2 12 3.7909 12 6ZM20 18C20 20.2091 18.2091 22 16 22C13.7909 22 12 20.2091 12 18C12 15.7909 13.7909 14 16 14C18.2091 14 20 15.7909 20 18Z',
      ),
    ],
    0xe910: <SvgPathData>[
      SvgPathData(
        'M12.4382 2.1011L21.4382 6.4886C22.1873 6.8538 22.1873 7.9212 21.4382 8.2864L12.4382 12.6739C12.1616 12.8087 11.8384 12.8087 11.5618 12.6739L2.5618 8.2864C1.8127 7.9212 1.8127 6.8538 2.5618 6.4886L11.5618 2.1011C11.8384 1.9663 12.1616 1.9663 12.4382 2.1011ZM2 12.625L11.5618 17.2864C11.8384 17.4212 12.1616 17.4212 12.4382 17.2864L22 12.625M2 17.2375L11.5618 21.8989C11.8384 22.0337 12.1616 22.0337 12.4382 21.8989L22 17.2375',
      ),
    ],
    0xe911: <SvgPathData>[
      SvgPathData(
        'M12 3V14M8 10L12 14L16 10M4 18V19C4 20.1046 4.89543 21 6 21H18C19.1046 21 20 20.1046 20 19V18',
      ),
    ],
    0xe912: <SvgPathData>[
      SvgPathData(
        'M6 6C6 5.2291 6.4431 4.5268 7.1389 4.1949C7.8347 3.8629 8.6593 3.9605 9.2585 4.4456L17.6292 11.2228C17.8638 11.4127 18 11.6983 18 12C18 12.3017 17.8638 12.5873 17.6292 12.7772L9.2585 19.5544C8.6593 20.0395 7.8347 20.1371 7.1389 19.8051C6.4431 19.4732 6 18.7709 6 18Z',
      ),
    ],
    0xe913: <SvgPathData>[
      SvgPathData(
        'M12 6L12 12L17 12M12 2C17.5228 2 22 6.47715 22 12C22 17.5228 17.5228 22 12 22C6.47715 22 2 17.5228 2 12C2 6.47715 6.47715 2 12 2Z',
      ),
    ],
    0xe914: <SvgPathData>[
      SvgPathData(
        'M19 3 C20.6569 3 22 4.3431 22 6 C22 7.6569 20.6569 9 19 9 C17.3431 9 16 7.6569 16 6 C16 4.3431 17.3431 3 19 3 ZM12.668 3.0179 C12.4456 3.006 12.2228 3 12 3 C6.4772 3 2 6.5817 2 11 C2 12.9769 2.915 14.8839 4.5686 16.353 L5 21 L9.5808 18.7624 C10.3721 18.9202 11.1845 19 12 19 C16.8496 19 21.0003 16.2162 21.8466 12.3961',
      ),
    ],
    0xe915: <SvgPathData>[
      SvgPathData(
        'M14 5C14 6.1045 13.1045 7 12 7C10.8955 7 10 6.1045 10 5C10 3.8955 10.8955 3 12 3C13.1045 3 14 3.8955 14 5ZM14 12C14 13.1045 13.1045 14 12 14C10.8955 14 10 13.1045 10 12C10 10.8955 10.8955 10 12 10C13.1045 10 14 10.8955 14 12ZM14 19C14 20.1045 13.1045 21 12 21C10.8955 21 10 20.1045 10 19C10 17.8955 10.8955 17 12 17C13.1045 17 14 17.8955 14 19Z',
      ),
    ],
    0xe916: <SvgPathData>[SvgPathData('M2 22L22 2')],
    0xe917: <SvgPathData>[
      SvgPathData(
        'M12 2C6.47715 2 2 6.47715 2 12C2 17.5228 6.47715 22 12 22C17.5228 22 22 17.5228 22 12M10.5 13.5L14.6248 11.8501L20.4874 5.9874C21.1709 5.304 21.1709 4.196 20.4874 3.5126C19.804 2.8291 18.696 2.8291 18.0126 3.5126L12.1499 9.3752Z',
      ),
    ],
    0xe918: <SvgPathData>[
      SvgPathData(
        'M4 4L20 4C21.1046 4 22 4.8954 22 6L22 7C22 8.1046 21.1046 9 20 9L4 9C2.8954 9 2 8.1046 2 7L2 6C2 4.8954 2.8954 4 4 4ZM4 9L4 17C4 18.6569 5.3431 20 7 20L17 20C18.6569 20 20 18.6569 20 17L20 9M10 13L14 13',
      ),
    ],
    0xe919: <SvgPathData>[SvgPathData('M6 9L12 15L18 9')],
  };
}

/// Drop-in for [Icon] — same constructor shape — so call sites keep
/// working unchanged.
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

class ClaudeIconPainter extends CustomPainter {
  const ClaudeIconPainter(
    this.codePoint, {
    required this.color,
    required this.size,
  });

  final int codePoint;
  final Color color;
  final double size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    ClaudeIcons.draw(canvas, codePoint, color: color, size: size);
  }

  @override
  bool shouldRepaint(ClaudeIconPainter oldDelegate) =>
      oldDelegate.codePoint != codePoint ||
      oldDelegate.color != color ||
      oldDelegate.size != size;
}
