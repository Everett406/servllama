import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:servllama/app/app_theme.dart';

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
    // GptMarkdown owns the text at every stage. An earlier version swapped
    // in a plain Text while the stream was running to fade characters in,
    // which meant raw asterisks and unclosed pipes were visible until the
    // reply finished — the markdown only appeared once it was too late for
    // it to matter.
    //
    // The fade is therefore painted over the last line rather than into the
    // glyphs: a canvas-coloured gradient anchored to the bottom edge veils
    // the newest characters, so they read as arriving instead of landing.
    final markdown = GptMarkdown(content, style: style);
    if (!isStreaming || content.isEmpty) {
      return markdown;
    }
    return Stack(
      children: [
        markdown,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: _tailFadeHeight,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    context.canvas.withAlpha(0),
                    context.canvas.withAlpha(235),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Tall enough to cover one line of body text at the reading measure.
  static const double _tailFadeHeight = 26;
}
