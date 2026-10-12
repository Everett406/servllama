import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/widgets/claude_icons.dart';
import 'package:servllama/app/design/tokens.dart';
import 'package:servllama/features/chat/controllers/streaming_chat_message_notifier.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/widgets/streaming_fade_text.dart';
import 'package:servllama/features/chat/widgets/token_stats.dart';
import 'package:servllama/features/chat/widgets/thinking_card.dart';
import 'package:servllama/l10n/l10n.dart';

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
      liveContent: widget.liveReasoning,
      liveElapsed: ValueNotifier<Duration>(
        ThinkingTimings.frozen(message.id) ?? elapsed,
      ),
    );
    if (mounted) setState(() => _showReasoning = false);
  }

  bool get _isUser => widget.message.role == ChatRole.user;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final reasoning = message.reasoningContent?.trim() ?? '';
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
            _UserBubble(content: content, id: message.id),
          if (!_isUser) ...[
            // Shown while generating even with nothing to quote yet: a
            // reply that has not appeared needs to say why it has not
            // appeared, and an empty gap is not a reason.
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
          _ActionBar(
            // Was gated on hover, which is a pointer concept. On a
            // phone there is no hover, so the row simply never appeared.
            visible: widget.canManage,
            isStreaming: widget.isStreaming,
            messageId: message.id,
            onCopy: hasContent ? widget.onCopy : null,
            onRegenerate: _isUser ? null : widget.onRegenerate,
            onEdit: _isUser ? widget.onEdit : null,
            onDelete: widget.onDelete,
            timestamp: !_isUser && !widget.isStreaming
                ? _formatTimestamp(context, message.createdAt)
                : null,
            throughput: !_isUser && !widget.isStreaming
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
  const _UserBubble({required this.content, required this.id});

  final String content;
  final String id;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
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
      child: FadingMarkdown(
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
    required this.onEdit,
    required this.onDelete,
    this.timestamp,
    this.throughput,
  });

  final bool visible;
  final bool isStreaming;
  final String messageId;
  final VoidCallback? onCopy;
  final VoidCallback? onRegenerate;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

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
            _ActionButton(
              key: Key('chat_message_copy_button_$messageId'),
              icon: ClaudeIcons.copy,
              tooltip: context.l10n.chatCopyMessage,
              onPressed: onCopy == null ? null : () => onCopy!(),
            ),
            if (onEdit != null)
              _ActionButton(
                key: Key('chat_message_edit_button_$messageId'),
                icon: ClaudeIcons.edit,
                tooltip: context.l10n.chatEditMessage,
                onPressed: onEdit,
              ),
            if (onRegenerate != null && !isStreaming)
              _ActionButton(
                key: Key('chat_message_regenerate_button_$messageId'),
                icon: ClaudeIcons.regenerate,
                tooltip: context.l10n.chatRegenerateMessage,
                onPressed: onRegenerate,
              ),
            if (onDelete != null)
              _ActionButton(
                key: Key('chat_message_delete_button_$messageId'),
                icon: ClaudeIcons.trash,
                tooltip: context.l10n.commonDelete,
                onPressed: onDelete,
                destructive: true,
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
    this.destructive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: ClaudeIcons.render(icon, size: 17),
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        color: destructive
            ? context.dangerText
            : onPressed == null
            ? context.inkTertiary
            : context.inkSecondary,
        iconSize: 17,
      ),
    );
  }
}
