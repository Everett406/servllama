import 'package:flutter/material.dart';
import 'package:servllama/app/app_theme.dart';

/// The activity dot.
///
/// A model thinking for thirty seconds has no progress bar to show, so the
/// only honest signal is "something is happening". That means the animation
/// has to be aperiodic-feeling and low-salience: eleven logical pixels,
/// neutral ink rather than the accent, breathing between 55% and 130% on a
/// two second cycle. Anything more would be a progress bar for a job whose
/// duration nobody can predict.
///
/// The colour split matters as much as the size. The accent belongs to the
/// thinking *card*, which carries the meaning; the thing that actually moves
/// stays grey so a single breathing dot does not own the whole message.
class GenerationActivityDot extends StatefulWidget {
  const GenerationActivityDot({
    super.key,
    this.size = 11,
    this.color,
    this.active = true,
  });

  final double size;
  final Color? color;
  final bool active;

  @override
  State<GenerationActivityDot> createState() => _GenerationActivityDotState();
}

class _GenerationActivityDotState extends State<GenerationActivityDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  late final Animation<double> _scale = Tween<double>(begin: 0.55, end: 1.30)
      .animate(
        CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn),
      );

  @override
  void initState() {
    super.initState();
    _syncMotion();
  }

  @override
  void didUpdateWidget(GenerationActivityDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _syncMotion();
  }

  void _syncMotion() {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!widget.active || reduceMotion) {
      _controller.stop();
      _controller.value = 1;
      return;
    }
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final scale = (!widget.active || reduceMotion) ? 1.0 : _scale.value;
    return Transform.scale(
      scale: scale,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color ?? context.inkTertiary,
          ),
        ),
      ),
    );
  }
}

/// The inline activity slot that sits at the end of an in-flight reply.
///
/// Fixed height on purpose: the slot crossfades between the breathing dot
/// and the first streamed characters, and a slot that resized as it swapped
/// would shove the answer under the user's thumb mid-generation.
class StreamingActivitySlot extends StatelessWidget {
  const StreamingActivitySlot({
    super.key,
    required this.visible,
    required this.child,
    this.height = 24,
  });

  final bool visible;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: AnimatedOpacity(
        // Fades in, but never fades back out: a dot that shrinks away reads
        // as a hiccup, whereas vanishing instantly reads as "done".
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn,
        child: Align(alignment: Alignment.centerLeft, child: child),
      ),
    );
  }
}

/// A static 270-degree arc for when the system asks for reduced motion.
///
/// Still says "in progress" without animating — and without pretending to
/// know a percentage it cannot know.
class StaticProgressArc extends StatelessWidget {
  const StaticProgressArc({
    super.key,
    required this.color,
    this.size = 16,
    this.strokeWidth = 2,
  });

  final Color color;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ArcPainter(color, strokeWidth)),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter(this.color, this.strokeWidth);

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    canvas.drawArc(
      Rect.fromLTWH(inset, inset, size.width - strokeWidth, size.height - strokeWidth),
      -1.5707963,
      4.712389,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Formats an elapsed span the way a person would say it out loud.
String formatThinkingDuration(Duration elapsed) {
  final s = elapsed.inSeconds;
  if (s < 60) return '${s}s';
  final m = s ~/ 60;
  final rs = s % 60;
  if (m < 60) return rs == 0 ? '${m}m' : '${m}m ${rs}s';
  final h = m ~/ 60;
  final rm = m % 60;
  return rm == 0 ? '${h}h' : '${h}h ${rm}m';
}