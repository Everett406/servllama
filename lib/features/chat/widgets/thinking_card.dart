import 'dart:async';

import 'package:flutter/material.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';
import 'package:servllama/features/chat/widgets/thinking_indicator.dart';
import 'package:servllama/l10n/l10n.dart';

/// Chain-of-thought, folded.
///
/// The old version was a hard left rule with a chevron — a structure that
/// reads as "warning tape" and separates thought from answer with a border
/// rather than with type. This one leans the way the rest of the app does:
/// a quiet raised card whose header carries the elapsed time.
///
/// The timer is the point. People are not really waiting for a spinner to
/// stop, they are waiting to find out how long this is going to take; a
/// counter tells them whether to go make coffee or go read something, and
/// it is the only element here that carries information.
class ThinkingCard extends StatefulWidget {
  const ThinkingCard({
    super.key,
    required this.content,
    required this.expanded,
    required this.onToggle,
    this.live = false,
  });

  final String content;
  final bool expanded;
  final VoidCallback onToggle;

  /// Still generating — swaps the header between "thinking" and "thought".
  final bool live;

  @override
  State<ThinkingCard> createState() => _ThinkingCardState();
}

class _ThinkingCardState extends State<ThinkingCard> {
  static const double _radius = 18;

  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(ThinkingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.live != widget.live) _restartTimer();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _restartTimer() {
    _ticker?.cancel();
    if (widget.live) {
      _startedAt = DateTime.now();
      _elapsed = Duration.zero;
      _ticker = Timer.periodic(const Duration(milliseconds: 1000), (_) {
        if (!mounted) return;
        setState(() {
          _elapsed = DateTime.now().difference(_startedAt!);
        });
      });
    } else {
      // Freeze on whatever the live counter last showed, so the finished
      // card does not snap back to "0s".
      _startedAt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final accent = context.accent.withAlpha(179);
    final duration = formatThinkingDuration(_elapsed);
    final title = widget.live
        ? context.l10n.chatThinkingLive(duration)
        : context.l10n.chatThinkingDone(duration);

    return Padding(
      // Nudges the card one step out of the answer's column, so the hierarchy
      // is carried by position as well as by type size.
      padding: const EdgeInsets.only(left: 0, bottom: ClaudeSpacing.md),
      child: Container(
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: context.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              key: const Key('thinking_card_header'),
              onTap: widget.onToggle,
              borderRadius: BorderRadius.circular(_radius),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
                child: Row(
                  children: [
                    if (widget.live)
                      reduceMotion
                          ? StaticProgressArc(color: accent, size: 13)
                          : const GenerationActivityDot(size: 10)
                    else
                      Icon(
                        Icons.psychology_outlined,
                        size: 15,
                        color: accent,
                      ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.linear,
                        switchOutCurve: Curves.linear,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                        child: Text(
                          title,
                          // The key has to change with the text or the
                          // crossfade has nothing to interpolate between.
                          key: ValueKey(title),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 22 / 13,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: widget.expanded ? 0.5 : 0,
                      duration: reduceMotion
                          ? Duration.zero
                          : ClaudeMotion.medium,
                      curve: ClaudeMotion.curve,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: context.inkTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 400),
              curve: Curves.decelerate,
              alignment: Alignment.topCenter,
              child: widget.expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 11),
                      child: Text(
                        widget.content,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          // Deliberately a step below the answer's body size:
                          // thought should be readable but never compete with
                          // the reply it precedes.
                          fontSize: 13,
                          height: 1.55,
                          color: context.inkTertiary,
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 9),
                      child: _FadedTailText(
                        text: widget.content,
                        streaming: widget.live,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One line of reasoning with the newest characters fading in at the tail.
///
/// Gives the sense that text is still arriving without resorting to a
/// scrolling marquee or a blinking caret — both of which fight the answer
/// text directly below them for attention.
class _FadedTailText extends StatelessWidget {
  const _FadedTailText({required this.text, required this.streaming});

  final String text;
  final bool streaming;

  static const int _fadeCodePoints = 42;
  static const int _bands = 6;
  static const double _newestAlpha = 0.38;
  static const int _maxCodePoints = 90;

  @override
  Widget build(BuildContext context) {
    final chars = text.characters;
    final truncated = chars.length > _maxCodePoints
        ? '…${chars.skip(chars.length - _maxCodePoints)}'
        : chars.toString();
    final base = context.inkTertiary;

    if (!streaming || truncated.length <= 2) {
      return Text(
        truncated,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 13,
          height: 1.5,
          color: base,
        ),
      );
    }

    final runes = truncated.runes.toList();
    final fadeStart =
        (runes.length - _fadeCodePoints).clamp(0, runes.length).toInt();
    final fadeSpan = runes.length - fadeStart;
    final spans = <TextSpan>[];

    for (var i = 0; i < runes.length; i++) {
      var alpha = 1.0;
      if (fadeSpan > 0 && i >= fadeStart) {
        final band = ((i - fadeStart) * _bands) ~/ fadeSpan;
        alpha = 1.0 - ((band + 1) / _bands) * (1 - _newestAlpha);
      }
      spans.add(
        TextSpan(
          text: String.fromCharCode(runes[i]),
          style: TextStyle(
            color: base.withAlpha((base.a * alpha).clamp(0, 1).round()),
          ),
        ),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontSize: 13,
        height: 1.5,
        color: base,
      ),
    );
  }
}