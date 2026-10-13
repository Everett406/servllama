import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/widgets/claude_icons.dart';
import 'package:servllama/app/design/tokens.dart';
import 'package:servllama/features/chat/controllers/streaming_chat_message_notifier.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/widgets/token_stats.dart';
import 'package:servllama/features/chat/widgets/answer_markdown.dart';
import 'package:servllama/features/chat/widgets/prefill_orb.dart';
import 'package:servllama/features/chat/widgets/thinking_card.dart';
import 'package:servllama/features/chat/widgets/tool_call_row.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/app/sheet/vela_sheet.dart';

/// One message in the transcript.
///
/// User turns get a soft, right-aligned bubble; assistant turns get none at
/// all and read as continuous prose on the canvas. That asymmetry is the
/// whole trick — it keeps the eye on the answer instead of on a stack of
/// alternating boxes.
class ChatMessageItem extends StatefulWidget {
  const ChatMessageItem({
    super.key,
    required this.message,
    this.isStreaming = false,
    this.promptedAt,
    this.stream,
    this.liveReasoning,
    this.canManage = false,
    this.onCopy,
    this.onRegenerate,

    /// Kept on the public API so callers do not have to know which actions
    /// moved behind the long press. It is what that menu calls.
    this.onEdit,
    this.onDelete,
  });

  final ChatMessageRecord message;
  final bool isStreaming;

  /// When the prompt that produced this message was sent.
  final DateTime? promptedAt;

  /// The live stream, so the thought sheet can follow the model instead of
  /// showing a snapshot the user has to close and reopen to refresh.
  final ValueListenable<StreamingChatMessageData>? stream;

  /// Live reasoning text, for the thought sheet to follow.
  final ValueListenable<String>? liveReasoning;
  final bool canManage;
  final VoidCallback? onCopy;
  final VoidCallback? onRegenerate;
  final VoidCallback? onEdit;

  /// Not offered anywhere. Kept so removing it stays a call-site decision
  /// rather than a signature change.
  final VoidCallback? onDelete;

  @override
  State<ChatMessageItem> createState() => _ChatMessageItemState();
}

class _ChatMessageItemState extends State<ChatMessageItem> {
  bool _showReasoning = false;

  /// Opens the thought in a sheet and drops the inline marker afterwards.
  ///
  /// The inline state exists only to keep the row's hit target honest while
  /// the sheet is up; the sheet is what the user actually reads.
  Future<void> _openThinking() async {
    if (_showReasoning) {
      setState(() => _showReasoning = false);
      return;
    }
    setState(() => _showReasoning = true);
    final message = widget.message;
    final promptedAt = widget.promptedAt;
    var elapsed =
        ThinkingTimings.frozen(message.id) ??
        (promptedAt == null
            ? Duration.zero
            : DateTime.now().difference(promptedAt));
    if (elapsed.isNegative) elapsed = Duration.zero;
    if (!mounted) return;
    await showThinkingSheet(
      context,
      content: message.reasoningContent ?? '',
      elapsed: elapsed,
      messageId: message.id,
      liveContent: _liveReasoning,
      answerStarted: (message.content).trim().isNotEmpty,
    );
    if (mounted) setState(() => _showReasoning = false);
  }

  bool get _isUser => widget.message.role == ChatRole.user;

