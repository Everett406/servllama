import 'package:flutter/material.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';

/// A small status dot.
///
/// Pulsing is opt-in and only for the state that is genuinely "working on
/// it" — a permanent pulse on every non-idle state turns the whole app into
/// a disco. The ring keeps the dot legible when it sits on a coloured fill.
class StatusDot extends StatefulWidget {
  const StatusDot({
    super.key,
    required this.color,
    this.size = 8,
    this.pulsing = false,
  });

  final Color color;
  final double size;
  final bool pulsing;

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulsing) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulsing && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.pulsing && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 2,
      height: widget.size * 2,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = widget.pulsing ? _controller.value : 0.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (widget.pulsing)
                Container(
                  width: widget.size * 2,
                  height: widget.size * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withAlpha((38 * (1 - t)).round()),
                  ),
                ),
              child!,
            ],
          );
        },
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

/// A quiet uppercase-ish group label. Used to separate sidebar sections
/// without adding a rule, which keeps the warm palette from getting busy.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.padding});

  final String text;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(8, 16, 8, 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: context.inkTertiary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// A plain surface panel with the standard hairline border. Most cards in the
/// app are this; anything richer should be earning it.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(ClaudeSpacing.lg),
    this.onTap,
    this.selected = false,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool selected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(ClaudeRadius.md);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? context.surface,
        borderRadius: radius,
        border: Border.all(
          color: selected ? ClaudeColors.accent : context.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
