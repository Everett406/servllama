import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/chat/widgets/thinking_card.dart';

Widget _line({
  required String messageId,
  required bool live,
  required bool answerStarted,
  DateTime? promptedAt,
  DateTime? answeredAt,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ThinkingLine(
        content: 'let me think about that',
        expanded: false,
        live: live,
        answerStarted: answerStarted,
        messageId: messageId,
        promptedAt: promptedAt,
        answeredAt: answeredAt,
        onToggle: () {},
      ),
    ),
  );
}

void main() {
  // Unique id per test: ThinkingTimings is keyed by message id in static maps
  // that outlive a single test.
  var seq = 0;
  String nextId() => 'msg-${seq++}';

  testWidgets('the row and the sheet share one clock', (tester) async {
    final id = nextId();
    final prompted = DateTime.now().subtract(const Duration(seconds: 5));
    await tester.pumpWidget(
      _line(
        messageId: id,
        live: true,
        answerStarted: false,
        promptedAt: prompted,
        answeredAt: prompted,
      ),
    );
    await tester.pump();

    // Two clocks is the whole bug. The sheet used to build its own notifier
    // from a `fallback` the row handed it, so the two could disagree — and
    // after a rebuild the row's fallback came out at zero.
    expect(
      identical(ThinkingTimings.clockFor(id), ThinkingTimings.clockFor(id)),
      isTrue,
    );
  });

  testWidgets('a frozen clock survives the row being rebuilt', (tester) async {
    final id = nextId();
    final prompted = DateTime.now().subtract(const Duration(seconds: 9));
    // The placeholder message is created at send time, not when the first
    // token lands — which is what made the old fallback span come out at zero
    // and the row read 0s after counting to eight.
    final created = prompted.add(const Duration(milliseconds: 400));
    final clock = ThinkingTimings.clockFor(id);

    await tester.pumpWidget(
      _line(
        messageId: id,
        live: true,
        answerStarted: false,
        promptedAt: prompted,
        answeredAt: created,
      ),
    );
    await tester.pump();

    // Whatever the ticker last showed is the answer.
    final atStop = Duration(seconds: 8);
    clock.value = atStop;

    await tester.pumpWidget(
      _line(
        messageId: id,
        live: true,
        answerStarted: true,
        promptedAt: prompted,
        answeredAt: created,
      ),
    );
    await tester.pump();

    // Transcript rebuilds the row. This is where it used to snap to zero.
    await tester.pumpWidget(
      _line(
        messageId: id,
        live: false,
        answerStarted: true,
        promptedAt: prompted,
        answeredAt: created,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(
      ThinkingTimings.clockFor(id).value,
      atStop,
      reason: 'the elapsed time moved after the answer started',
    );
  });

  test('freeze keeps the first stop and ignores later ones', () {
    final id = nextId();
    ThinkingTimings.freeze(id, const Duration(seconds: 8));
    ThinkingTimings.freeze(id, const Duration(seconds: 40));

    expect(ThinkingTimings.frozen(id), const Duration(seconds: 8));
    expect(ThinkingTimings.clockFor(id).value, const Duration(seconds: 8));
  });

  test('a fresh clock starts at zero rather than throwing', () {
    expect(ThinkingTimings.clockFor('never-marked').value, Duration.zero);
  });
}