  /// Copy or edit, asked for rather than offered.
  ///
  /// Destructive or rarely used actions behind a press-and-hold is the
  /// mobile convention; a permanent row under the bubble spends vertical
  /// space on every message in the transcript to advertise two buttons.
  Future<void> _openUserActions(String content) async {
    final l10n = context.l10n;
    final choice = await showVelaSheet<String>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          decoration: BoxDecoration(
            color: sheetContext.surface,
            borderRadius: BorderRadius.circular(ClaudeRadius.xl),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: ClaudeIcon(ClaudeIcons.copy),
                title: Text(l10n.chatCopyMessage),
                onTap: () => Navigator.of(sheetContext).pop('copy'),
              ),
              ListTile(
                leading: ClaudeIcon(ClaudeIcons.edit),
                title: Text(l10n.chatEditMessage),
                onTap: () => Navigator.of(sheetContext).pop('edit'),
              ),
            ],
          ),
        ),
      ),
    );
    switch (choice) {
      case 'copy':
        widget.onCopy?.call();
      case 'edit':
        widget.onEdit?.call();
      default:
        break;
    }
  }


  /// Reasoning as the model produces it.
  ///
  /// Owned here rather than handed in. It was projected in the list and
  /// passed down, but only on the branch that builds a streaming item, so a
  /// sheet opened from the other branch was handed nothing to listen to and
  /// showed the text it opened with until you closed it. The sheet is where
  /// you go to watch the thought happen, so it follows the thought.
  late final ValueNotifier<String> _liveReasoning = ValueNotifier<String>(
    widget.message.reasoningContent ?? '',
  );

  @override
  void dispose() {
    _liveReasoning.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final reasoning = message.reasoningContent?.trim() ?? '';
    // This item's own build is the one place that is guaranteed to run with
    // the live message in hand, on either branch.
    final liveReasoning = message.reasoningContent ?? '';
    if (_liveReasoning.value != liveReasoning) {
      _liveReasoning.value = liveReasoning;
    }
    final content = message.content;
    final hasContent = content.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        ClaudeSpacing.lg,
        _isUser ? ClaudeSpacing.sm : ClaudeSpacing.lg,
        ClaudeSpacing.lg,
        _isUser ? ClaudeSpacing.lg : ClaudeSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: _isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (message.imageFilePaths.isNotEmpty)
            _MessageImages(paths: message.imageFilePaths, alignEnd: _isUser),
          if (_isUser && hasContent)
            _UserBubble(
              content: content,
              id: message.id,
              // Your own message carries its actions behind a long press
              // instead of printing them under the bubble. Two grey buttons
              // under every question is a lot of chrome for something you
              // use twice.
              onLongPress: widget.canManage &&
                      (widget.onCopy != null || widget.onEdit != null)
                  ? () => _openUserActions(content)
                  : null,
            ),
          if (!_isUser) ...[
            // Shown while generating even with nothing to quote yet: a
            // reply that has not appeared needs to say why it has not
            // appeared, and an empty gap is not a reason.
            // Pure prefill: generating, but neither a token of the answer nor
            // a word of reasoning yet. The thinking line has nothing to put on
            // screen in that window, so the orb covers it.
            if (widget.isStreaming && !hasContent && reasoning.isEmpty)
              const PrefillOrb(),
            if (reasoning.isNotEmpty || widget.isStreaming)
              ThinkingLine(
                content: reasoning,
                expanded: _showReasoning,
                live: widget.isStreaming,
                answerStarted: hasContent,
                messageId: message.id,
                promptedAt: widget.promptedAt,
                answeredAt: message.createdAt,
                onToggle: _openThinking,
              ),
            // Tool calls get their own line rather than joining the thinking
            // row: one is what the model did, the other is what it was
            // thinking. Merging them says the model thought about a lookup
            // when what actually happened is that it performed one.
            for (var i = 0; i < message.toolCalls.length; i++)
              ToolCallRow(
                call: message.toolCalls[i],
                result: i < message.toolResults.length
                    ? message.toolResults[i]
                    : null,
                running: widget.isStreaming && i >= message.toolResults.length,
              ),
            if (hasContent || widget.isStreaming)
              _AssistantBody(
                content: content,
                id: message.id,
                isStreaming: widget.isStreaming,
              ),
            if (!hasContent && !widget.isStreaming && reasoning.isNotEmpty)
              _AssistantBody(
                content: context.l10n.chatModelRequestFailed(
                  message.modelName ?? '',
                ),
                id: message.id,
                isStreaming: false,
              ),
          ],
          // Actions live in the row's own vertical rhythm and simply fade
          // out, so an assistant turn doesn't shift the transcript when the
          // pointer leaves.
          // Assistant only. A user turn carries copy and edit behind a long
          // press; a reply carries copy and retry inline with its timestamp
          // and rate. Delete was on both rows and was never asked for, and
          // on a reply it is the one button nobody should tap by accident.
          if (!_isUser)
            _ActionBar(
              // Was gated on hover, which is a pointer concept. On a
              // phone there is no hover, so the row simply never appeared.
              visible: widget.canManage,
              isStreaming: widget.isStreaming,
              messageId: message.id,
              onCopy: hasContent ? widget.onCopy : null,
              onRegenerate: widget.onRegenerate,
              timestamp: !widget.isStreaming
                  ? _formatTimestamp(context, message.createdAt)
                  : null,
              throughput: !widget.isStreaming
                  ? _formatThroughput(context, message.id)
                  : null,
            ),
        ],
      ),
    );
  }
}

