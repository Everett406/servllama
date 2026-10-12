import 'dart:ui';

/// Turns an SVG path's `d` attribute into a Flutter [Path].
///
/// Only the commands the keyline set actually uses are supported: absolute
/// `M`, `L`, `C`, `H`, `V` and `Z`. The whole set comes to 29 paths and
/// contains no elliptical arc, no quadratic and no relative command, so a
/// partial parser is a complete one here — and a partial parser is much
/// easier to be sure about than a permissive one that silently draws the
/// wrong shape.
///
/// The coordinates are the set's native 24-unit grid and are left in that
/// space. [KeylineIconPainter] scales once, at paint time.
class SvgPathData {
  const SvgPathData(this.d);

  /// The raw `d` string, kept so the table stays inspectable in source.
  final String d;

  /// Parses to a path in the set's own 24×24 space.
  Path toPath() {
    final path = Path();
    final scanner = _Scanner(d);

    var x = 0.0;
    var y = 0.0;
    var startX = 0.0;
    var startY = 0.0;

    while (true) {
      final command = scanner.readCommand();
      if (command == null) break;

      switch (command) {
        case 'M':
          x = scanner.readNumber();
          y = scanner.readNumber();
          path.moveTo(x, y);
          startX = x;
          startY = y;
        case 'L':
          x = scanner.readNumber();
          y = scanner.readNumber();
          path.lineTo(x, y);
        case 'H':
          x = scanner.readNumber();
          path.lineTo(x, y);
        case 'V':
          y = scanner.readNumber();
          path.lineTo(x, y);
        case 'C':
          final c1x = scanner.readNumber();
          final c1y = scanner.readNumber();
          final c2x = scanner.readNumber();
          final c2y = scanner.readNumber();
          x = scanner.readNumber();
          y = scanner.readNumber();
          path.cubicTo(c1x, c1y, c2x, c2y, x, y);
        case 'Z':
          path.close();
          // A closed subpath resumes from where it started. Anything drawn
          // after it in the same `d` continues from there, not from the last
          // point before the close.
          x = startX;
          y = startY;
        default:
          // Unreachable for this set, and throwing beats drawing a shape
          // nobody asked for.
          throw FormatException('Unsupported path command "$command" in $d');
      }
    }
    return path;
  }
}

/// A minimal reader for the numeric grammar SVG paths use.
///
/// Hand-rolled because the set has no exponents and no packed coordinate
/// runs: numbers are `[-+0-9.eE]*`, separators are whitespace and commas.
class _Scanner {
  _Scanner(this.source);

  final String source;
  int _index = 0;

  String? readCommand() {
    _skipSeparators();
    if (_index >= source.length) return null;
    final char = source[_index];
    if (!_isCommandLetter(char)) return null;
    _index++;
    return char;
  }

  double readNumber() {
    _skipSeparators();
    final start = _index;
    while (_index < source.length && _isNumberChar(source[_index])) {
      _index++;
    }
    if (start == _index) {
      throw FormatException('Expected a number at $_index in $source');
    }
    final value = double.tryParse(source.substring(start, _index));
    if (value == null) {
      throw FormatException('Bad number in $source');
    }
    return value;
  }

  void _skipSeparators() {
    while (_index < source.length) {
      final char = source[_index];
      if (char == ' ' ||
          char == '\t' ||
          char == '\n' ||
          char == '\r' ||
          char == ',') {
        _index++;
      } else {
        return;
      }
    }
  }

  static bool _isCommandLetter(String char) {
    final code = char.codeUnitAt(0);
    return code >= 65 && code <= 90 || code >= 97 && code <= 122;
  }

  static bool _isNumberChar(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 48 && code <= 57) ||
        char == '.' ||
        char == '-' ||
        char == '+' ||
        char == 'e' ||
        char == 'E';
  }
}
