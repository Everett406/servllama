import 'package:flutter/material.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';
import 'package:servllama/features/chat/widgets/streaming_block_splitter.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/l10n/l10n.dart';

/// Stands in for a table that is still being written.
///
/// The alternative — rendering the table as it grows — looks worse than doing
/// nothing: every row that lands reflows the columns above it, so the rows
/// the reader is in the middle of never sit still. Holding the block back
/// costs nothing and the real table appears in one piece.
///
/// Distinct from the thinking line, which reports on the model. This reports
/// on the *reply's* shape, and the two can be on screen at once.
class StreamingTablePlaceholder extends StatelessWidget {
  const StreamingTablePlaceholder({super.key, required this.segment});

  final StreamSegment segment;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rows = segment.openRowCount;
    // Keyed so a test — and a screen reader — can tell one frame of a
    // held-back table from the next. Without it the placeholder is
    // indistinguishable from the real table it stands in for.
    return KeyedSubtree(
      key: const Key('streaming_table_placeholder'),
      child: _placeholder(context, l10n, rows),
    );
  }

  Widget _placeholder(
    BuildContext context,
    AppLocalizations l10n,
    int rows,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ClaudeSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: ClaudeSpacing.md,
          vertical: ClaudeSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(ClaudeRadius.sm),
          border: Border.all(color: context.border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: context.inkTertiary,
              ),
            ),
            const SizedBox(width: ClaudeSpacing.sm),
            Expanded(
              child: Text(
                rows == 0
                    ? l10n.streamingTableStarting
                    : l10n.streamingTableBuilding(rows),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.inkTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
