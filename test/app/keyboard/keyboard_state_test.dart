import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/app/keyboard/keyboard_state.dart';

void main() {
  group('DismissKeyboardOnTap', () {
    testWidgets('a tap outside the input drops focus', (tester) async {
      final outside = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(focusNode: outside),
                Expanded(
                  child: DismissKeyboardOnTap(
                    // stretch, or the Column centres it and the box has no
                    // width — the tap then lands in empty space and the test
                    // passes or fails for reasons that have nothing to do with
                    // focus. This cost an hour.
                    child: const SizedBox.expand(
                      child: ColoredBox(color: Color(0xFFFFFFFF)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      outside.requestFocus();
      await tester.pump();
      expect(outside.hasFocus, isTrue);

      await tester.tap(find.byType(ColoredBox));
      await tester.pump();

      // This is the whole point. Without dropping focus, a dismissed keyboard
      // leaves the node focused and the next rebuild re-attaches the IME.
      expect(outside.hasFocus, isFalse);
    });

    testWidgets('a control underneath still receives its tap', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DismissKeyboardOnTap(
              child: Center(
                child: TextButton(onPressed: () => taps++, child: const Text('go')),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pump();

      // The dismiss layer must not swallow the button.
      expect(taps, 1);
    });
  });

  group('KeyboardStateRestorer', () {
    for (final (label, insets, expectFocus) in [
      ('a return without a keyboard stays without one', 0.0, false),
      ('a return with the keyboard up brings it back', 300.0, true),
    ]) {
      testWidgets(label, (tester) async {
        final node = FocusNode();
        addTearDown(node.dispose);

        await tester.pumpWidget(
          _withInsets(
            insets,
            MaterialApp(home: _Host(composer: node)),
          ),
        );

        // The page records on the way out and restores on the way back, which
        // is all this mixin exists for.
        await tester.tap(find.byKey(const Key('leave')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('return')));
        await tester.pump();

        expect(node.hasFocus, expectFocus);
      });
    }

    testWidgets('a page that was never recorded leaves focus alone', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        _withInsets(0, MaterialApp(home: _Host(composer: node))),
      );

      node.requestFocus();
      await tester.pump();

      await tester.tap(find.byKey(const Key('return')));
      await tester.pump();

      // Restoring what was never recorded would close a keyboard the user
      // opened on purpose.
      expect(node.hasFocus, isTrue);
    });
  });
}

Widget _withInsets(double bottom, Widget child) {
  return Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(viewInsets: EdgeInsets.only(bottom: bottom)),
      child: child,
    ),
  );
}

class _Host extends StatefulWidget {
  const _Host({required this.composer});

  final FocusNode composer;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host>
    with WidgetsBindingObserver, KeyboardStateRestorer<_Host> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextButton(
            key: const Key('leave'),
            onPressed: rememberKeyboard,
            child: const Text('leave'),
          ),
          TextButton(
            key: const Key('return'),
            onPressed: () => restoreKeyboard(focusNode: widget.composer),
            child: const Text('return'),
          ),
          TextField(focusNode: widget.composer),
        ],
      ),
    );
  }
}
