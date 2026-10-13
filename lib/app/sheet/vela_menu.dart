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

class VelaAnchorState extends State<VelaAnchor>
    with WidgetsBindingObserver {
  /// Gap between the trigger and the panel.
  static const double gap = 8;

  final LayerLink _link = LayerLink();

  /// The trigger's rect, republished whenever it moves.
  ///
  /// The panel reads this on every layout. Snapshotting the rect once at open
  /// time is what made the menu fail to follow: the keyboard came down, the
  /// composer dropped to the bottom of the screen, and the panel stayed at the
  /// height the trigger used to have — hanging in the middle of an empty page.
  final ValueNotifier<Rect?> _trigger = ValueNotifier<Rect?>(null);

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _remeasure();
      // A keyboard is the common case, and it moves over ~250ms: re-arm so
      // the panel keeps pace for the whole animation rather than snapping once
      // at the end — or not at all, if the tracking loop had already settled.
      _onTriggerMoved?.call();
    });
  }

  /// Re-arms the follow loop. Set for the lifetime of an open menu.
  VoidCallback? _onTriggerMoved;

  @visibleForTesting
  void rearmForTest() => _onTriggerMoved?.call();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _remeasure() {
    final render = _key.currentContext?.findRenderObject();
    if (render is! RenderBox || !render.hasSize || !render.attached) return;
    final next = render.localToGlobal(Offset.zero) & render.size;
    // Only publish a real move. A notifier that fires every frame rebuilds the
    // panel every frame even when nothing changed.
    if (_trigger.value != next) _trigger.value = next;
  }

  final GlobalKey _key = GlobalKey();

  Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    double width = 248,
  }) {
    // Not an `as RenderBox?`: inside a ListView the anchor's render object can
    // resolve to a sliver, and the cast threw — which took the whole menu down
    // with it rather than skipping it.
    final render = context.findRenderObject();
    if (render is! RenderBox || !render.hasSize || !render.attached) {
      return Future<T?>.value();
    }
    final box = render;

    final media = MediaQuery.of(context);
    _trigger.value = box.localToGlobal(Offset.zero) & box.size;
    // A guess, refined by the delegate once the real height is known. It has
    // to exist here because the entrance scales from the corner facing the
    // trigger, and that corner depends on which side was chosen.
    // Which side, decided once and used by both the delegate and the entrance
    // animation. When these two disagreed the delegate placed the panel below
    // the trigger while the scale still grew from the top-left corner, so the
    // panel visibly slid as it opened.
    const estimate = 220.0;
    final triggerTop = box.localToGlobal(Offset.zero).dy;
    final roomAbove = triggerTop - media.padding.top - VelaAnchorState.gap;
    final preferUp = widget.prefer == AxisDirection.up;
    final openAbove = preferUp
        ? roomAbove >= estimate
        : roomAbove < estimate && triggerTop < media.size.height / 2;

    // Opening a menu from a focused field should not be a way to close it, and
    // closing the menu should not be a way to open it.
    final keyboardWasUp = keyboardVisible(context);

    // Track the trigger every frame while the menu is open.
    //
    // `didChangeMetrics` fires once when the keyboard starts moving, not once
    // per frame of its ~250ms animation. Measuring on that single event left
    // the panel 270pt behind the trigger — it moved a little, which looked
    // like it was following when it was really only agreeing to the first
    // frame. A post-frame chain tracks it properly.
    // Track, but stop once the trigger settles.
    //
    // A post-frame callback that reschedules itself forever leaves the
    // scheduler permanently busy: `pumpAndSettle` never returns, the entrance
    // animation is abandoned part-way, and every measurement taken afterwards
    // is off by whatever the scale had reached. Stopping after the rect holds
    // still for two frames fixes that and stops the loop costing a frame a
    // second while a menu sits open and nothing moves.
    var tracking = true;
    var armed = false;
    void arm() {
      if (!tracking || !mounted || armed) return;
      armed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        armed = false;
        if (!tracking || !mounted) return;
        final before = _trigger.value;
        _remeasure();
        // Only keep going while something is still moving. A loop that
        // reschedules itself unconditionally leaves the scheduler permanently
        // busy, and the entrance animation is then abandoned part-way with
        // every later measurement carrying whatever scale it reached. Stopping
        // on "nothing moved" is both correct and free.
        if (_trigger.value != before) arm();
      });
    }

    _onTriggerMoved = arm;
    arm();

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
      pageBuilder: (dialogContext, animation, _) => ValueListenableBuilder<Rect?>(
        valueListenable: _trigger,
        builder: (context, trigger, _) => CustomSingleChildLayout(
        // The follower knows where the trigger is but not how tall the panel
        // turned out to be, and picking a side needs both — guessing the
        // height from a constant is what put a panel at y -89 on an 800x600
        // screen.
        delegate: _AnchoredMenuDelegate(
          trigger: trigger,
          openAbove: openAbove,
          safeTop: media.padding.top,
          safeBottom: media.padding.bottom,
        ),
        child: Transform.scale(
          scale: 0.86 + 0.14 * animation.value,
          // Origin at the corner facing the trigger. This is what makes the
          // panel look like it grew out of the pill; left at the default
          // (centre) it scales in place and reads as a small dialog that
          // happened to be nearby — and it shifts the panel off its own
          // anchor by a quarter of its width.
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
      tracking = false;
      _onTriggerMoved = null;
      if (keyboardWasUp) FocusManager.instance.primaryFocus?.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) =>
      CompositedTransformTarget(link: _link, child: KeyedSubtree(key: _key, child: widget.child));

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _trigger.dispose();
    super.dispose();
  }
}

