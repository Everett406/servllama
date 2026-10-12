import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/app/sheet/vela_sheet.dart';

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showVelaSheet<void>(
                context: context,
                builder: (_) => const SizedBox(height: 200, child: Text('body')),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a sheet is inset from the sides and has no square corners', (
    tester,
  ) async {
    await _open(tester);

    final body = find.text('body');
    expect(body, findsOneWidget);

    final screen = tester.getSize(find.byType(Scaffold).first).width;
    final left = tester.getTopLeft(body).dx;
    final right = screen - tester.getTopRight(body).dx;

    // The old sheet ran edge to edge with two square bottom corners, which is
    // what made it read as a drawer. It is a card now.
    expect(left, greaterThan(8));
    expect(right, greaterThan(8));
    expect(left, closeTo(right, 1.0), reason: 'the gutters should match');

    final decoration = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((w) => w.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.borderRadius is BorderRadius);
    final radius = (decoration.borderRadius! as BorderRadius).bottomLeft.x;
    expect(radius, greaterThan(16));
  });

  testWidgets('a sheet clears the navigation bar rather than sitting on it', (
    tester,
  ) async {
    await _open(tester);

    final body = find.text('body');
    final bottomGap = tester.getSize(find.byType(Scaffold).first).height -
        tester.getBottomRight(body).dy;

    expect(bottomGap, greaterThan(8));
  });

  testWidgets('dragging the handle dismisses; dragging the body does not', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('body'), findsOneWidget);

    // The body is not a drag target. A list inside a sheet has its own
    // scroll, and one recogniser on the body fights every flick.
    await tester.drag(find.text('body'), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(
      find.text('body'),
      findsOneWidget,
      reason: 'dragging the content must not dismiss the sheet',
    );

    // The handle is.
    await tester.drag(find.byKey(velaSheetDragHandle), const Offset(0, 260));
    await tester.pumpAndSettle();
    expect(find.text('body'), findsNothing);
  });

  testWidgets('a small drag springs back instead of dismissing', (
    tester,
  ) async {
    await _open(tester);

    await tester.drag(find.byKey(velaSheetDragHandle), const Offset(0, 18));
    await tester.pumpAndSettle();

    expect(find.text('body'), findsOneWidget);
  });
}
