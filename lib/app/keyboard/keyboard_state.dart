import 'package:flutter/material.dart';

/// Whether the soft keyboard is on screen.
bool keyboardVisible(BuildContext context) =>
    MediaQuery.viewInsetsOf(context).bottom > 0;

/// Focus and the keyboard are not the same thing, and conflating the two is
/// why the keyboard kept coming back on its own.
///
/// The platform back gesture hides the IME without unfocusing the node, so
/// the field stays focused with no keyboard in front of it. Anything that
/// rebuilds and re-lays-out the field then re-attaches the input connection
/// and the keyboard springs back — tapping Retry after a reply was enough to
/// trigger it. Nothing in the app was asking for it.
///
/// This mixin keeps the two apart. It watches the view insets, remembers what
/// the user actually had, and puts it back on return: a page that was left
/// with the keyboard up comes back up, and one that was left without it comes
/// back without it. Without it every return from a sub-page re-attached the
/// IME, which is the other half of the complaint.
///
/// Call [rememberKeyboard] before navigating away and [restoreKeyboard] once
/// the route is back on top.
///
/// The page applies `WidgetsBindingObserver` alongside this mixin; the mixin
/// only supplies [didChangeMetrics].
mixin KeyboardStateRestorer<T extends StatefulWidget> on State<T> {
  bool _wasVisible = false;
  bool _recorded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this as WidgetsBindingObserver);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this as WidgetsBindingObserver);
    super.dispose();
  }

  void didChangeMetrics() {
    if (!mounted) return;
    final visible = keyboardVisible(context);
    if (visible != _wasVisible) {
      _wasVisible = visible;
      _recorded = true;
    }
  }

  /// What the user had when the page was last current.
  bool get keyboardWasVisible => _wasVisible;

  /// Record the keyboard state. Call immediately before pushing a route, while
  /// this page is still on top and its insets are the real ones — after the
  /// transition starts they describe the new page instead.
  void rememberKeyboard() {
    _wasVisible = keyboardVisible(context);
    _recorded = true;
  }

  /// Put the keyboard back the way it was. Call after a pop completes.
  ///
  /// A null [focusNode] only ever hides it: restoring an open keyboard needs
  /// a node to focus, and guessing one would be worse than leaving it closed.
  void restoreKeyboard({FocusNode? focusNode}) {
    if (!_recorded) return;
    if (_wasVisible) {
      focusNode?.requestFocus();
    } else if (focusNode != null) {
      focusNode.unfocus();
    }
  }
}

/// Dismisses the keyboard when the user taps somewhere that is not the input.
///
/// Without this, dismissing the IME leaves the field focused, so the next
/// rebuild re-attaches it and the keyboard reappears — which reads as the app
/// popping the keyboard up by itself.
class DismissKeyboardOnTap extends StatelessWidget {
  const DismissKeyboardOnTap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Translucent so the gesture sees hits through an unpainted area, but
      // still deferring to any control underneath.
      behavior: HitTestBehavior.translucent,
      // Unfocusing the scope is not enough: EditableText holds its own node
      // and puts focus straight back. Taking the primary node down directly
      // is what actually clears it.
      onTapDown: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      child: child,
    );
  }
}
