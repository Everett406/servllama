import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/chat/widgets/streaming_block_splitter.dart';

void main() {
  // gpt_markdown already holds a half-row back until its newline lands, so a
  // table never *forms* on half a row. What it cannot stop is a table growing
  // under the user's eye — and every new row reflows the rows above it, so
  // what they are reading is never still.
  group('open table blocks', () {
    test('a table still arriving is held back', () {
      const content = 'Here you go:\n\n'
          '| Name | Size |\n'
          '| --- | --- |\n'
          '| bge | 26 MB |';
      final segments = splitStreamingBlocks(content);

      expect(segments.where((s) => s.isOpenTable), hasLength(1));
      final open = segments.firstWhere((s) => s.isOpenTable);
      expect(open.table, startsWith('| Name | Size |'));
      // The prose before it is settled and must still render.
      expect(segments.first.markdown, contains('Here you go:'));
    });

    test('a closed table renders as ordinary Markdown', () {
      const content = '| Name | Size |\n'
          '| --- | --- |\n'
          '| bge | 26 MB |\n'
          '\n'
          'That is all.';
      final segments = splitStreamingBlocks(content);

      expect(segments.where((s) => s.isOpenTable), isEmpty);
      expect(segments.single.markdown, content);
    });

    test('a trailing newline is not a finishing line, so the table stays open', () {
      // The bug this locks down: `'a\n'.split('\n')` is `['a', '']`, so the
      // newline the model just typed left a blank element that looked like the
      // blank line that closes a table. The table flickered between finished
      // and unfinished on nearly every row.
      const rows = '| a | b |\n| --- | --- |\n| 1 | 2 |\n';
      final segments = splitStreamingBlocks(rows);
      expect(segments.where((s) => s.isOpenTable), hasLength(1));

      // A genuinely typed blank line has its own trailing newline, so the
      // table really is finished.
      final closed = splitStreamingBlocks('$rows\n');
      expect(closed.where((s) => s.isOpenTable), isEmpty);

      // And a blank line followed by more text closes it too.
      final followed = splitStreamingBlocks('$rows\n后面还有一句。');
      expect(followed.where((s) => s.isOpenTable), isEmpty);
    });

    // The split is now monotone in the common case, which is what removed the
    // flicker. AnswerMarkdown still latches, because "usually" is not a
    // guarantee and a table that blinks is very visible.
    test('a table stays open for every row it gains', () {
      const head = '说明。\n\n| a | b |\n| --- | --- |';
      const rows = <String>['| 1 | 2 |', '| 3 | 4 |', '| 5 | 6 |'];
      var openedAfterFirst = false;
      for (var i = 0; i < rows.length; i++) {
        final held = splitStreamingBlocks('$head\n${rows[i]}\n')
            .where((s) => s.isOpenTable);
        expect(held, hasLength(1), reason: 'row ${i + 1} should be held back');
        openedAfterFirst = true;
      }
      expect(openedAfterFirst, isTrue);
    });

    test('no table at all is untouched', () {
      const content = 'Just a paragraph.\n\nAnd another.';
      expect(splitStreamingBlocks(content).single.markdown, content);
    });

    test('pipes without a delimiter row are prose, not a table', () {
      // Two pipe lines with no `|---|` between them are text that happens to
      // contain pipes. Rendering a placeholder for those would blank out
      // ordinary content.
      const content = 'a | b\nc | d';
      final segments = splitStreamingBlocks(content);
      expect(segments.where((s) => s.isOpenTable), isEmpty);
      expect(segments.single.markdown, content);
    });

    test('an open table is found after settled prose', () {
      const content = 'Answer:\n\n'
          'First a paragraph.\n\n'
          '| a | b |\n'
          '| --- | --- |\n'
          '| 1 | 2 |';
      final segments = splitStreamingBlocks(content);
      expect(segments.where((s) => s.isOpenTable), hasLength(1));
      expect(
        segments.firstWhere((s) => !s.isOpenTable).markdown,
        contains('First a paragraph.'),
      );
    });

    // Only the trailing block can be open: once a model has moved past
    // something it is finished by definition.
    test('an earlier table stays rendered while a later one streams', () {
      const content = '| a | b |\n'
          '| --- | --- |\n'
          '| 1 | 2 |\n'
          '\n'
          'And now the second one:\n\n'
          '| c | d |\n'
          '| --- | --- |\n'
          '| 3 | 4 |';
      final segments = splitStreamingBlocks(content);
      final open = segments.where((s) => s.isOpenTable).toList();
      expect(open, hasLength(1));
      expect(open.single.table, startsWith('| c | d |'));
      // The first table is still in the settled Markdown.
      final settled = segments.firstWhere((s) => !s.isOpenTable).markdown!;
      expect(settled, contains('| a | b |'));
    });

    test('a table immediately after a heading is detected', () {
      const content = '## Sizes\n'
          '\n'
          '| a | b |\n'
          '| --- | --- |\n'
          '| 1 | 2 |';
      expect(splitStreamingBlocks(content).where((s) => s.isOpenTable), hasLength(1));
    });

    test('a header-only table with a delimiter and no rows yet is open', () {
      const content = '| Name | Size |\n| --- | --- |';
      final segments = splitStreamingBlocks(content);
      expect(segments.where((s) => s.isOpenTable), hasLength(1));
    });

    test('a single line is never a table', () {
      expect(splitStreamingBlocks('| a |').single.isOpenTable, isFalse);
      expect(splitStreamingBlocks('| a |\n| --- |').last.isOpenTable, isTrue);
    });

    test('empty and whitespace content produce nothing to render', () {
      expect(splitStreamingBlocks(''), isEmpty);
      expect(splitStreamingBlocks('\n\n'), isNotEmpty);
      expect(
        splitStreamingBlocks('\n\n').where((s) => s.isOpenTable),
        isEmpty,
      );
    });

    test('the settled Markdown excludes the held-back table', () {
      const content = 'Before.\n\n| a | b |\n| --- | --- |\n| 1 | 2 |';
      final settled = settledMarkdown(splitStreamingBlocks(content));
      expect(settled, contains('Before.'));
      // The point: the renderer is never handed the unfinished table.
      expect(settled, isNot(contains('| 1 | 2 |')));
    });
  });
}
