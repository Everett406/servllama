import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// Streamed answer text, with the newest characters fading up.
///
/// A token arriving at full opacity reads as a page flipping: the answer is
/// there all at once and the eye has to find where it began. Letting the
/// newest few characters ramp from transparent over about half a second
/// makes the text arrive the way it was written — and costs one extra
/// AnnotatedString per frame, which is cheaper than a blinking caret and
/// far less attention-grabbing.
///
/// Only the tail is touched. Re-laying out the whole document to fade in a
/// whole document would defeat the point and make the answer jump.
class StreamingFadeText extends StatefulWidget {
  const StreamingFadeText({
    super.key,
    required this.text,
    required this.style,
    required this.isStreaming,
    this.fadeCodePoints = 90,
    this.alphaPerSecond = 2.4,
  });

  final String text;
  final TextStyle style;

  /// Once this goes false the tail snaps to full opacity and the timer
  /// stops: a finished answer should not still be fading in.
  final bool isStreaming;

  /// How many trailing characters carry the ramp. Long enough to cover a
  /// fast token rate at one fade window, short enough that a completed
  /// paragraph is never half-transparent.
  final int fadeCodePoints;

  /// Alpha gained per second. 2.4 reaches full in roughly 420ms.
  final double alphaPerSecond;

  @override
  State<StreamingFadeText> createState() => _StreamingFadeTextState();
}

class _StreamingFadeTextState extends State<StreamingFadeText> {
  static const Duration _tick = Duration(milliseconds: 40);

  /// First time each trailing code point was seen, so the ramp is measured
  /// from when the character actually arrived rather than from whenever the
  /// widget happened to rebuild.
  final Map<int, DateTime> _birth = <int, DateTime>{};

  final ValueNotifier<int> _clock = ValueNotifier<int>(0);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _syncBirths();
    _timer = Timer.periodic(_tick, (_) {
      if (!mounted) return;
      _clock.value++;
    });
  }

  @override
  void didUpdateWidget(StreamingFadeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _syncBirths();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clock.dispose();
    super.dispose();
  }

  void _syncBirths() {
    final length = widget.text.runes.length;
    final now = DateTime.now();
    for (var i = _birth.length; i < length; i++) {
      _birth[i] = now;
    }
    _birth.removeWhere((index, _) => index >= length);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _clock,
      builder: (context, _, __) {
        final base =
            widget.style.color ??
            DefaultTextStyle.of(context).style.color ??
            Colors.black;
        if (!widget.isStreaming) {
          return Text(
            widget.text,
            style: widget.style,
            key: Key('chat_message_target_streaming_text'),
          );
        }

        final runes = widget.text.runes.toList();
        final fadeStart = (runes.length - widget.fadeCodePoints).clamp(
          0,
          runes.length,
        );
        final now = DateTime.now();
        final spans = <TextSpan>[];

        for (var i = 0; i < runes.length; i++) {
          var alpha = 1.0;
          if (i >= fadeStart) {
            final ageMs = now.difference(_birth[i] ?? now).inMilliseconds;
            alpha = (widget.alphaPerSecond * ageMs / 1000).clamp(0.0, 1.0);
          }
          spans.add(
            TextSpan(
              text: String.fromCharCode(runes[i]),
              style: alpha >= 1.0
                  ? null
                  : TextStyle(color: base.withAlpha((base.a * alpha).round())),
            ),
          );
        }

        return Text.rich(
          TextSpan(children: spans),
          style: widget.style,
          key: Key('chat_message_target_streaming_text'),
        );
      },
    );
  }
}

/// Answer body, with the fade applied only while it streams.
class FadingMarkdown extends StatelessWidget {
  const FadingMarkdown({
    super.key,
    required this.content,
    required this.style,
    required this.isStreaming,
  });

  final String content;
  final TextStyle style;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    if (!isStreaming || content.isEmpty) {
      return GptMarkdown(content, style: style);
    }
    return StreamingFadeText(
      text: content,
      style: style,
      isStreaming: isStreaming,
    );
  }
}