/// HH:mm, and a date once the reply is no longer from today.
///
/// A bare time is what makes a scrollback readable; a bare date is not
/// enough on its own, so the two are combined rather than chosen between.
String _formatTimestamp(BuildContext context, DateTime at) {
  final now = DateTime.now();
  final time =
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
  final sameDay =
      at.year == now.year && at.month == now.month && at.day == now.day;
  if (sameDay) return time;
  return '${at.month}/${at.day} $time';
}

/// Grey, quiet, and only when there is something to say: too short a stream
/// and the number is noise, and a rate nobody can act on is decoration.
String? _formatThroughput(BuildContext context, String messageId) {
  final rate = TokenStats.tokensPerSecond(messageId);
  if (rate == null || rate <= 0 || rate.isInfinite) return null;
  return context.l10n.chatThroughput(rate.toStringAsFixed(1));
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({
    required this.content,
    required this.id,
    this.onLongPress,
  });

  final String content;
  final String id;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: context.surfaceSunken,
          borderRadius: BorderRadius.circular(ClaudeRadius.xl),
        ),
        child: Text(
          content,
          key: Key('chat_message_target_${id}_content'),
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: context.ink, height: 1.55),
        ),
        ),
      ),
    );
  }
}

class _AssistantBody extends StatelessWidget {
  const _AssistantBody({
    required this.content,
    required this.id,
    required this.isStreaming,
  });

  final String content;
  final String id;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final style =
        Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: context.ink, height: 1.68) ??
        const TextStyle();
    return RepaintBoundary(
      // The package's own reveal: each character resolves out of a blur while
      // it fades in. The previous version painted a canvas-coloured gradient
      // over the last line instead, which veiled whatever happened to be
      // sitting at the bottom — a different effect, and the wrong one.
      child: AnswerMarkdown(
        content: content.isEmpty && isStreaming ? '…' : content,
        isStreaming: isStreaming,
        style: style,
      ),
    );
  }
}

class _MessageImages extends StatelessWidget {
  const _MessageImages({required this.paths, required this.alignEnd});

  final List<String> paths;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ClaudeSpacing.sm),
      child: Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final path in paths)
                ClipRRect(
                  borderRadius: BorderRadius.circular(ClaudeRadius.sm),
                  child: Image.file(
                    File(path),
                    width: 104,
                    height: 104,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 104,
                      height: 104,
                      color: context.surfaceSunken,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: context.inkTertiary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.visible,
    required this.isStreaming,
    required this.messageId,
    required this.onCopy,
    required this.onRegenerate,
    this.timestamp,
    this.throughput,
  });

  final bool visible;
  final bool isStreaming;
  final String messageId;
  final VoidCallback? onCopy;
  final VoidCallback? onRegenerate;

  /// Rendered at the row's leading edge, opposite the controls. When it was
  /// absent the row started with a button and no idea of when anything was
  /// said, which is the one thing a scrollback reader wants first.
  final String? timestamp;

  /// Tokens per second, when the stream was long enough to measure.
  final String? throughput;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: ClaudeMotion.fast,
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          children: [
            // When and how fast, then the two things you can do with it.
            // A row that starts with a button gives no idea when anything
            // was said, which is the first thing a scrollback reader wants.
            if (timestamp != null || throughput != null) ...[
              Flexible(
                child: Text(
                  [timestamp, throughput].whereType<String>().join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.inkTertiary,
                    fontSize: 11.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            _ActionButton(
              key: Key('chat_message_copy_button_$messageId'),
              icon: ClaudeIcons.copy,
              tooltip: context.l10n.chatCopyMessage,
              onPressed: onCopy == null ? null : () => onCopy!(),
            ),
            if (onRegenerate != null && !isStreaming)
              _ActionButton(
                key: Key('chat_message_regenerate_button_$messageId'),
                icon: ClaudeIcons.regenerate,
                tooltip: context.l10n.chatRegenerateMessage,
                onPressed: onRegenerate,
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: ClaudeIcons.render(icon, size: 17),
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        color: onPressed == null ? context.inkTertiary : context.inkSecondary,
        iconSize: 17,
      ),
    );
  }
}
