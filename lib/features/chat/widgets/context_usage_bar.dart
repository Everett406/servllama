import 'package:flutter/material.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/l10n/l10n.dart';

/// How much of the window this conversation is eating.
///
/// Sits below the composer, in the strip of screen that is otherwise just
/// gesture bar and nothing — the one place a meter can live without pushing
/// the conversation up. It stays hidden until the engine reports a real
/// context window, because a bar measuring against a guessed ceiling teaches
/// people to trust a number the app made up.
///
/// The estimate is a character count, not a tokenizer. Running one on every
/// keystroke to produce a figure that would still be approximate is not worth
/// the cost, and llama.cpp's own server reports usage authoritatively if the
/// caller ever wants to stop guessing.
class ContextUsageBar extends StatelessWidget {
  const ContextUsageBar({
    super.key,
    required this.messages,
    required this.contextWindow,
  });

  final List<ChatMessageRecord> messages;
  final int? contextWindow;

  @override
  Widget build(BuildContext context) {
    final window = contextWindow;
    if (window == null || window <= 0 || messages.isEmpty) {
      return const SizedBox.shrink();
    }

    final used = estimateTokens(messages);
    final ratio = (used / window).clamp(0.0, 1.0);
    final percent = (ratio * 100).round();
    final (fill, track) = switch (ratio) {
      >= 0.9 => (context.dangerText, context.dangerText.withAlpha(28)),
      >= 0.75 => (context.warningText, context.warningText.withAlpha(28)),
      _ => (context.inkTertiary, context.inkTertiary.withAlpha(22)),
    };

    return Semantics(
      label: context.l10n.contextUsageLabel(
        percent,
        formatTokenCount(used),
        formatTokenCount(window),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 84,
          height: 5,
          decoration: BoxDecoration(
            color: track,
            borderRadius: BorderRadius.circular(ClaudeRadius.pill),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: ratio == 0 ? 0.02 : ratio.clamp(0.02, 1.0),
              child: AnimatedContainer(
                duration: ClaudeMotion.medium,
                curve: ClaudeMotion.curve,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(ClaudeRadius.pill),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rough token count for a transcript.
///
/// Weighted per character rather than per word: CJK text runs close to one
/// token per character on the BPE vocabularies these models ship with, while
/// English sits near a quarter, and a single divisor cannot serve both.
/// Rounding up keeps a full window from reporting 99%.
int estimateTokens(Iterable<ChatMessageRecord> messages) {
  var total = 0.0;
  for (final message in messages) {
    total += _count(message.content);
    total += _count(message.reasoningContent ?? '');
    // Per-message framing overhead in the chat template.
    total += 4;
  }
  return total.ceil();
}

double _count(String text) {
  if (text.isEmpty) return 0;
  var total = 0.0;
  for (final rune in text.runes) {
    // CJK, fullwidth forms and kana dominate the per-character cost; ASCII
    // and Latin-1 are roughly four characters to a token.
    total += rune >= 0x2E80 ? 1.0 : 0.25;
  }
  return total;
}

/// Compact token counts: 823, 12.4k, 1.2M.
String formatTokenCount(int value) {
  if (value < 1000) return '$value';
  if (value < 1000000) {
    final k = value / 1000;
    return '${k.toStringAsFixed(k < 10 ? 1 : 0)}k';
  }
  final m = value / 1000000;
  return '${m.toStringAsFixed(m < 10 ? 1 : 0)}M';
}
