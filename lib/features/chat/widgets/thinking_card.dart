import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';
import 'package:servllama/app/widgets/claude_icons.dart';
import 'package:servllama/features/chat/widgets/thinking_indicator.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/app/sheet/vela_sheet.dart';

/// When each message spent thinking.
///
/// The card sits inside a `ListView.builder`, so its State is thrown away
/// every time the row scrolls out of the cache extent — and thrown away
/// again when the message is re-fetched. Keeping the number in the widget
/// meant every scroll back to a finished answer reset it, which is exactly
/// the kind of detail that makes the whole feature look broken.
///
/// Held here instead, in a process-lifetime map. The clock also *stops*
/// when the answer starts arriving rather than when the stream ends: time
/// spent writing prose is not time spent thinking, and counting it makes a
/// fast model look like a slow one.
class ThinkingTimings {
  const ThinkingTimings._();

  static final Map<String, Duration> _frozen = <String, Duration>{};
  static final Map<String, DateTime> _started = <String, DateTime>{};

  static void markStarted(String messageId, DateTime at) {
    _started[messageId] ??= at;
  }

  static DateTime? startedAt(String messageId) => _started[messageId];

  static void freeze(String messageId, Duration elapsed) {
    _frozen[messageId] = elapsed;
  }

  static Duration? frozen(String messageId) => _frozen[messageId];
}

/// Chain-of-thought, as one quiet line.
///
/// Not a card. A bordered panel looks like a system dialog and costs more
/// vertical space than the thought it introduces — on a phone the answer
/// gets pushed off-screen by the thing meant to support it. A row of grey
/// type reads as a caption on the answer instead.
///
/// The line shows *what* was thought, not how long it took. A timer in the
/// caption made the number the message, and the number is the least
/// interesting thing about it. The duration moved into the sheet, where
/// somebody who wants to know can look and nobody else has to.
class ThinkingLine extends StatefulWidget {
  const ThinkingLine({
    super.key,
    required this.content,
    required this.expanded,
    required this.onToggle,
    required this.messageId,
    this.live = false,
    this.answerStarted = false,
    this.promptedAt,
    this.answeredAt,
  });

  final String content;
  final bool expanded;
  final VoidCallback onToggle;
  final String messageId;
  final bool live;

  /// The model has started writing the answer. The clock stops here — time
  /// spent producing prose is not time spent thinking.
  final bool answerStarted;

  final DateTime? promptedAt;
  final DateTime? answeredAt;

  @override
  State<ThinkingLine> createState() => _ThinkingLineState();
}

class _ThinkingLineState extends State<ThinkingLine> {
  static const double _markSize = 14;
  static const double _markGap = 9;

  /// How much of the thought the caption shows at once.
  static const int _window = 34;
  static const Duration _advance = Duration(milliseconds: 1800);

