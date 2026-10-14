import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/chat/widgets/answer_markdown.dart';

/// The bug being locked down here is only visible as a sequence. Every frame
/// on its own looks reasonable: the table is either there or held back. The
/// reader sees the flicker because the answer changes twenty times over a
/// couple of seconds.
void main() {
  const full = '先看结果。\n\n'
      '| 名称 | 数量 |\n'
      '| --- | --- |\n'
      '| 苹果 | 3 |\n'
      '| 香蕉 | 5 |\n'
      '| 橘子 | 8 |\n';

  Future<bool> placeholderShown(WidgetTester tester, String content) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AnswerMarkdown(content: content, isStreaming: true, style: const TextStyle()),
          ),
        ),
      ),
    );
    await tester.pump();
    return find.byKey(const Key('streaming_table_placeholder')).evaluate().isNotEmpty;
  }

  testWidgets('the table placeholder does not blink while rows arrive', (
    tester,
  ) async {
    var seenAfterFirstAppearance = false;
    var heldFrom = -1;

    for (var length = 1; length <= full.length; length++) {
      final shown = await placeholderShown(tester, full.substring(0, length));
      if (shown) {
        if (heldFrom < 0) heldFrom = length;
        seenAfterFirstAppearance = true;
      } else if (seenAfterFirstAppearance) {
        // Back to a real table with rows still missing: the blink.
        fail(
          'the table stopped being held back at length $length of '
          '${full.length}, so it renders, blinks and is held back again',
        );
      }
    }

    expect(seenAfterFirstAppearance, isTrue, reason: 'never held back a table');
    // Once held back it stays held back for the rest of the table. Only the
    // end of the stream, tested separately, turns it into a real one.
    expect(
      heldFrom,
      lessThanOrEqualTo(full.indexOf('\n', full.indexOf('| 苹果')) + 1),
      reason: 'held back only after the table had already started filling',
    );
  });

  testWidgets('text before an open table still renders while it streams', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnswerMarkdown(
            content: '先看结果。\n\n| 名称 | 数量 |\n| --- | --- |\n| 苹果 ',
            isStreaming: true,
            style: const TextStyle(),
          ),
        ),
      ),
    );
    await tester.pump();

    // The text before the table still renders while the table is held back.
    // Asserting on RichText and the key rather than on a string: the paragraph
    // is split into per-character reveal groups, so no single Text holds it.
    expect(find.byType(RichText), findsWidgets);
    expect(find.byKey(const Key('streaming_table_placeholder')), findsOneWidget);
  });

  testWidgets('a finished reply shows the table, not the placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnswerMarkdown(
            content: full,
            isStreaming: false,
            style: const TextStyle(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('streaming_table_placeholder')), findsNothing);
    expect(find.text('香蕉'), findsOneWidget);
  });
}
