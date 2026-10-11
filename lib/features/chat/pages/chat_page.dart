import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';
import 'package:servllama/app/widgets/brand_mark.dart';
import 'package:servllama/app/widgets/shell_bits.dart';
import 'package:servllama/core/models/engine_runtime_state.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/library_model.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/core/providers/model_management_provider.dart';
import 'package:servllama/features/chat/controllers/chat_scroll_coordinator.dart';
import 'package:servllama/features/chat/models/chat_model_option.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/chat/services/image_attachment_service.dart';
import 'package:servllama/features/chat/widgets/chat_composer.dart';
import 'package:servllama/features/chat/widgets/chat_empty_state.dart';
import 'package:servllama/features/chat/widgets/chat_engine_start_sheet.dart';
import 'package:servllama/features/chat/widgets/chat_message_list.dart';
import 'package:servllama/features/chat/widgets/chat_model_sheet.dart';
import 'package:servllama/features/downloads/pages/model_discovery_page.dart';
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
                    title: chat.currentSessionTitle,
                    isDraft: chat.isShowingDraftSession,
                    onOpenSidebar: widget.onOpenSidebar,
                    onOpenHistory: widget.onOpenHistory,
                    status: runtime?.status ?? EngineRuntimeStatus.idle,
                    isBusy: runtime?.isBusy ?? false,
                    onToggleRuntime: _startServer,
                    model: chat.currentModel,
                    onSelectModel: _showModels,
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
                    padding: EdgeInsets.fromLTRB(
                      ClaudeSpacing.lg,
                      0,
                      ClaudeSpacing.lg,
                      MediaQuery.viewInsetsOf(context).bottom > 0
                          ? ClaudeSpacing.sm
                          : ClaudeSpacing.lg,
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

/// Thin contextual bar. Everything here is secondary to the conversation —
/// no title, no tabs, no chrome beyond what the user needs right now.
class _ChatTopBar extends StatelessWidget {
  const _ChatTopBar({
    required this.title,
    required this.isDraft,
    required this.onOpenSidebar,
    required this.onOpenHistory,
    required this.status,
    required this.isBusy,
    required this.onToggleRuntime,
    required this.model,
    required this.onSelectModel,
  });

  final String title;
  final bool isDraft;
  final VoidCallback? onOpenSidebar;
  final VoidCallback? onOpenHistory;
  final EngineRuntimeStatus status;
  final bool isBusy;
  final VoidCallback onToggleRuntime;
  final ChatModelOption? model;
  final VoidCallback onSelectModel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (dotColor, label) = switch (status) {
      EngineRuntimeStatus.ready => (context.okText, l10n.serverStatusRunning),
      EngineRuntimeStatus.preparing => (context.accent, l10n.serverStatusPreparing),
      EngineRuntimeStatus.stopping => (context.accent, l10n.serverStatusStopping),
      EngineRuntimeStatus.error => (context.dangerText, l10n.serverStatusError),
      EngineRuntimeStatus.idle => (context.inkTertiary, l10n.serverStatusIdle),
    };

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: ClaudeSpacing.sm),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.border)),
      ),
      child: Row(
        children: [
          IconButton(
            key: const Key('chat_open_sidebar_button'),
            tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
            onPressed: onOpenSidebar,
            icon: const Icon(Icons.menu_rounded, size: 22),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isDraft ? context.inkTertiary : context.ink,
              ),
            ),
          ),
          _ModelPill(
            model: model,
            isBusy: isBusy,
            onTap: onSelectModel,
          ),
          IconButton(
            key: const Key('chat_server_toggle_button'),
            tooltip: isBusy
                ? l10n.serverCancelPreparation
                : status == EngineRuntimeStatus.ready
                ? l10n.serverStop
                : l10n.chatStartServer,
            onPressed: onToggleRuntime,
            icon: StatusDot(
              key: const Key('chat_server_status_badge'),
              color: dotColor,
              size: 9,
              pulsing: isBusy,
            ),
          ),
          IconButton(
            key: const Key('chat_open_history_button'),
            tooltip: l10n.drawerAllHistoryTooltip,
            onPressed: onOpenHistory,
            icon: const Icon(Icons.history_rounded, size: 21),
          ),
        ],
      ),
    );
  }
}

class _ModelPill extends StatelessWidget {
  const _ModelPill({
    required this.model,
    required this.isBusy,
    required this.onTap,
  });

  final ChatModelOption? model;
  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ClaudeRadius.pill),
      child: InkWell(
        key: const Key('chat_model_selector_button'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(ClaudeRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 14),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  model?.displayName ?? context.l10n.chatSelectModel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: context.inkSecondary,
                  ),
                ),
              ),
              Icon(Icons.expand_more_rounded, size: 15, color: context.inkTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
