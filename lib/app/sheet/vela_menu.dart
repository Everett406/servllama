import 'package:flutter/material.dart';

import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/keyboard/keyboard_state.dart';

/// Marks the widget a menu hangs off.
class VelaAnchor extends StatefulWidget {
  const VelaAnchor({super.key, required this.child, this.prefer = AxisDirection.up});

  final Widget child;

  /// Which side of the trigger the menu opens on.
  ///
  /// Falls back to the other side when the preferred one has no room, which
  /// is what happens to a pill near the bottom of the screen.
  final AxisDirection prefer;

  /// The nearest enclosing anchor, if [context] is inside one.
  static VelaAnchorState? of(BuildContext context) =>
      context.findAncestorStateOfType<VelaAnchorState>();

  @override
  State<VelaAnchor> createState() => VelaAnchorState();
}

class VelaAnchorState extends State<VelaAnchor> {
  final LayerLink _link = LayerLink();
  final GlobalKey _key = GlobalKey();

  Rect? _rectOf(BuildContext context) {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    double width = 248,
  }) {
    final rect = _rectOf(context);
    if (rect == null) return Future<T?>.value();

    // Remember the keyboard before the overlay steals the tap. Opening a menu
    // from a focused field should not be a way to close it, and closing the
    // menu should not be a way to open it either.
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
      pageBuilder: (dialogContext, animation, _) => _AnchoredPosition(
        animation: animation,
        trigger: rect,
        width: width,
        prefer: widget.prefer,
        child: Builder(
          builder: (panelContext) => Padding(
            padding: EdgeInsets.only(top: MediaQuery.paddingOf(panelContext).top),
            child: VelaMenuEntrance(
              alignment: widget.prefer == AxisDirection.up
                  ? Alignment.bottomLeft
                  : Alignment.topLeft,
              child: VelaMenuPanel(
                width: width,
                child: Builder(builder: builder),
              ),
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      // Put the field back the way the user had it.
      if (keyboardWasUp) FocusManager.instance.primaryFocus?.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(link: _link, child: KeyedSubtree(key: _key, child: widget.child));
}

/// Places the panel against the trigger, flipping sides when it has to.
///
/// The scale origin in [VelaMenuEntrance] does most of the work; this only
/// decides where the panel's corner lands.
class _AnchoredPosition extends StatelessWidget {
  const _AnchoredPosition({
    required this.trigger,
    required this.width,
    required this.prefer,
    required this.child,
    required this.animation,
  });

  final Animation<double> animation;
  final Rect trigger;
  final double width;
  final AxisDirection prefer;
  final Widget child;

  static const double gap = 8;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final safeTop = MediaQuery.paddingOf(context).top + 8;
    final safeBottom = MediaQuery.paddingOf(context).bottom + 8;

    // A rough height to decide which side has room. Only the decision uses
    // it; the actual placement is anchored to an edge and never uses it.
    final estimated = 220.0;
    final roomAbove = trigger.top - safeTop;
    final roomBelow = screen.height - trigger.bottom - safeBottom;
    // Flip only when the preferred side genuinely has no room. Falling back
    // to "whichever side is bigger" would open downward for a pill in the
    // middle of the screen, which is the opposite of what was asked for.
    final above = prefer == AxisDirection.up
        ? roomAbove >= estimated || roomBelow < estimated
        : roomBelow >= estimated;

    final left = trigger.left.clamp(
      8.0,
      (screen.width - width - 8).clamp(8.0, screen.width),
    );

    // Anchored by the edge nearest the trigger rather than by a top offset.
    // A `Positioned(top:)` would need the panel's height before layout, and
    // the panel is free to be any height — the thought sheet grows, a model
    // list scrolls. Anchoring the bottom instead leaves the height to layout
    // and cannot drift.
    return Stack(
      children: [
        if (above)
          Positioned(
            left: left,
            bottom: screen.height - trigger.top + gap,
            child: FadeTransition(opacity: animation, child: child),
          )
        else
          Positioned(
            left: left,
            top: trigger.bottom + gap,
            child: FadeTransition(opacity: animation, child: child),
          ),
      ],
    );
  }
}

/// Convenience: the panel itself.
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

/// Scales the panel out of its trigger.
///
/// [alignment] has to name the corner that touches the trigger. Without it
/// Flutter scales around the centre and the menu reads as a dialog that
/// happened to be small — which is the single easiest thing to get wrong
/// here and the whole reason this wrapper exists.
class VelaMenuEntrance extends StatelessWidget {
  const VelaMenuEntrance({
    super.key,
    required this.alignment,
    required this.child,
  });

  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.86 + 0.14 * t,
          // Origin at the corner facing the trigger: the panel appears to
          // come out of the pill.
          alignment: alignment,
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// A row inside a menu panel.
///
/// Sized like a list row, not like a settings row. The model picker used to
/// be a sheet with settings-sized rows, which is most of why it read as
/// bloated: twice the height it needs and a divider after every line.
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
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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
