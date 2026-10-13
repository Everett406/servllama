import 'package:flutter/material.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';
import 'package:servllama/app/widgets/claude_icons.dart';
import 'package:servllama/features/chat/models/chat_tool_call.dart';

/// One row per tool the model called.
///
/// Its own line rather than folded into the thinking line, because a tool call
/// is something the model *did*, not something it was thinking about — and the
/// user may well want to know the answer was looked up rather than recalled.
/// The row expands to show the arguments that were sent and the result that
/// came back, which is the only way to tell a good retrieval from a confident
/// one.
class ToolCallRow extends StatefulWidget {
  const ToolCallRow({
    super.key,
    required this.call,
    required this.result,
    this.running = false,
  });

  final ChatToolCall call;
  final ChatToolResult? result;

  /// True while the tool is executing and there is nothing to show yet.
  final bool running;

  @override
  State<ToolCallRow> createState() => _ToolCallRowState();
}

class _ToolCallRowState extends State<ToolCallRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final failed = result?.failed ?? false;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: Key('tool_call_row_${widget.call.name}_${widget.call.id}'),
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(ClaudeRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  if (widget.running)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: context.inkTertiary,
                      ),
                    )
                  else
                    ClaudeIcon(
                      failed ? ClaudeIcons.chip : ClaudeIcons.star,
                      size: 12,
                      color: failed ? context.accent : context.inkTertiary,
                    ),
                  const SizedBox(width: ClaudeSpacing.sm),
                  Expanded(
                    child: Text(
                      _title(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.inkSecondary,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: context.inkTertiary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 2),
            _Detail(
              // Deliberately not localised: these sit next to the raw JSON
              // above them, and a translated label between two JSON blocks
              // reads as part of the payload.
              label: 'arguments',
              value: widget.call.arguments.isEmpty ? '—' : widget.call.arguments,
            ),
            if (result != null)
              _Detail(
                label: failed ? 'error' : 'result',
                value: result.error ?? result.result,
                error: failed,
              ),
          ],
        ],
      ),
    );
  }

  String _title(BuildContext context) {
    if (widget.running) return '${widget.call.name} …';
    final result = widget.result;
    if (result == null) return widget.call.name;
    if (result.failed) return '${widget.call.name} · 失败';
    return widget.call.name;
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.label,
    required this.value,
    this.error = false,
  });

  final String label;
  final String value;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.inkTertiary),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: error ? context.accent : context.inkSecondary,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
