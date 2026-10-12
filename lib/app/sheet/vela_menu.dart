import 'package:flutter/material.dart';

import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/keyboard/keyboard_state.dart';

/// Marks the widget a menu hangs off.
///
/// The panel tracks this live through a [LayerLink]. It used to capture the
/// trigger's `Rect` once when the menu opened and place the panel from that
/// snapshot — which looked fine until the layout moved. Open the menu with the
/// keyboard up, put the keyboard away, and the panel stayed at the height the
/// composer had while the keyboard was up: hanging in the middle of an empty
/// screen, nowhere near the button that opened it.
///
/// A follower also removes the height guesswork the snapshot needed. The panel
/// can be any height and still sit against its trigger.
class VelaAnchor extends StatefulWidget {
  const VelaAnchor({
    super.key,
    required this.child,
    this.prefer = AxisDirection.up,
  });

  final Widget child;

  /// Which side the menu opens on when there is room for it.
  final AxisDirection prefer;

  /// The nearest enclosing anchor, if [context] is inside one.
  static VelaAnchorState? of(BuildContext context) =>
      context.findAncestorStateOfType<VelaAnchorState>();

  @override
  State<VelaAnchor> createState() => VelaAnchorState();
}

class VelaAnchorState extends State<VelaAnchor> {
  final LayerLink _link = LayerLink();

  /// Space between the trigger and the panel.
  static const double _gap = 8;

  Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    double width = 248,
  }) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) {
      return Future<T?>.value();
    }
    final media = MediaQuery.of(context);
    final trigger = box.localToGlobal(Offset.zero) & box.size;

    // Decide the side once, from the room there is right now. After that the
    // follower keeps the panel attached even if the layout moves; a panel that
    // needs its side re-deciding every frame is a panel that flickers between
    // two positions as the keyboard animates.
    final roomAbove = trigger.top - media.padding.top - 8;
    final roomBelow = media.size.height - trigger.bottom - media.padding.bottom - 8;
    const estimated = 220.0;

    final preferUp = widget.prefer == AxisDirection.up;
    final roomPreferred = preferUp ? roomAbove : roomBelow;
    final roomOther = preferUp ? roomBelow : roomAbove;
    // Symmetric. The two branches used to differ: the upward-preferred one
    // could fall back to the other side, the downward-preferred one could not.
    // An engine button at the bottom of the composer asked for "open below",
    // found no room, and opened below anyway — the panel landed at y 899..1099
    // on a 900pt screen, entirely off it.
    final openAbove = switch (roomPreferred) {
      final r when r >= estimated => preferUp,
      _ when roomOther >= estimated => !preferUp,
      _ => roomAbove >= roomBelow,
    };

    // Keep the panel's left edge on the trigger's left edge, and slide it back
    // in if that would run it off the right of the screen. The vertical side
    // is the follower's job; horizontal is not something it can express,
    // because the panel's width is only known after layout.
    final desiredLeft = trigger.left;
    final maxLeft = media.size.width - width - 8;
    final horizontalShift = desiredLeft > maxLeft
        ? (maxLeft - desiredLeft).clamp(-desiredLeft + 8, 0.0)
        : 0.0;

    // Opening a menu from a focused field should not be a way to close it, and
    // closing the menu should not be a way to open it.
    final keyboardWasUp = keyboardVisible(context);

    return showGeneralDialog<T>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      // Transparent on purpose: the barrier catches the outside tap, it does
      // not dim the page. A dimmed page behind a 248dp menu makes the menu
      // look like it lost to a dialog.
      barrierColor: Colors.transparent,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (dialogContext, animation, _) => Center(
        // The follower's child must be the panel itself, not a full-screen
        // box with the panel inside it.
        //
        // `followerAnchor` names a point on the child's own rect. Give it a
        // screen-filling box and `topLeft` means the *screen's* top-left, so
        // aligning that to the trigger's bottom shifts the whole 900pt box
        // down by the trigger's height and the panel — parked at the bottom of
        // that box — lands hundreds of points off screen.
        //
        // The page does not fill the screen on purpose: the transparent
        // barrier below it is what has to catch the outside tap.
        child: CompositedTransformFollower(
          link: _link,
          // Corner to corner: the panel's edge and the trigger's edge end up
          // one gap apart, without the panel ever needing to know its height.
          // Opening above: the panel's *bottom* edge meets the trigger's
          // *top* edge. Opening below: the panel's top meets the trigger's
          // bottom. These were the wrong way round, which put the panel's top
          // on the trigger's bottom and sent it downward off the screen.
          targetAnchor: openAbove ? Alignment.topLeft : Alignment.bottomLeft,
          followerAnchor: openAbove ? Alignment.bottomLeft : Alignment.topLeft,
          offset: Offset(horizontalShift, openAbove ? -_gap : _gap),
          child: Transform.scale(
            scale: 0.86 + 0.14 * animation.value,
            // Origin at the corner facing the trigger. Without it the panel
            // scales around its centre and reads as a small dialog that
            // happened to be nearby — the easiest thing to get wrong here.
            alignment: openAbove
                ? Alignment.bottomLeft
                : Alignment.topLeft,
            child: FadeTransition(
              opacity: animation,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight:
                      media.size.height -
                      media.padding.top -
                      media.padding.bottom -
                      16,
                ),
                child: VelaMenuPanel(
                  width: width,
                  child: Builder(builder: builder),
                ),
              ),
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      if (keyboardWasUp) FocusManager.instance.primaryFocus?.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) =>
      CompositedTransformTarget(link: _link, child: widget.child);
}

/// The panel itself: a rounded card, menu width, soft shadow.
class VelaMenuPanel extends StatelessWidget {
  const VelaMenuPanel({super.key, required this.child, this.width = 248});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: width,
        constraints: const BoxConstraints(maxHeight: 420),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(38),
              blurRadius: 32,
              offset: const Offset(0, 8),
              spreadRadius: -6,
            ),
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        // Clip so a long list rounds off with the panel instead of painting
        // square corners over the radius.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: child,
        ),
      ),
    );
  }
}

/// A row inside a menu panel.
///
/// Sized like a list row, not like a settings row. The model picker used to be
/// a sheet with settings-sized rows, which is most of why it read as bloated:
/// twice the height it needs and a divider under every line.
class VelaMenuItem extends StatelessWidget {
  const VelaMenuItem({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.selected = false,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: selected ? context.accent : context.ink,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null && subtitle!.trim().isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.inkTertiary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
