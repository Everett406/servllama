import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:servllama/app/widgets/claude_icons.dart';
import 'package:servllama/app/widgets/svg_path_data.dart';

/// The keyline set is drawn on a 24x24 grid with 2px strokes, round caps and
/// joins. It uses six path commands and no others, so the parser is small
/// enough to pin down precisely — a glyph that is off by a control point is
/// not something anybody spots by looking.
void main() {
  group('SvgPathData', () {
    test('M and L', () {
      final path = SvgPathData('M0 0L10 0L10 10Z').toPath();
      expect(path.getBounds().left, 0);
      expect(path.getBounds().right, 10);
      expect(path.getBounds().bottom, 10);
    });

    test('H and V move only one axis', () {
      final path = SvgPathData('M5 5H15V20').toPath();
      final b = path.getBounds();
      expect(b.left, 5);
      expect(b.top, 5);
      expect(b.right, 15);
      expect(b.bottom, 20);
    });

    test('C stays inside its control points', () {
      final path = SvgPathData('M0 0C0 10 10 10 10 0').toPath();
      final b = path.getBounds();
      expect(b.left, greaterThanOrEqualTo(0));
      expect(b.right, lessThanOrEqualTo(10));
      expect(b.bottom, greaterThan(0));
    });

    test('negative and decimal coordinates parse', () {
      final path = SvgPathData('M-1.5 2.25L3.5 -4.75').toPath();
      final b = path.getBounds();
      expect(b.left, -1.5);
      expect(b.top, -4.75);
      expect(b.right, 3.5);
      expect(b.bottom, 2.25);
    });

    test('newlines, tabs and commas all separate numbers', () {
      final a = SvgPathData('M1 2L3 4').toPath().getBounds();
      final b = SvgPathData('M1,2\nL3,4').toPath().getBounds();
      final c = SvgPathData('M 1 2 L 3 4').toPath().getBounds();
      expect(a, b);
      expect(a, c);
    });

    test('a close resumes from the start of that subpath', () {
      // Two boxes; if close did not reset, the second box would join the first.
      final path = SvgPathData('M0 0L5 0L5 5ZM20 20L25 20L25 25Z').toPath();
      final b = path.getBounds();
      expect(b.left, 0);
      expect(b.right, 25);
      expect(b.width, 25);
    });

    test('an unsupported command is refused rather than half-drawn', () {
      expect(
        () => SvgPathData('M0 0A5 5 0 0 1 10 10').toPath(),
        throwsFormatException,
      );
      expect(
        () => SvgPathData('m0 0l5 5').toPath(),
        throwsFormatException,
        reason: 'relative commands are not in this set',
      );
    });

    test('truncated data is refused', () {
      expect(() => SvgPathData('M0').toPath(), throwsFormatException);
    });
  });

  group('ClaudeIcons', () {
    test('every icon has geometry inside the 24-unit grid', () {
      for (final entry in ClaudeIcons.paths.entries) {
        expect(
          entry.value,
          isNotEmpty,
          reason: 'codepoint 0x${entry.key.toRadixString(16)} has no paths',
        );
        for (final shape in entry.value) {
          final bounds = shape.toPath().getBounds();
          expect(bounds.width + bounds.height, greaterThan(0));
          // The set is 24x24; allow a little for round caps sitting on the
          // edge, but nothing should be drawn outside it.
          expect(bounds.left, greaterThan(-1.5));
          expect(bounds.top, greaterThan(-1.5));
          expect(bounds.right, lessThan(25.5));
          expect(bounds.bottom, lessThan(25.5));
        }
      }
    });

    test('every icon name the app uses resolves to a drawing', () {
      // The regression this guards: 31 call sites handed Material IconData to
      // this painter, the codepoints did not match anything in the table, and
      // the whole settings page rendered with no icons and nothing in the log.
      //
      // Walking the source is blunt on purpose. It catches a name that exists
      // as a getter but has no entry in `paths`, which is the failure mode a
      // widget test rendering one screen at a time would not.
      const names = <String>[
        'send', 'stop', 'plus', 'image', 'ghost', 'menu', 'copy', 'edit',
        'regenerate', 'trash', 'chip', 'search', 'chevronRight', 'close',
        'info', 'sliders', 'layers', 'download', 'play', 'clock', 'newChat',
        'more', 'slash', 'penSquare', 'archive', 'chevronDown',
        'error', 'security', 'key', 'folderOpen', 'wifi', 'route', 'timer',
        'star', 'smartphone', 'receipt', 'palette', 'language', 'package',
        'file', 'fileText', 'cloudDownload', 'broom', 'calculator', 'tag',
      ];
      expect(names.toSet(), hasLength(ClaudeIcons.paths.length));

      final source = Directory('lib');
      var referenced = <String>{};
      for (final entity in source.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        for (final m in RegExp(r'ClaudeIcons\.(\w+)').allMatches(entity.readAsStringSync())) {
          final name = m.group(1)!;
          // Methods and the private constructor are not icon names.
          if (name == 'render' || name == 'draw' || name == '_') continue;
          referenced.add(name);
        }
      }
      expect(referenced, isNotEmpty);
      expect(
        referenced.difference(names.toSet()),
        isEmpty,
        reason: 'these names are used in lib/ but have no drawing',
      );
    });

    test('codepoints are unique', () {
      final all = <IconData>[
        ClaudeIcons.send, ClaudeIcons.stop, ClaudeIcons.plus, ClaudeIcons.image,
        ClaudeIcons.ghost, ClaudeIcons.menu, ClaudeIcons.copy, ClaudeIcons.edit,
        ClaudeIcons.regenerate, ClaudeIcons.trash, ClaudeIcons.chip, ClaudeIcons.search,
        ClaudeIcons.chevronRight, ClaudeIcons.close, ClaudeIcons.info, ClaudeIcons.sliders,
        ClaudeIcons.layers, ClaudeIcons.download, ClaudeIcons.play, ClaudeIcons.clock,
        ClaudeIcons.newChat, ClaudeIcons.more, ClaudeIcons.slash, ClaudeIcons.penSquare,
        ClaudeIcons.archive, ClaudeIcons.chevronDown,
      ];
      expect(all.map((e) => e.codePoint).toSet(), hasLength(all.length));
    });

    testWidgets('a widget paints without throwing for every icon', (tester) async {
      for (final entry in ClaudeIcons.paths.entries) {
        await tester.pumpWidget(
          MaterialApp(
            home: ClaudeIcon(
              IconData(entry.key, fontFamily: ClaudeIcons.family),
            ),
          ),
        );
        await tester.pump();
      }
    });
  });
}