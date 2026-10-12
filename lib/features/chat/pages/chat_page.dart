import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';
import 'package:servllama/app/widgets/claude_icons.dart';
import 'package:servllama/core/models/engine_runtime_state.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/library_model.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/core/providers/model_management_provider.dart';
import 'package:servllama/features/chat/controllers/chat_scroll_coordinator.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/chat/services/image_attachment_service.dart';
import 'package:servllama/features/chat/widgets/chat_composer.dart';
import 'package:servllama/features/chat/widgets/chat_empty_state.dart';
import 'package:servllama/features/chat/widgets/chat_engine_start_sheet.dart';
import 'package:servllama/features/chat/widgets/chat_message_list.dart';
import 'package:servllama/features/chat/widgets/chat_model_sheet.dart';
import 'package:servllama/features/chat/widgets/context_usage_bar.dart';
import 'package:servllama/features/downloads/pages/model_discovery_page.dart';
import 'package:servllama/features/settings/pages/settings_page.dart';
import 'package:servllama/features/downloads/providers/download_provider.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/l10n/runtime_labels.dart';

/// The chat canvas: a thin contextual bar, then either an empty-state hero
/// with the composer centred beneath it, or the transcript with the composer
/// pinned to the bottom.
class ChatPage extends StatelessWidget {
  const ChatPage({
    super.key,
    this.provider,
    this.onOpenSidebar,
    this.onOpenHistory,
  });

  final ChatProvider? provider;
  final VoidCallback? onOpenSidebar;
  final VoidCallback? onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final existing = provider;
    if (existing != null) {
      return ChangeNotifierProvider<ChatProvider>.value(
        value: existing,
        child: _ChatView(
          onOpenSidebar: onOpenSidebar,
          onOpenHistory: onOpenHistory,
        ),
      );
    }
    return _ChatView(
      onOpenSidebar: onOpenSidebar,
      onOpenHistory: onOpenHistory,
    );
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView({this.onOpenSidebar, this.onOpenHistory});

  final VoidCallback? onOpenSidebar;
  final VoidCallback? onOpenHistory;

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final ChatScrollCoordinator _scroll = ChatScrollCoordinator();
  final TextEditingController _input = TextEditingController();
  final ImageAttachmentService _images = ImageAttachmentService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ChatProvider>().load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scroll.attachProvider(context.read<ChatProvider>());
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final provider = context.read<ChatProvider>();
    final text = _input.text;
    if (text.trim().isEmpty && provider.pendingImageAttachments.isEmpty) {
      return;
    }
    _input.clear();
    _scroll.enableAutoStickToBottom();
    final attachments = List<String>.from(provider.pendingImageAttachments);
    await provider.sendMessage(text, imageAttachments: attachments);
    if (!mounted) return;
    final error = provider.lastErrorMessage;
    if (error != null) {
      provider.clearLastError();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _pickImage() async {
    final provider = context.read<ChatProvider>();
    try {
      final paths = await _images.pickFromGallery(
        currentCount: provider.pendingImageAttachments.length,
      );
      for (final path in paths) {
        provider.addImageAttachment(path);
      }
    } on ImageAttachmentException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _startServer() async {
    final runtime = context.read<EngineRuntimeProvider?>();
    if (runtime == null) return;

    if (runtime.isRunning) {
      await runtime.stop();
      if (mounted) _showRuntimeError(runtime);
      return;
    }
    if (runtime.isBusy) {
      await runtime.cancel();
      return;
    }

    final library = context.read<ModelManagementProvider>();
    unawaited(library.load());
    final engine = await showModalBottomSheet<InferenceEngine>(
      context: context,
      builder: (sheetContext) =>
          Consumer<EngineRuntimeProvider>(
            builder: (_, runtime, __) => ChatEngineStartSheet(
              currentEngine: runtime.activeEngine,
              defaultModelNames: <InferenceEngine, String?>{
                for (final engine in InferenceEngine.values)
                  engine: _modelDisplayName(
                    library,
                    engine,
                    runtime.selectedModelIdFor(engine),
                  ),
              },
              onSelect: (engine) => Navigator.of(sheetContext).pop(engine),
            ),
          ),
    );
    if (engine == null || !mounted) return;

    if (runtime.activeEngine != engine) {
      await runtime.switchEngine(engine);
    }
    if (!mounted || runtime.activeEngine != engine) return;

    // Both engines are model-specific, so a missing selection means the next
    // step is picking one rather than starting.
    if (runtime.selectedModelId == null) {
      await _showModels();
      return;
    }

    await runtime.start();
    if (mounted) _showRuntimeError(runtime);
  }

  String? _modelDisplayName(
    ModelManagementProvider library,
    InferenceEngine engine,
    String? modelId,
  ) {
    if (modelId == null) return null;
    for (final model in library.libraryModelsFor(engine)) {
      if (model.runtimeId == modelId) return model.name;
    }
    return modelId;
  }

  Future<void> _showModels() async {
    final runtime = context.read<EngineRuntimeProvider?>();
    if (runtime == null) return;
    final library = context.read<ModelManagementProvider>();
    unawaited(library.load());

    final picked = await showModalBottomSheet<LibraryModel>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) =>
          Consumer3<EngineRuntimeProvider, ModelManagementProvider, DownloadProvider>(
            builder: (_, runtime, library, downloads, __) {
              final engine = runtime.activeEngine;
              final error = runtime.lastError;
              return ChatModelSheet(
                engine: engine,
                models: library.libraryModelsFor(engine),
                activeModelId: runtime.isRunning ? runtime.activeModelId : null,
                pendingModelId: runtime.isBusy ? runtime.selectedModelId : null,
                downloading: downloads.activeTasks
                    .where((task) => task.engine == engine)
                    .toList(growable: false),
                errorText: error == null
                    ? null
                    : RuntimeLabels.runtimeError(
                        context.l10n,
                        error,
                        runtime.port,
                      ),
                onSelect: (model) => Navigator.of(sheetContext).pop(model),
                onDiscover: () {
                  Navigator.of(sheetContext).pop();
                  _openDiscovery();
                },
              );
            },
          ),
    );

    if (picked == null || !mounted) return;
    await runtime.activateModel(picked.runtimeId);
    if (mounted) _showRuntimeError(runtime);
  }

