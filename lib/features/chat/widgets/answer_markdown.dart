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
      // blurIn reveals per group, and a group is a word in Latin text but a
      // single ideograph in Chinese — see the CJK split in the vendored
      // gpt_markdown. Before that patch a whole paragraph was one group, all
      // of its characters shared the first character's progress, and the
      // paragraph blurred once and then snapped sharp together. That is the
      // whole of "the blur only shows up at the start of each paragraph".
      blockAnimation: GptMarkdownBlockAnimation.fadeIn,
      isStreaming: isStreaming,
      // Pacing, not a typewriter's own speed. It only has to be fast enough
      // that the reveal head stays ahead of the model — a reply that waits on
      // the animation looks broken. 45 is comfortably above what a local model
      // on a phone actually emits (~15-40 characters/s in Chinese) while still
      // being slow enough that roughly two characters land per frame. At 150,
      // six or seven characters arrived in the same frame and the per-character
      // entrance smeared into a streak no eye could separate.
      charactersPerSecond: 45,
      // How long a character keeps resolving after the head passes it. The
      // trail is this multiplied by the pacing above, and that product is what
      // decides whether the blur reads as one character coming into focus or as
      // a smear: 0.62 at 150 left 93 characters blurred at once, which is a
      // streak, not an entrance. This leaves a short crest.
      revealFadeSeconds: 0.16,
      // Lines arrive a beat apart rather than all at once. Prose reveals per
      // character now, so this only governs what a fence or a table does.
      blockAnimationDuration: const Duration(milliseconds: 520),
      blockAnimationCurve: Curves.easeOutCubic,
      // The package gives every heading level the same padding, so a second
      // level sitting under a first one opens as much space as a section
      // break would. This is the only place to correct for that.
      headingBuilder: _heading,
    );
  }

  /// Per-level heading rhythm.
  ///
  /// Space above a heading should shrink as the heading gets more nested: a
  /// title earns a section's worth of air, a fourth-level label under one
  /// earns almost none. One flat value cannot express that, and the flat
  /// value is what put a screen's worth of blank between a document's title
  /// and the first line under it.
  static Widget _heading(
    BuildContext context,
    int level,
    Widget content,
    HeadingStyle style,
  ) {
    const above = <int, double>{
      1: 26,
      2: 18,
      3: 13,
      4: 10,
      5: 8,
      6: 6,
    };
    final top = above[level.clamp(1, 6)] ?? 6;
    // Nothing before the very first heading: the message already has its own
    // top padding and the two stacked into a visible gap.
    final isFirst = level == 1;
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: isFirst ? 2 : 4),
      child: content,
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
        // No padding here. HeadingStyle applies one value to every level, so
        // an h2 directly under an h1 got the same 22dp lead as a section
        // break and the pair read as two separate sections. The per-level
        // rhythm lives in headingBuilder below.
        padding: EdgeInsets.zero,
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
        // No columnWidth. It used to be FlexColumnWidth, which divides the
        // available width proportionally and measures nothing — on a phone
        // that is the difference between a readable table and a column of
        // single characters stacked on each other, since five columns share
        // 360dp and each gets one glyph per line. Left unset, the package
        // measures each column to its content and lets the table exceed the
        // viewport, which already scrolls horizontally.
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
