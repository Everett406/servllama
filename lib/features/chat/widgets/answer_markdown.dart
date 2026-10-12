import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:servllama/app/app_theme.dart';


/// Answer body.
///
/// Two things the package already does that this used to reimplement badly:
/// markdown stays live during the stream, and characters resolve out of a
/// blur while they fade in. An earlier version swapped in a plain `Text`
/// mid-stream to fade glyphs by hand, which meant raw asterisks sat on
/// screen until the reply ended — and the hand-rolled fade was a gradient
/// over the last line, not a per-character reveal, which is a different
/// effect entirely.
class AnswerMarkdown extends StatelessWidget {
  const AnswerMarkdown({
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
    return GptMarkdown(
      content,
      style: style,
      styleSheet: _sheet(context),
      animation: isStreaming
          ? GptMarkdownAnimation.blurIn
          : GptMarkdownAnimation.none,
      // Per block, not per character: this is what makes lines arrive one at
      // a time. growIn was too quick to read as a line arriving — a
      // three-line paragraph resolved as one gesture.
      blockAnimation: GptMarkdownBlockAnimation.fadeIn,
      isStreaming: isStreaming,
      // 900 was so far above the model's own pace that a whole paragraph
      // revealed inside a single frame, which is why it looked like an
      // instant dump with no typewriter at all. Slow enough that a
      // paragraph assembles; still comfortably above a local model's typical
      // output rate, so the trail still leads rather than lags.
      charactersPerSecond: 180,
      // How long one character keeps resolving after the head passes. A long
      // trail reads as the sentence assembling itself; a short one reads as
      // a stutter.
      revealFadeSeconds: 0.38,
      // Lines arrive a beat apart rather than all at once.
      blockAnimationDuration: const Duration(milliseconds: 340),
      blockAnimationCurve: Curves.easeOutCubic,
    );
  }

  /// The package's defaults are a documentation-site look: rules under every
  /// heading, a framed card around code, full-bleed tables. None of that
  /// belongs next to warm neutrals, so it is re-stated here rather than
  /// inherited.
  GptMarkdownStyleSheet _sheet(BuildContext context) {
    final sunken = context.surfaceSunken;
    return GptMarkdownStyleSheet(
      heading: HeadingStyle(
        textStyle: const TextStyle(letterSpacing: -0.3, height: 1.35),
        padding: const EdgeInsets.only(top: 22, bottom: 6),
        // No rule. The size step already separates a heading from the
        // paragraph under it, and a rule turns every title into a banner.
        showDivider: false,
      ),
      codeBlock: CodeBlockStyle(
        backgroundColor: sunken,
        // No frame around a frame: one edge does the job.
        borderWidth: 0,
        borderRadius: const Radius.circular(12),
        padding: const EdgeInsets.all(14),
        fontSize: 13,
        textColor: context.inkSecondary,
        // The language chip and copy button add chrome to a block that is
        // already a distinct shape.
        showLanguageLabel: false,
        showCopyButton: false,
      ),
      inlineCode: InlineCodeStyle(
        fontSizeFactor: 0.88,
        fontWeight: FontWeight.w500,
        color: context.accent,
        backgroundColor: context.accentSubtle.withAlpha(28),
        borderWidth: 0,
        borderRadius: const Radius.circular(5),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      ),
      list: ListStyle(
        bulletSize: 5,
        bulletColor: context.inkTertiary,
        indent: 20,
        gapAfterMarker: 8,
      ),
      blockQuote: BlockQuoteStyle(
        // A bar and an indent. A filled panel inside a card reads as a
        // second card.
        barWidth: 3,
        barColor: context.borderStrong,
        backgroundColor: Colors.transparent,
        // The gap between the bar and the text. Zeroing this is what made the
        // bar sit flush against the first character; backgroundColor above is
        // the thing that controls the panel fill, not the indent.
        padding: const EdgeInsets.only(left: 14),
        margin: const EdgeInsets.symmetric(vertical: 4),
        textStyle: TextStyle(
          fontSize: 15,
          height: 1.7,
          color: context.inkSecondary,
          fontStyle: FontStyle.italic,
        ),
      ),
      table: TableStyle(
        borderColor: context.border,
        borderWidth: 1,
        // No outer frame and no header fill: a boxed table reads as a dialog.
        borderRadius: Radius.zero,
        cellPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        headerBackground: Colors.transparent,
        headerTextStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: context.inkTertiary,
          letterSpacing: 0.3,
        ),
        rowStripeColor: Colors.transparent,
        columnWidth: const FlexColumnWidth(),
      ),
      hr: HrStyle(
        color: context.border,
        thickness: 1,
        padding: const EdgeInsets.symmetric(vertical: 18),
      ),
      link: LinkStyle(
        color: context.accent,
        // Underlined links are underlined; body text is not.
        decoration: TextDecoration.underline,
        decorationThickness: 1,
      ),
    );
  }
}
