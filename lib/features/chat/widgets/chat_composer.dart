import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';
import 'package:servllama/app/widgets/claude_icons.dart';
import 'package:servllama/features/chat/models/chat_model_option.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/l10n/l10n.dart';

/// The message composer.
///
/// One rounded panel, one text column, and a single row of controls pinned
/// to its bottom edge. The send control lives in that row at the trailing
/// corner rather than floating beside the text, because the thumb reaches
/// the bottom-right of the screen — not the middle of the panel.
///
/// Nothing here shouts. When the server is down the placeholder says so and
/// the engine button on the left is the fix; a second line of coloured text
/// repeating the same sentence was two pieces of advice fighting for one
/// piece of information.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onStop,
    required this.onPickImage,
    required this.onStartServer,
    required this.onSelectModel,
    required this.onOpenSettings,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onPickImage;
  final VoidCallback onStartServer;
  final VoidCallback onSelectModel;
  final VoidCallback onOpenSettings;

  @override
  State<ChatComposer> createState() => ChatComposerState();
}

class ChatComposerState extends State<ChatComposer> {
  static const double _maxFieldHeight = 168;

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

    final hint = switch ((isRunning, modelReady)) {
      (false, _) => l10n.chatInputHintStartServer,
      (true, false) => l10n.chatInputHintSelectModel,
      (true, true) => l10n.chatInputHintEnterMessage,
    };

    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(ClaudeRadius.composer),
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
            ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: _maxFieldHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 2),
              child: TextField(
                key: const Key('chat_input_field'),
                controller: widget.controller,
                focusNode: _focusNode,
                minLines: 1,
                maxLines: null,
                // Typing stays available mid-stream: the text sits in the
                // field and send swaps to stop, so the next question can be
                // lined up while a reply runs.
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
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
            // Attach first, send last, engine under the thumb: the order
            // matches how the row is read — build the message, then commit
            // it, then deal with the machine.
            child: Row(
              children: [
                _RoundIconButton(
                  keyValue: 'chat_attach_button',
                  icon: ClaudeIcons.plus,
                  tooltip: l10n.chatAttachImage,
                  onPressed: isSending || !isRunning ? null : widget.onPickImage,
                ),
                const Spacer(),
                _EngineButton(
                  running: isRunning,
                  modelReady: modelReady,
                  onTap: isRunning ? widget.onOpenSettings : widget.onStartServer,
                  onSelectModel: widget.onSelectModel,
                  model: model,
                ),
                const SizedBox(width: 6),
                _SendStopButton(
                  isSending: isSending,
                  canSend: canSend,
                  onSend: widget.onSend,
                  onStop: widget.onStop,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Server state on the left of the composer.
///
/// Tapping it is the fix when the engine is down and the settings shortcut
/// once it is up, which is the same affordance the sidebar's status strip
/// offers — kept here so the composer never has to explain itself in words.
class _EngineButton extends StatelessWidget {
  const _EngineButton({
    required this.running,
    required this.modelReady,
    required this.onTap,
    required this.onSelectModel,
    required this.model,
  });

  final bool running;
  final bool modelReady;
  final VoidCallback onTap;
  final VoidCallback onSelectModel;
  final ChatModelOption? model;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundIconButton(
          keyValue: 'chat_engine_button',
          icon: running ? ClaudeIcons.chip : ClaudeIcons.stop,
          tooltip: context.l10n.drawerSettings,
          onPressed: onTap,
          active: running,
        ),
        const SizedBox(width: 2),
        if (running)
          _ModelChip(model: model, onTap: onSelectModel)
        else
          // Quiet affordance: the placeholder already says what is wrong, so
          // this only has to offer the repair.
          Semantics(
            button: true,
            label: context.l10n.chatInputHintStartServer,
            child: InkWell(
              key: const Key('chat_blocked_action'),
              onTap: onTap,
              borderRadius: BorderRadius.circular(ClaudeRadius.pill),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  context.l10n.chatStartServer,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: context.accent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.keyValue,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final String? keyValue;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: active ? context.accentSubtle : context.surfaceSunken,
          shape: const CircleBorder(),
          child: InkWell(
            key: keyValue == null ? null : Key(keyValue!),
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: ClaudeIcon(
                  icon,
                  size: 18,
                  color: !enabled
                      ? context.inkTertiary.withAlpha(120)
                      : active
                      ? context.accent
                      : context.inkSecondary,
                ),
              ),
            ),
          ),
        ),
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
        shape: const CircleBorder(),
        child: InkWell(
          key: Key(isSending ? 'chat_stop_button' : 'chat_send_button'),
          onTap: isSending ? onStop : (canSend ? onSend : null),
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: ClaudeMotion.fast,
            curve: ClaudeMotion.curve,
            width: 38,
            height: 38,
            child: Center(
              child: ClaudeIcon(
                isSending ? ClaudeIcons.stop : ClaudeIcons.send,
                size: 19,
                color: active
                    ? ClaudeColors.onAccent
                    : context.inkTertiary.withAlpha(140),
              ),
            ),
          ),
        ),
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
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
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
              ClaudeIcon(
                ClaudeIcons.chevronDown,
                size: 13,
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
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
        itemCount: paths.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final path = paths[index];
          return Stack(
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
                    child: ClaudeIcon(
                      ClaudeIcons.image,
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
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: Center(
                        child: ClaudeIcon(
                          ClaudeIcons.stop,
                          size: 10,
                          color: ClaudeColors.canvas,
                        ),
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