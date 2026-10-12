import 'dart:async';

import 'package:flutter/material.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';
import 'package:servllama/app/widgets/claude_icons.dart';
import 'package:servllama/features/chat/widgets/thinking_indicator.dart';
import 'package:servllama/l10n/l10n.dart';

/// How long each message spent thinking, keyed by message id.
///
/// The card sits inside a `ListView.builder`, so its State is thrown away
/// every time the row scrolls out of the cache extent — and thrown away
/// again when the message is re-fetched. Keeping the number in the widget
/// meant every scroll back to a finished answer reset it to 0s, which is
/// exactly the kind of detail that makes the whole feature look broken.
///
/// Held here instead, in a process-lifetime map. Replies that arrive from
/// disk after a restart have no timing to recover, so the card falls back to
/// the span between the prompt and the answer.
class ThinkingTimings {
  const ThinkingTimings._();

  static final Map<String, Duration> _frozen = <String, Duration>{};
  static final Map<String, DateTime> _started = <String, DateTime>{};

  static void markStarted(String messageId, DateTime at) {
    _started[messageId] = at;
  }

  static DateTime? startedAt(String messageId) => _started[messageId];

  static void freeze(String messageId, Duration elapsed) {
    _frozen[messageId] = elapsed;
  }

  static Duration? frozen(String messageId) => _frozen[messageId];
}

/// Chain-of-thought, as one quiet line.
///
/// Not a card. A bordered panel with an elapsed timer looks like a system
/// dialog, and it costs more vertical space than the thought it introduces
/// — on a phone the answer gets pushed off the screen by the thing that was
/// supposed to be supporting it. A row of grey type with a small mark at the
/// front reads as a caption on the answer instead of a panel above it.
///
/// The mark is the only thing that moves: a ring that turns while the model
/// is working, a clock once it has stopped. Everything the user actually
/// wants to know — how long did that take — is in the text.
class ThinkingLine extends StatefulWidget {
  const ThinkingLine({
    super.key,
    required this.content,
    required this.expanded,
    required this.onToggle,
    required this.messageId,
    this.live = false,
    this.promptedAt,
    this.answeredAt,
  });

  final String content;
  final bool expanded;
  final VoidCallback onToggle;
  final String messageId;
  final bool live;
  final DateTime? promptedAt;
  final DateTime? answeredAt;

  @override
  State<ThinkingLine> createState() => _ThinkingLineState();
}

class _ThinkingLineState extends State<ThinkingLine> {
  static const double _markSize = 13;

  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(ThinkingLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.live != widget.live) _restartTimer();
    if (oldWidget.messageId != widget.messageId) {
      _elapsed = _resolveInitialElapsed();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Duration _resolveInitialElapsed() {
    final frozen = ThinkingTimings.frozen(widget.messageId);
    if (frozen != null) return frozen;
    final promptedAt = widget.promptedAt;
    final answeredAt = widget.answeredAt;
    if (promptedAt != null && answeredAt != null) {
      final span = answeredAt.difference(promptedAt);
      if (!span.isNegative && span.inSeconds > 0) return span;
    }
    return Duration.zero;
  }

  void _restartTimer() {
    _ticker?.cancel();
    if (widget.live) {
      // One clock per message, held outside the widget: this row is rebuilt
      // whenever the transcript scrolls it back into view, and a timer that
      // restarted with the State would report 0s every time.
      ThinkingTimings.markStarted(
        widget.messageId,
        ThinkingTimings.startedAt(widget.messageId) ?? DateTime.now(),
      );
      _elapsed = _resolveInitialElapsed();
      _ticker = Timer.periodic(const Duration(milliseconds: 1000), (_) {
        if (!mounted) return;
        final started = ThinkingTimings.startedAt(widget.messageId);
        if (started == null) return;
        setState(() => _elapsed = DateTime.now().difference(started));
      });
    } else {
      final frozen = ThinkingTimings.frozen(widget.messageId);
      if (frozen != null) {
        _elapsed = frozen;
      } else {
        final started = ThinkingTimings.startedAt(widget.messageId);
        _elapsed = started == null
            ? _resolveInitialElapsed()
            : DateTime.now().difference(started);
        ThinkingTimings.freeze(widget.messageId, _elapsed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final duration = formatThinkingDuration(_elapsed, chinese: chinese);
    final label = widget.live
        ? context.l10n.chatThinkingLiveShort(duration)
        : context.l10n.chatThinkingDone(duration);

    return Padding(
      padding: const EdgeInsets.only(bottom: ClaudeSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            key: const Key('thinking_line_toggle'),
            onTap: widget.onToggle,
            borderRadius: BorderRadius.circular(ClaudeRadius.sm),
            // A 24px minimum keeps it hittable without turning the row into
            // something that looks like a button.
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 24),
              child: Row(
                children: [
                  SizedBox(
                    width: _markSize,
                    height: _markSize,
                    child: widget.live
                        ? _ThinkingRing(reduceMotion: reduceMotion)
                        : ClaudeIcon(
                            ClaudeIcons.clock,
                            size: 13,
                            color: context.inkTertiary,
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 280),
                      switchInCurve: Curves.linear,
                      switchOutCurve: Curves.linear,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                      child: Text(
                        label,
                        key: ValueKey(label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14.5,
                          color: context.inkTertiary,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: AnimatedRotation(
                      turns: widget.expanded ? 0.5 : 0,
                      duration: reduceMotion
                          ? Duration.zero
                          : ClaudeMotion.fast,
                      child: ClaudeIcon(
                        ClaudeIcons.chevronDown,
                        size: 13,
                        color: context.inkTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: reduceMotion ? Duration.zero : ClaudeMotion.medium,
            curve: ClaudeMotion.curve,
            alignment: Alignment.topLeft,
            child: widget.expanded
                ? Padding(
                    padding: const EdgeInsets.only(
                      left: 21,
                      top: 2,
                      bottom: ClaudeSpacing.sm,
                    ),
                    child: Text(
                      widget.content,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        height: 1.85,
                        color: context.inkTertiary,
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }
}

/// The one moving part: a ring that turns while the model works.
///
/// A full ring with a single lighter arc, not a dot breathing. The dot is
/// quieter but reads as "idle"; a ring reads as "busy" from across the room,
/// which is the actual job.
class _ThinkingRing extends StatefulWidget {
  const _ThinkingRing({required this.reduceMotion});

  final bool reduceMotion;

  @override
  State<_ThinkingRing> createState() => _ThinkingRingState();
}

class _ThinkingRingState extends State<_ThinkingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.reduceMotion) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduceMotion) {
      return StaticProgressArc(color: context.inkTertiary, size: 13, strokeWidth: 2);
    }
    return RotationTransition(
      turns: _controller,
      child: CustomPaint(
        painter: _RingPainter(
          track: context.border,
          arc: context.accent,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.track, required this.arc});

  final Color track;
  final Color arc;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final rect = Offset.zero & size;
    canvas
      ..drawCircle(size.center(Offset.zero), size.width / 2 - 1, paint..color = track)
      // Just over a quarter, so there is a visible head and tail to the arc.
      ..drawArc(rect.deflate(1), -1.5707963, 1.9, false, paint..color = arc);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.track != track || oldDelegate.arc != arc;
}
