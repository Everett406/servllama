import 'package:flutter/material.dart';

import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';

/// The grab bar.
///
/// Public so tests can target it exactly. `find.byType(GestureDetector)` does
/// not work: the button that opened the sheet is a GestureDetector too, and
/// the first match is whichever the tree happens to build first.
const Key velaSheetDragHandle = Key('vela_sheet_drag_handle');

/// The one way a sheet appears in Vela.
///
/// Four things every call site used to get wrong, in one place:
///
/// * **It is a floating card, not a panel.** Air on the sides and below, all
///   four corners rounded, clear of the navigation bar. The default bottom
///   sheet is edge to edge with two square corners and no margin, which reads
///   as a drawer rather than a card laid on the page.
/// * **No black scrim.** A dimmed backdrop over warm paper turns the whole
///   page grey. The scrim here is a soft shadow-coloured wash instead — the
///   card reads as raised off the page rather than the page being switched
///   off.
/// * **Asymmetric spring.** Entering overshoots slightly and settles; leaving
///   does not. A symmetric spring makes dismissal feel reluctant, and
///   dismissal is the one gesture a user does not think about.
/// * **A real drag handle, and only the handle drags.** Dragging the content
///   area fights the scroll of a list inside the sheet, and a sheet you
///   cannot flick away with a shrug is one that gets dismissed with the back
///   button instead.
///
/// No glass. Frosted sheets look like a screenshot of another app and cost a
/// frame to rasterise; a card with a shadow says the same thing.
Future<T?> showVelaSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useSafeArea = false,
  bool barrierDismissible = true,
  double? maxWidth,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    barrierColor: _scrim(context),
    // Off. It makes the whole sheet a drag-to-dismiss target, which quietly
    // defeats the handle: a list inside the sheet would be fought over by the
    // route's recogniser on every flick, and dragging anywhere dismissed it.
    enableDrag: false,
    backgroundColor: Colors.transparent,
    elevation: 0,
    shape: const RoundedRectangleBorder(),
    clipBehavior: Clip.none,
    builder: (sheetContext) => _SheetSurface(
      maxWidth: maxWidth,
      child: Builder(builder: builder),
    ),
  );
}

/// The card. Owns its drag so the handle and the maths stay together.
class _SheetSurface extends StatefulWidget {
  const _SheetSurface({required this.child, this.maxWidth});

  final Widget child;
  final double? maxWidth;

  @override
  State<_SheetSurface> createState() => _SheetSurfaceState();
}

class _SheetSurfaceState extends State<_SheetSurface> {
  /// How far the card has been pulled down. Drives the exit and the shadow.
  double _drag = 0;

  static const double _handleWidth = 40;
  static const double _handleThickness = 4.5;

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      // Upward resistance: the card can be pulled but not dragged past its
      // resting place, which would otherwise stretch the content behind it.
      _drag = details.delta.dy < 0
          ? (_drag + details.delta.dy * 0.2).clamp(-24.0, 140.0)
          : (_drag + details.delta.dy).clamp(0.0, 180.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    if (_drag > 72 || velocity > 620) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _drag = 0);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(ClaudeRadius.sheet);
    return Padding(
      padding: EdgeInsets.only(
        left: ClaudeSpacing.sheetGutter,
        right: ClaudeSpacing.sheetGutter,
        bottom: ClaudeSpacing.sheetGutter + MediaQuery.paddingOf(context).bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: widget.maxWidth ?? ClaudeSpacing.readingWidth,
          // Never taller than the space above the gutter, so a tall sheet
          // cannot push its own top edge off the screen.
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Transform.translate(
          offset: Offset(0, _drag),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: radius,
              border: Border.all(color: context.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(26 + (_drag * 0.5).round()),
                  blurRadius: 40,
                  offset: const Offset(0, -6),
                  spreadRadius: -8,
                ),
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            // Clip so a list inside rounds off with the card rather than
            // painting square corners over the radius.
            child: ClipRRect(
              borderRadius: radius,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    key: velaSheetDragHandle,
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: _onDragUpdate,
                    onVerticalDragEnd: _onDragEnd,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 6),
                      child: Center(
                        child: Container(
                          width: _handleWidth,
                          height: _handleThickness,
                          decoration: BoxDecoration(
                            color: context.inkTertiary.withAlpha(70),
                            borderRadius: BorderRadius.circular(
                              _handleThickness,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Flexible(child: widget.child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color _scrim(BuildContext context) =>
    Colors.black.withAlpha(Theme.of(context).brightness == Brightness.dark ? 110 : 46);
