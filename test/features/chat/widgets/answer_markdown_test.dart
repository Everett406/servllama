import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

void main() {
  group('reveal grouping', () {
    // The contract this whole patch exists to hold: upstream breaks reveal
    // groups on whitespace, and Chinese has none, so an entire paragraph was
    // one group. Every character in it read the first character's progress and
    // the paragraph blurred once, then snapped sharp together.
    test('a CJK paragraph splits into one group per character', () {
      const text = '模型已经加载完毕';
      final groups = <String>[];
      var from = 0;
      while (from < text.length) {
        final end = revealGroupEnd(text, from);
        groups.add(text.substring(from, end));
        from = end;
      }

      expect(groups, text.split(''));
    });

    test('CJK punctuation ends a group as well', () {
      const text = '好的。';
      expect(revealGroupEnd(text, 0), 1);
      expect(revealGroupEnd(text, 1), 2);
    });

    test('a Latin word is still one group', () {
      const text = 'hello world';
      expect(revealGroupEnd(text, 0), 5);
      expect(revealGroupEnd(text, 6), 11);
    });

    test('a Latin run into CJK ends at the boundary', () {
      const text = 'model模型';
      // The word ends where the ideograph begins.
      expect(revealGroupEnd(text, 0), 5);
      expect(revealGroupEnd(text, 5), 6);
    });

    test('a word starting after a space is still one group', () {
      const text = 'a bb ccc';
      expect(revealGroupEnd(text, 0, limit: 5), 1);
      expect(revealGroupEnd(text, 2, limit: 7), 4);
      expect(revealGroupEnd(text, 5, limit: text.length), text.length);
    });

    test('an unbreakable URL stays a single group', () {
      const url = 'https://example.com/a/b';
      expect(revealGroupEnd(url, 0), url.length);
    });

    // The other half of the bug: _wordStart walked back over whitespace only,
    // so every character in a paragraph read the *first* character's progress
    // — long settled — and the whole paragraph turned plain at once.
    test('the group start of a mid-paragraph character is that character', () {
      const text = '模型已经加载完毕';
      for (var i = 0; i < text.length; i++) {
        expect(revealGroupStart(text, i), i);
      }
    });

    test('the group start of a Latin word is the word start', () {
      const text = 'hello world';
      expect(revealGroupStart(text, 3), 0);
      expect(revealGroupStart(text, 8), 6);
    });
  });

  testWidgets('streaming CJK renders as its own paragraph', (tester) async {
    // Smoke test: the vendored copy still builds a reply at all, and the
    // per-character grouping did not break the paragraph into pieces that no
    // longer share a line.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GptMarkdown(
            '模型已经加载完毕，可以开始对话。',
            animation: GptMarkdownAnimation.blurIn,
            isStreaming: true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(RichText), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