  Timer? _ticker;
  Timer? _walker;
  Duration _elapsed = Duration.zero;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _elapsed = _resolveInitialElapsed();
    _restartTicker();
    _restartWalker();
  }

  @override
  void didUpdateWidget(ThinkingLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageId != widget.messageId) {
      _elapsed = _resolveInitialElapsed();
    }
    if (oldWidget.live != widget.live) {
      // The stream ended. Whatever the clock last showed is the answer.
      if (!widget.live && !_isFrozen) {
        ThinkingTimings.freeze(widget.messageId, _elapsed);
      }
    }
    if (widget.live && !widget.answerStarted) {
      _restartTicker();
    }
  }

  bool get _isFrozen => ThinkingTimings.frozen(widget.messageId) != null;

  @override
  void dispose() {
    _ticker?.cancel();
    _walker?.cancel();
    super.dispose();
  }

  /// Walks the caption forward through the thought while it streams.
  ///
  /// A caption frozen on the first sentence shows the model's opening move
  /// for the entire reply, which is the least interesting part by the end.
  /// Advancing a window keeps the newest reasoning on screen and wraps back
  /// to the top once it runs off the end.
  void _restartWalker() {
    _walker?.cancel();
    if (!widget.live || widget.answerStarted) {
      _walker = null;
      _offset = 0;
      return;
    }
    _walker = Timer.periodic(_advance, (_) {
      if (!mounted) return;
      final length = widget.content
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          .length;
      if (length <= _window) return;
      setState(() {
        _offset += 12;
        if (_offset + _window > length) _offset = 0;
      });
    });
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

  void _restartTicker() {
    _ticker?.cancel();
    if (!widget.live || widget.answerStarted) {
      // The answer has started, or the reply is over: the clock is done.
      _ticker = null;
      if (!_isFrozen) {
        ThinkingTimings.freeze(widget.messageId, _elapsed);
      }
      return;
    }
    ThinkingTimings.markStarted(
      widget.messageId,
      ThinkingTimings.startedAt(widget.messageId) ?? DateTime.now(),
    );
    _ticker = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      if (!mounted) return;
      final started = ThinkingTimings.startedAt(widget.messageId);
      if (started == null) return;
      setState(() => _elapsed = DateTime.now().difference(started));
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    // Still deciding what to think about.
    final waiting = widget.live && widget.content.trim().isEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: ClaudeSpacing.sm),
      child: InkWell(
        key: const Key('thinking_line_toggle'),
        onTap: widget.onToggle,
        borderRadius: BorderRadius.circular(ClaudeRadius.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 26),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: _markSize,
                  height: _markSize,
                  child: waiting
                      // Nothing to show yet. A breathing dot rather than a
                      // spinner: the ring says "working", the dot says
                      // "waiting", and waiting is what this actually is.
                      ? GenerationActivityDot(
                          size: 10,
                          color: context.inkTertiary,
                        )
                      : widget.live
                      ? _ThinkingRing(reduceMotion: reduceMotion)
                      : ClaudeIcon(
                          ClaudeIcons.clock,
                          size: _markSize,
                          color: context.inkTertiary,
                        ),
                ),
                const SizedBox(width: _markGap),
                Expanded(
                  child: Text(
                    waiting
                        ? context.l10n.chatThinkingWaiting
                        : _summarise(widget.content, _offset),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // AnimatedSwitcher centres its child, which is how the
                    // old caption ended up floating in the middle of the
                    // row. Left is where a caption belongs.
                    textAlign: TextAlign.left,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14.5,
                      color: context.inkTertiary,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: widget.expanded ? 0.5 : 0,
                  duration: reduceMotion ? Duration.zero : ClaudeMotion.fast,
                  child: ClaudeIcon(
                    ClaudeIcons.chevronDown,
                    size: 14,
                    color: context.inkTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// First line of the thought, flattened.
  ///
  /// Models wrap reasoning wherever the line happens to end, and a caption
  /// that starts with a newline reads as an empty row.
  static String _summarise(String reasoning, int offset) {
    final collapsed = reasoning.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.length <= _window || offset == 0) return collapsed;
    if (offset + _window > collapsed.length) return collapsed;
    return '…${collapsed.substring(offset, offset + _window)}';
  }
}

/// The one moving part: a ring that turns while the model works.
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
      return StaticProgressArc(
        color: context.inkTertiary,
        size: 14,
        strokeWidth: 2.2,
      );
    }
    return RotationTransition(
      turns: _controller,
      child: CustomPaint(
        painter: _RingPainter(track: context.border, arc: context.accent),
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
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawCircle(
        size.center(Offset.zero),
        size.width / 2 - 1.1,
        paint..color = track,
      )
      // Just over a quarter, so there is a visible head and tail.
      ..drawArc(
        Rect.fromCircle(
          center: size.center(Offset.zero),
          radius: size.width / 2 - 1.1,
        ),
        -1.5707963,
        1.9,
        false,
        paint..color = arc,
      );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.track != track || oldDelegate.arc != arc;
}

/// The full thought, in a sheet.
///
/// A sheet rather than an inline expansion because the thought is often
/// longer than the screen: expanding it in place pushes the answer the user
/// came to read off the bottom, and then they have to scroll back to read
/// the thing they just opened.
Future<void> showThinkingSheet(
  BuildContext context, {
  required String content,
  required Duration elapsed,
  required String messageId,
  ValueListenable<String>? liveContent,
  bool answerStarted = false,
}) {
  final chinese = Localizations.localeOf(context).languageCode == 'zh';
  return showVelaSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      minChildSize: 0.35,
      maxChildSize: 0.94,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
            child: ValueListenableBuilder<Duration>(
              valueListenable: _ThinkingClock(
                messageId: messageId,
                fallback: elapsed,
                answerStarted: answerStarted,
              ),
              builder: (context, liveValue, _) => Text(
                context.l10n.chatThinkingSheetTitle(
                  formatThinkingDuration(liveValue, chinese: chinese),
                ),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              children: [
                ValueListenableBuilder<String>(
                  valueListenable:
                      liveContent ?? const AlwaysStoppedAnimation(''),
                  builder: (context, liveValue, _) => Text(
                    liveValue.isNotEmpty ? liveValue : content,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.85,
                      color: context.inkSecondary,
                    ),
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

/// The elapsed time, as a notifier the sheet can listen to.
///
/// It used to be a [ValueNotifier] built at open time and handed in as
/// `liveElapsed`, which meant it held whatever it was constructed with and
/// never moved again: the title showed the time as of the moment the sheet
/// opened and stood there for the rest of the thought. A sheet is where you
/// go to watch something happen, so the clock has to be one of the things
/// that happens.
///
/// Ticking stops the moment the answer starts, because at that point the
/// thought is over and the real elapsed time is [ThinkingTimings.frozen].
class _ThinkingClock extends ValueNotifier<Duration> {
  _ThinkingClock({
    required String messageId,
    required Duration fallback,
    required bool answerStarted,
  }) : super(fallback) {
    _messageId = messageId;
    _answerStarted = answerStarted;
    _restart();
  }

  late final String _messageId;
  late bool _answerStarted;
  Timer? _ticker;

  void _restart() {
    _ticker?.cancel();
    _ticker = null;
    final frozen = ThinkingTimings.frozen(_messageId);
    if (frozen != null) {
      value = frozen;
      return;
    }
    final started = ThinkingTimings.startedAt(_messageId);
    if (_answerStarted || started == null) return;
    value = DateTime.now().difference(started);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      value = DateTime.now().difference(started);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
