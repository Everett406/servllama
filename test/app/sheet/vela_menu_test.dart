import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/app/sheet/vela_menu.dart';

Future<void> _open(WidgetTester tester, {double top = 400}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Positioned(
              top: top,
              left: 0,
              right: 0,
              child: Center(
                child: VelaAnchor(
                  child: Builder(
                    builder: (chipContext) => GestureDetector(
                      onTap: () => VelaAnchor.of(
                        chipContext,
                      )!.show<void>(context: chipContext, builder: (_) => const SizedBox(height: 160, child: Text('panel'))),
                      child: const SizedBox(
                        key: Key('trigger'),
                        width: 120,
                        height: 40,
                        child: Text('trigger'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('trigger')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the panel sits against its trigger, not the middle', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('panel'), findsOneWidget);

    final trigger = tester.getRect(find.byKey(const Key('trigger')));
    final panel = tester.getRect(find.byType(VelaMenuPanel));

    // The whole point. A panel that opens in the middle of the screen is a
    // dialog; this one has to touch the thing that opened it.
    final verticalGap = trigger.top - panel.bottom;
    expect(
      verticalGap.abs(),
      lessThan(24),
      reason: 'the panel should sit just above its trigger',
    );
    expect(panel.left, closeTo(trigger.left, 12));
  });

  testWidgets('a trigger low on the screen opens upward', (tester) async {
    await _open(tester, top: 460);
    final trigger = tester.getRect(find.byKey(const Key('trigger')));
    final panel = tester.getRect(find.byType(VelaMenuPanel));

    expect((panel.bottom - trigger.top).abs(), lessThan(24));
    expect(panel.top, lessThan(trigger.top));
    // Still on screen: a menu that runs off the bottom with half its list
    // unreachable is worse than one that opened the other way.
    expect(panel.bottom, lessThanOrEqualTo(600));
  });

  testWidgets('a trigger high on the screen opens downward', (tester) async {
    await _open(tester, top: 60);
    final trigger = tester.getRect(find.byKey(const Key('trigger')));
    final panel = tester.getRect(find.byType(VelaMenuPanel));

    expect((panel.top - trigger.bottom).abs(), lessThan(24));
    expect(panel.top, greaterThan(trigger.top));
    expect(panel.bottom, lessThanOrEqualTo(600));
  });

  testWidgets('the panel is a rounded card of menu width', (tester) async {
    await _open(tester);
    final panel = tester.getRect(find.byType(VelaMenuPanel));
    final screen = tester.view.physicalSize.width / tester.view.devicePixelRatio;

    // The panel is 248 wide unless it has to slide to stay on screen, which
    // it does next to a right-edge trigger. What must hold either way is that
    // it is menu-sized and fully visible.
    expect(panel.width, lessThanOrEqualTo(248));
    expect(panel.width, greaterThan(200));
    expect(panel.left, greaterThanOrEqualTo(0));
    expect(panel.right, lessThanOrEqualTo(screen));
    expect(
      tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((w) => w.decoration)
          .whereType<BoxDecoration>()
          .any((d) => (d.borderRadius as BorderRadius?)?.topLeft.x == 18),
      isTrue,
      reason: 'the panel should carry the 18dp menu radius',
    );
  });

  testWidgets('tapping outside closes it without picking anything', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('panel'), findsOneWidget);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.text('panel'), findsNothing);
  });
}
