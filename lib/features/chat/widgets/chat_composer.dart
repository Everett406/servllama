import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';
import 'package:servllama/app/widgets/shell_bits.dart';
import 'package:servllama/features/chat/models/chat_model_option.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/l10n/l10n.dart';

/// The message composer.
///
/// Sits inside a bordered rounded panel with the send control inset at the
/// trailing edge, so the whole thing reads as one object rather than a text
/// field with buttons parked next to it. Grows with content up to a ceiling,
/// then scrolls.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onStop,
    required this.onPickImage,
    required this.onStartServer,
    required this.onSelectModel,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onPickImage;
  final VoidCallback onStartServer;
  final VoidCallback onSelectModel;

  @override
  State<ChatComposer> createState() => ChatComposerState();
}

class ChatComposerState extends State<ChatComposer> {
  static const double _maxFieldHeight = 200;

  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncText);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncText);
    _focusNode.dispose();
    super.dispose();
  }

  void _syncText() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final l10n = context.l10n;

    final isSending = chat.isSending;
    final isRunning = chat.isServerRunning;
    final model = chat.currentModel;
    final modelReady = model?.status == ChatModelStatus.loaded;
    final canSend = chat.canSend && _hasText;
    final pendingImages = chat.pendingImageAttachments;

    final (hint, blockedAction) = switch ((
      isRunning,
      modelReady,
    )) {
      (false, _) => (l10n.chatInputHintStartServer, widget.onStartServer),
      (true, false) => (l10n.chatInputHintSelectModel, widget.onSelectModel),
      (true, true) => (l10n.chatInputHintEnterMessage, null),
    };

    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(ClaudeRadius.xl),
        border: Border.all(color: context.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pendingImages.isNotEmpty)
            _PendingImagesStrip(
              paths: pendingImages,
              onRemove: chat.removeImageAttachment,
            ),          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: _maxFieldHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: _maxFieldHeight),
                      child: TextField(
                        key: const Key('chat_input_field'),
                        controller: widget.controller,
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: null,
                        // Typing stays available mid-stream: the text sits in
                        // the field and the send button swaps to stop, so the
                        // user can line up the next question while a reply runs.
                        enabled: true,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        textCapitalization: TextCapitalization.sentences,
                        style: Theme.of(context).textTheme.bodyLarge,
                        cursorColor: context.accent,
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          hintText: hint,
                          hintStyle: TextStyle(
                            color: context.inkTertiary,
                            fontSize: 16,
                          ),
                        ),
                        onSubmitted: (_) {
                          if (canSend) widget.onSend();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _SendStopButton(
                    isSending: isSending,
                    canSend: canSend,
                    onSend: widget.onSend,
                    onStop: widget.onStop,
                  ),
                ],
              ),
            ),
          ),
          _ComposerToolbar(
            hint: hint,
            blockedAction: blockedAction,
            isRunning: isRunning,
            modelReady: modelReady,
            model: model,
            attachmentsDisabled: isSending || !isRunning,
            onPickImage: widget.onPickImage,
            onSelectModel: widget.onSelectModel,
          ),
        ],
      ),
    );
  }
}

class _SendStopButton extends StatelessWidget {
  const _SendStopButton({
    required this.isSending,
    required this.canSend,
    required this.onSend,
    required this.onStop,
  });

  final bool isSending;
  final bool canSend;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final active = isSending || canSend;
    return Semantics(
      button: true,
      label: isSending ? context.l10n.chatStop : context.l10n.chatSend,
      child: Material(
        color: active ? context.accent : context.surfaceSunken,
        borderRadius: BorderRadius.circular(ClaudeRadius.md),
        child: InkWell(
          key: Key(isSending ? 'chat_stop_button' : 'chat_send_button'),
          onTap: isSending ? onStop : (canSend ? onSend : null),
          borderRadius: BorderRadius.circular(ClaudeRadius.md),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(
              isSending ? Icons.stop_rounded : Icons.arrow_upward_rounded,
              size: 19,
              color: active
                  ? ClaudeColors.onAccent
                  : context.inkTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerToolbar extends StatelessWidget {
  const _ComposerToolbar({
    required this.hint,
    required this.blockedAction,
    required this.isRunning,
    required this.modelReady,
    required this.model,
    required this.attachmentsDisabled,
    required this.onPickImage,
    required this.onSelectModel,
  });

  final String hint;
  final VoidCallback? blockedAction;
  final bool isRunning;
  final bool modelReady;
  final ChatModelOption? model;
  final bool attachmentsDisabled;
  final VoidCallback onPickImage;
  final VoidCallback onSelectModel;

  @override
  Widget build(BuildContext context) {
    final blocked = !isRunning || !modelReady;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        children: [
          IconButton(
            key: const Key('chat_attach_button'),
            tooltip: context.l10n.chatAttachImage,
            onPressed: attachmentsDisabled ? null : onPickImage,
            icon: const Icon(Icons.image_outlined, size: 20),
            visualDensity: VisualDensity.compact,
            color: context.inkSecondary,
          ),
          if (blocked)
            // The hint doubles as the recovery action — telling someone the
            // server is off without also giving them the button wastes a tap.
            Flexible(
              child: TextButton.icon(
                key: const Key('chat_blocked_action'),
                onPressed: blockedAction,
                icon: Icon(
                  isRunning
                      ? Icons.memory_rounded
                      : Icons.play_circle_outline_rounded,
                  size: 16,
                ),
                label: Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            )
          else
            Flexible(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _ModelChip(model: model, onTap: onSelectModel),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModelChip extends StatelessWidget {
  const _ModelChip({required this.model, required this.onTap});

  final ChatModelOption? model;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = model?.displayName ?? context.l10n.chatSelectModel;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ClaudeRadius.pill),
      child: InkWell(
        key: const Key('chat_model_chip'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(ClaudeRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusDot(color: context.okText, size: 6),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 190),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: context.inkSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.expand_more_rounded,
                size: 16,
                color: context.inkTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingImagesStrip extends StatelessWidget {
  const _PendingImagesStrip({required this.paths, required this.onRemove});

  final List<String> paths;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        itemCount: paths.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final path = paths[index];          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(ClaudeRadius.sm),
                child: Image.file(
                  File(path),
                  width: 62,
                  height: 62,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 62,
                    height: 62,
                    color: context.surfaceSunken,
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 18,
                      color: context.inkTertiary,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -5,
                right: -5,
                child: Material(
                  color: context.ink,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => onRemove(index),
                    child: const SizedBox(
                      width: 20,
                      height: 20,
                      child: Icon(
                        Icons.close_rounded,
                        size: 13,
                        color: ClaudeColors.canvas,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
