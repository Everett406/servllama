import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/widgets/chat_message_item.dart';
import 'package:servllama/features/chat/widgets/chat_message_list.dart';

/// A short turn used to drift into the middle of the measure.
///
/// The list wrapped every item in a `Center` to cap the reading width, and
/// Center also centres. A message item is a Column that sizes itself to its
/// widest child, so a long turn filled the measure and looked right-aligned
/// by accident, while a short one came out narrow and got parked in the
/// middle. This pins the geometry so it cannot come back.
void main() {
  ChatMessageRecord user(String id, String text) => ChatMessageRecord(
    id: id,
    role: ChatRole.user,
    content: text,
    createdAt: DateTime(2026, 10, 12),
  );

  testWidgets('a short user turn is right-aligned like a long one', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    Widget turn(ChatMessageRecord m) =>
        ChatMessageRow(child: ChatMessageItem(message: m));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [turn(user('long', '这是一条很长的消息，' * 40)), turn(user('short', '好'))],
          ),
        ),
      ),
    );
    await tester.pump();

    final measure = tester.getSize(find.byType(ChatMessageRow).first).width;
    final longBubble = tester.getRect(
      find.byKey(const Key('chat_message_target_long_content')),
    );
    final shortBubble = tester.getRect(
      find.byKey(const Key('chat_message_target_short_content')),
    );

    // Both bubbles end at the same x. Alignment is not "somewhere on the
    // right" — it is flush, or it has drifted.
    expect(
      (longBubble.right - shortBubble.right).abs(),
      lessThan(0.5),
      reason:
          'short bubble right ${shortBubble.right} vs long ${longBubble.right}',
    );
    // And that edge is the measure's right edge, not its middle.
    expect(shortBubble.right, greaterThan(measure * 0.9));
  });
}