  void _openDiscovery() {
    unawaited(
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const ModelDiscoveryPage())),
    );
  }

  void _openSettings() {
    unawaited(
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage())),
    );
  }

  void _showRuntimeError(EngineRuntimeProvider runtime) {
    final error = runtime.lastError;
    if (error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(RuntimeLabels.runtimeError(context.l10n, error, runtime.port)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final runtime = context.watch<EngineRuntimeProvider?>();
    final isEmpty = chat.visibleMessages.isEmpty && !chat.isLoadingMessages;

    return Scaffold(
      backgroundColor: context.canvas,
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: _scroll,
          builder: (context, _) => Stack(
            children: [
              Column(
                children: [
                  _ChatTopBar(
                    onOpenSidebar: widget.onOpenSidebar,
                    isStealth: chat.isStealthMode,
                    onStealthChanged: chat.setStealthMode,
                  ),
                  Expanded(
                    child: isEmpty
                        ? ChatEmptyState(
                            status: runtime?.status ?? EngineRuntimeStatus.idle,
                            hasModels:
                                context.watch<ModelManagementProvider>().libraryModels.isNotEmpty,
                            onStartServer: _startServer,
                            onSelectModel: _showModels,
                            onBrowseModels: () => _openDiscovery(),
                          )
                        : ChatMessageListView(coordinator: _scroll),
                  ),
                  Padding(
                    // The transcript runs under the gesture bar on purpose,
                    // but the composer must not: it is the one control the
                    // thumb has to reach, so it clears the system inset
                    // instead of hiding behind it.
                    padding: EdgeInsets.fromLTRB(
                      ClaudeSpacing.lg,
                      0,
                      ClaudeSpacing.lg,
                      _composerBottomInset(context),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: ClaudeSpacing.readingWidth,
                        ),
                        child: ChatComposer(
                          controller: _input,
                          onSend: _send,
                          onStop: chat.cancelStreaming,
                          onPickImage: _pickImage,
                          onStartServer: _startServer,
                          onSelectModel: _showModels,
                          onOpenSettings: _openSettings,
                        ),
                      ),
                    ),
                  ),
                  // Sits in the strip the gesture bar would otherwise own.
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      ClaudeSpacing.lg,
                      10,
                      ClaudeSpacing.lg,
                      MediaQuery.viewInsetsOf(context).bottom > 0
                          ? 0
                          : ClaudeSpacing.sm,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: ClaudeSpacing.readingWidth,
                        ),
                        child: ContextUsageBar(
                          messages: chat.visibleMessages,
                          contextWindow: runtime?.contextWindow,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (!isEmpty)
                Positioned(
                  right: ClaudeSpacing.lg,
                  bottom: MediaQuery.viewInsetsOf(context).bottom +
                      ClaudeSpacing.xxl * 2,
                  child: AnimatedSlide(
                    offset: _scroll.showJumpToLatestButton
                        ? Offset.zero
                        : const Offset(0, 0.4),
                    duration: ClaudeMotion.medium,
                    curve: ClaudeMotion.curve,
                    child: AnimatedOpacity(
                      opacity: _scroll.showJumpToLatestButton ? 1 : 0,
                      duration: ClaudeMotion.fast,
                      child: IgnorePointer(
                        ignoring: !_scroll.showJumpToLatestButton,
                        child: JumpToLatestButton(
                          onPressed: _scroll.jumpToLatestMessage,
                        ),
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

/// Vertical breathing room under the composer.
///
/// While the keyboard is up it owns the bottom of the screen, so only a
/// small gap is needed; with it down the gesture bar does, and the composer
/// has to clear that too or half of the send control sits under it.
double _composerBottomInset(BuildContext context) {
  final keyboard = MediaQuery.viewInsetsOf(context).bottom;
  if (keyboard > 0) return ClaudeSpacing.sm;
  return ClaudeSpacing.lg + MediaQuery.viewPaddingOf(context).bottom;
}

/// Stealth toggle.
///
/// Sits at the trailing corner because it is a promise about what will
/// happen to this conversation, and promises live where the eye already
/// rests after reading. When it is on the whole bar takes a faint tint, so
/// the mode is visible for the rest of the conversation rather than only at
/// the moment it was switched.
class _StealthToggle extends StatelessWidget {
  const _StealthToggle({required this.active, required this.onChanged});

  final bool active;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tooltip = active
        ? context.l10n.chatStealthOn
        : context.l10n.chatStealthOff;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        toggled: active,
        button: true,
        label: tooltip,
        child: Material(
          color: active ? context.accentSubtle : Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            key: const Key('chat_stealth_button'),
            onTap: () => onChanged(!active),
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 38,
              height: 38,
              child: Center(
                child: ClaudeIcon(
                  ClaudeIcons.ghost,
                  size: 19,
                  color: active ? context.accent : context.inkTertiary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin contextual bar. Everything here is secondary to the conversation —
/// no title, no tabs, no chrome beyond what the user needs right now.
/// The top strip.
///
/// Two round buttons and nothing else. An earlier version carried the
/// conversation title, a model pill, a server status dot and a history
/// entry — four things competing for a row that has no room to spare, and
/// none of them needed to be there: the model belongs with the model, the
/// engine belongs in the sidebar, and the title is the one piece of text
/// everybody already knows. The rule underneath it went too, since a
/// hairline across a canvas that already separates the sidebar from the
/// canvas just draws the boundary twice.
class _ChatTopBar extends StatelessWidget {
  const _ChatTopBar({
    required this.isStealth,
    required this.onStealthChanged,
    this.onOpenSidebar,
  });

  final bool isStealth;
  final ValueChanged<bool> onStealthChanged;
  final VoidCallback? onOpenSidebar;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: ClaudeSpacing.sm),
        child: Row(
          children: [
            _CircleButton(
              keyValue: 'chat_open_sidebar_button',
              tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
              onPressed: onOpenSidebar,
              icon: ClaudeIcons.menu,
            ),
            const Spacer(),
            _StealthToggle(
              active: isStealth,
              onChanged: onStealthChanged,
            ),
          ],
        ),
      ),
    );
  }
}

/// A bare round control. No label, no background until it is pressed.
class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.keyValue,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final String keyValue;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            key: Key(keyValue),
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: ClaudeIcon(
                  icon,
                  size: 20,
                  color: context.inkSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
