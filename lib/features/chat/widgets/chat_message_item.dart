import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
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
    this.canManage = false,
    this.onCopy,
    this.onRegenerate,
    this.onEdit,
    this.onDelete,
  });

  final ChatMessageRecord message;
  final bool isStreaming;
  final bool canManage;
  final VoidCallback? onCopy;
  final VoidCallback? onRegenerate;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<ChatMessageItem> createState() => _ChatMessageItemState();
}

class _ChatMessageItemState extends State<ChatMessageItem> {
  bool _hovered = false;
  bool _showReasoning = false;

  bool get _isUser => widget.message.role == ChatRole.user;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final reasoning = message.reasoningContent?.trim() ?? '';
    final content = message.content;
    final hasContent = content.trim().isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
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
            if (_isUser && hasContent) _UserBubble(content: content, id: message.id),
            if (!_isUser) ...[
              if (reasoning.isNotEmpty)
                _ReasoningBlock(
                  content: reasoning,
                  expanded: _showReasoning,
                  onToggle: () =>
                      setState(() => _showReasoning = !_showReasoning),
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
              visible: widget.canManage && _hovered,
              isStreaming: widget.isStreaming,
              messageId: message.id,
              onCopy: hasContent ? widget.onCopy : null,
              onRegenerate: _isUser ? null : widget.onRegenerate,
              onEdit: _isUser ? widget.onEdit : null,
              onDelete: widget.onDelete,
            ),
          ],
        ),
      ),
    );
  }
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
    return RepaintBoundary(
      child: GptMarkdown(
        content.isEmpty && isStreaming ? '…' : content,
        key: Key('chat_message_target_${id}_content'),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: context.ink,
          height: 1.68,
        ),
      ),
    );
  }
}

/// Collapsible chain-of-thought. Collapsed by default: most people never read
/// it, and an expanded block pushes the actual answer off-screen.
class _ReasoningBlock extends StatelessWidget {
  const _ReasoningBlock({
    required this.content,
    required this.expanded,
    required this.onToggle,
  });

  final String content;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: ClaudeSpacing.md),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: context.borderStrong, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(ClaudeRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: ClaudeMotion.fast,
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: context.inkTertiary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    context.l10n.chatThinkingLabel,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 0, 0),
              child: Text(
                content,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.inkTertiary,
                  height: 1.6,
                ),
              ),
            ),
        ],
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
  });

  final bool visible;
  final bool isStreaming;
  final String messageId;
  final VoidCallback? onCopy;
  final VoidCallback? onRegenerate;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

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
              icon: Icons.copy_rounded,
              tooltip: context.l10n.chatCopyMessage,
              onPressed: onCopy == null ? null : () => onCopy!(),
            ),
            if (onEdit != null)
              _ActionButton(
                key: Key('chat_message_edit_button_$messageId'),
                icon: Icons.edit_outlined,
                tooltip: context.l10n.chatEditMessage,
                onPressed: onEdit,
              ),
            if (onRegenerate != null && !isStreaming)
              _ActionButton(
                key: Key('chat_message_regenerate_button_$messageId'),
                icon: Icons.refresh_rounded,
                tooltip: context.l10n.chatRegenerateMessage,
                onPressed: onRegenerate,
              ),
            if (onDelete != null)
              _ActionButton(
                key: Key('chat_message_delete_button_$messageId'),
                icon: Icons.delete_outline_rounded,
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
        icon: Icon(icon, size: 17),
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