/// Places the panel against its trigger, live, and keeps it on screen.
class _AnchoredMenuDelegate extends SingleChildLayoutDelegate {
  _AnchoredMenuDelegate({
    required this.trigger,
    required this.openAbove,
    required this.safeTop,
    required this.safeBottom,
  });

  final Rect? trigger;
  final bool openAbove;
  final double safeTop;
  final double safeBottom;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Size getSize(BoxConstraints constraints) => constraints.biggest;

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // Republished by the anchor whenever it moves, so the panel follows the
    // trigger instead of where the trigger used to be.
    final trigger = this.trigger;
    if (trigger == null) return Offset.zero;

    const gap = VelaAnchorState.gap;
    final roomAbove = trigger.top - safeTop - gap;
    final roomBelow = size.height - trigger.bottom - safeBottom - gap;

    // The side was chosen by the caller so the entrance could scale from the
    // matching corner. Here it is only corrected if that side genuinely cannot
    // hold the panel, and the result is clamped either way — a panel whose
    // bottom hangs off the screen cannot be scrolled to, which is the same as
    // not being there.
    final actualAbove = switch (openAbove ? roomAbove : roomBelow) {
      final r when r >= childSize.height => openAbove,
      _ when (openAbove ? roomBelow : roomAbove) >= childSize.height => !openAbove,
      _ => openAbove,
    };

    // ignore: avoid_print
    // ignore: avoid_print
    final rawTop = actualAbove
        ? trigger.top - gap - childSize.height
        : trigger.bottom + gap;
    final top = rawTop.clamp(
      safeTop,
      (size.height - childSize.height - safeBottom).clamp(
        safeTop.toDouble(),
        double.infinity,
      ),
    );
    final left = trigger.left.clamp(
      gap.toDouble(),
      (size.width - childSize.width - gap).clamp(gap.toDouble(), double.infinity),
    );
    // ignore: avoid_print
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(covariant _AnchoredMenuDelegate old) =>
      old.trigger != trigger ||
      old.openAbove != openAbove ||
      old.safeTop != safeTop ||
      old.safeBottom != safeBottom;
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
