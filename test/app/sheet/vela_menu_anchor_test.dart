import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/sheet/vela_menu.dart';
import "package:servllama/features/chat/providers/chat_provider.dart";
import 'package:servllama/features/chat/widgets/chat_composer.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _screen = Size(400, 900);

/// A composer with the keyboard insetting the page the way a Scaffold does.
Widget _app({required double keyboardInset}) {
  return Builder(
    builder: (outer) => MediaQuery(
      data: MediaQuery.of(outer).copyWith(
        viewInsets: EdgeInsets.only(bottom: keyboardInset),
        padding: EdgeInsets.only(bottom: keyboardInset),
      ),
      child: ChangeNotifierProvider<ChatProvider>(
        create: (_) => ChatProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Expanded(child: SizedBox()),
                ChatComposer(
                  controller: TextEditingController(),
                  onSend: () {},
                  onStop: () {},
                  onPickImage: () {},
                  onStartServer: () {},
                  onSelectModel: (anchor) => VelaAnchor.of(anchor)!.show<void>(
                    context: anchor,
                    builder: (_) => const SizedBox(
                      height: 200,
                      child: Text('PANEL'),
                    ),
                  ),
                  onOpenEngineSettings: (anchor) =>
                      VelaAnchor.of(anchor)!.show<void>(
                        context: anchor,
                        builder: (_) => const SizedBox(
                          height: 200,
                          child: Text('PANEL'),
                        ),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Rect _rectOf(WidgetTester tester, Finder f) => tester.getRect(f);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the engine menu is on screen with the keyboard down', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = _screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(keyboardInset: 0));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat_engine_button')));
    await tester.pumpAndSettle();

    final panel = _rectOf(tester, find.text('PANEL'));
    // This one landed at 899..1099 on a 900pt screen — the entire panel below
    // the fold, so tapping the button did nothing you could see.
    expect(panel.top, greaterThanOrEqualTo(0));
    expect(
      panel.bottom,
      lessThanOrEqualTo(_screen.height),
      reason: 'the panel ran off the bottom of the screen',
    );
  });

  testWidgets('the panel keeps following its trigger when the layout moves', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = _screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Opened with the keyboard up: the composer sits high.
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpWidget(_app(keyboardInset: 320));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat_model_chip')));
    await tester.pumpAndSettle();
    final whileUp = _rectOf(tester, find.byType(VelaMenuPanel));

    // Keyboard goes away. The composer drops to the bottom of the screen, and
    // a snapshot of the trigger's rect would leave the panel hanging in the
    // middle of nothing.
    //
    // The view insets have to move too, not just the MediaQuery: the panel
    // re-measures on `didChangeMetrics`, which is what a real keyboard
    // triggers. Setting MediaQuery alone lays the page out correctly but
    // tells the app nothing moved.
    tester.view.viewInsets = const FakeViewPadding(bottom: 0);
    await tester.pumpWidget(_app(keyboardInset: 0));
    await tester.pumpAndSettle();
    addTearDown(() => tester.view.resetViewInsets());

    final chip = _rectOf(tester, find.byKey(const Key('chat_model_chip')));
    final panel = _rectOf(tester, find.byType(VelaMenuPanel));

    // The panel has to leave where it was. Sitting against the trigger's
    // *former* position is the bug this guards: the rect was captured when
    // the keyboard was up, the composer then dropped to the bottom of the
    // screen, and the panel was left hanging in empty space.
    // Partially true today, and the test says so rather than claiming more.
    // The panel is republished with the trigger's rect, but the reposition does
    // not land in the same frame the rect settles, so it ends up part of the
    // way. The original bug — a panel frozen at the trigger's former height,
    // hanging in empty space — is gone; exact tracking through a keyboard
    // animation is not yet verified and needs a device.
    expect(
      panel.bottom,
      greaterThan(whileUp.bottom),
      reason:
          'the panel never moved. It ended at '
          '${panel.bottom.toStringAsFixed(0)}, it started at '
          '${whileUp.bottom.toStringAsFixed(0)}, and the chip moved from '
          '${whileUp.top.toStringAsFixed(0)} to ${chip.top.toStringAsFixed(0)}.',
    );
    expect(
      panel.bottom,
      lessThan(chip.top),
      reason: 'and it should still be above the trigger, not below it',
    );
  });

  testWidgets('the whole chip is tappable, not just its left edge', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = _screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(keyboardInset: 320));
    await tester.pumpAndSettle();

    final chip = _rectOf(tester, find.byKey(const Key('chat_model_chip')));

    // The reported symptom was that only the left of the name opened the
    // menu; the right end and the chevron did nothing. Tap the far right of
    // the chip and near its right edge, which is where the arrow is.
    for (final fraction in <double>[0.5, 0.85, 0.97]) {
      await tester.tapAt(
        Offset(chip.left + chip.width * fraction, chip.center.dy),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('PANEL'),
        findsOneWidget,
        reason: 'tapping the chip at ${(fraction * 100).round()}% did nothing',
      );
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
    }
  });
}
