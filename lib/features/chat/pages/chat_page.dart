import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';
import 'package:servllama/app/keyboard/keyboard_state.dart';
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
import 'package:servllama/features/chat/widgets/context_usage_bar.dart';
import 'package:servllama/features/chat/widgets/chat_empty_state.dart';
import 'package:servllama/features/chat/widgets/chat_engine_start_sheet.dart';
import 'package:servllama/features/chat/widgets/chat_message_list.dart';
import 'package:servllama/features/chat/widgets/chat_model_sheet.dart';
import 'package:servllama/features/downloads/pages/model_discovery_page.dart';
import 'package:servllama/features/server/pages/server_config_page.dart';
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

class _ChatViewState extends State<_ChatView>
    with WidgetsBindingObserver, KeyboardStateRestorer<_ChatView> {
  final GlobalKey<ChatComposerState> _composerKey =
      GlobalKey<ChatComposerState>();

  FocusNode? get _composerFocus => _composerKey.currentState?.focusNode;
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
      builder: (sheetContext) => Consumer<EngineRuntimeProvider>(
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
          Consumer3<
            EngineRuntimeProvider,
            ModelManagementProvider,
            DownloadProvider
          >(
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

  /// Every route out of the chat records the keyboard first and puts it back
  /// on return. Doing it in one place is the point: it was missed on two of
  /// these before, and that is how the keyboard started reappearing by itself.
  Future<void> _pushAndRestore(Route<void> route) async {
    rememberKeyboard();
    await Navigator.of(context).push(route);
    if (mounted) restoreKeyboard(focusNode: _composerFocus);
  }

  void _openDiscovery() {
    unawaited(
      _pushAndRestore(
        MaterialPageRoute<void>(builder: (_) => const ModelDiscoveryPage()),
      ),
    );
  }

  /// The composer sits next to send, so its button should open the engine
  /// and not the whole app's settings. A global preferences page is a
  /// plausible-sounding answer and a wrong one.
  void _openEngineSettings() {
    unawaited(
      _pushAndRestore(
        MaterialPageRoute<void>(builder: (_) => const ServerConfigPage()),
      ),
    );
  }

  void _showRuntimeError(EngineRuntimeProvider runtime) {
    final error = runtime.lastError;
    if (error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          RuntimeLabels.runtimeError(context.l10n, error, runtime.port),
        ),
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
        // The header and the composer are floating surfaces over the
        // transcript, so only the status bar and the home indicator are
        // real insets here. The transcript is free to run under both.
        bottom: false,
        child: AnimatedBuilder(
          animation: _scroll,
          builder: (context, _) => Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: isEmpty
                        ? ChatEmptyState(
                            status: runtime?.status ?? EngineRuntimeStatus.idle,
                            hasModels: context
                                .watch<ModelManagementProvider>()
                                .libraryModels
                                .isNotEmpty,
                            onStartServer: _startServer,
                            onSelectModel: _showModels,
                            onBrowseModels: () => _openDiscovery(),
                          )
                        : Stack(
                            children: [
                              DismissKeyboardOnTap(
                                child: ChatMessageListView(
                                  coordinator: _scroll,
                                  // The transcript runs right up under the
                                  // pills. The old padding reserved a full
                                  // fade's worth of dead space above the
                                  // first line, which read as an empty band
                                  // rather than as breathing room.
                                  topInset: _topRunway,
                                  bottomInset: _bottomRunway,
                                ),
                              ),
                              // The pills are opaque and painted after this
                              // band, so they stay crisp. The fade is here so
                              // text dissolves on its way up to them instead
                              // of being sliced by the top of the screen,
                              // which is exactly what happened without it.
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: _topFade,
                                child: IgnorePointer(
                                  child: _EdgeFade(
                                    alignment: Alignment.topCenter,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                height: _bottomFade,
                                child: IgnorePointer(
                                  child: _EdgeFade(alignment: Alignment.bottomCenter),
                                ),
                              ),
                            ],
                          ),
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
                          key: _composerKey,
                          controller: _input,
                          onSend: _send,
                          onStop: chat.cancelStreaming,
                          onPickImage: _pickImage,
                          onStartServer: _startServer,
                          onSelectModel: _showModels,
                          onOpenEngineSettings: _openEngineSettings,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // The pills float. Three opaque circles over the transcript is one thing;
// a full-width opaque strip above it is another, and the strip is what was
// cutting the first line in half.
Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _ChatTopBar(
                  onOpenSidebar: widget.onOpenSidebar,
                  isStealth: chat.isStealthMode,
                  onStealthChanged: chat.setStealthMode,
                  onNewChat: chat.createSession,
                  onSelectModel: _showModels,
                  onOpenHistory: widget.onOpenHistory ?? () {},
                ),
              ),
              if (!isEmpty)
                // Above the composer, not on it. It used to sit bottom-
                // right, which is precisely where the send button lives,
                // and the two fought over the same corner.
                Positioned(
                  right: ClaudeSpacing.lg,
                  bottom:
                      MediaQuery.viewInsetsOf(context).bottom +
                      MediaQuery.viewPaddingOf(context).bottom +
                      112,
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

/// Clearance above the first line.
///
/// Enough to clear the pills when the transcript is scrolled to its very
/// top, and no more: the pills are opaque circles, not a bar, so text is
/// free to run up behind them and between them.
const double _topRunway = 54;

/// The dissolve above the transcript. The pills overlap this band but are
/// drawn after it and are opaque, so they are unaffected.
const double _topFade = 54;

/// The composer is an opaque panel, so text genuinely has to leave the way
/// it came in. Runway and fade share a length: a line starts dissolving
/// exactly where the panel's shadow begins.
const double _bottomRunway = 46;
const double _bottomFade = 46;

/// A gradient that hands the canvas over to whatever is behind it.
///
/// Opaque at the edge it guards, transparent at the inner end. A line
/// crossing it loses contrast as it goes rather than losing half its glyphs,
/// which is the difference between a surface and a curtain.
class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final top = alignment == Alignment.topCenter;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: top ? Alignment.topCenter : Alignment.bottomCenter,
          end: top ? Alignment.bottomCenter : Alignment.topCenter,
          colors: [
            context.canvas,
            context.canvas.withAlpha(178),
            context.canvas.withAlpha(0),
          ],
          stops: const [0, 0.55, 1],
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
  // Only the home indicator has to be cleared. Padding out to a full `lg`
  // on top of it left the composer floating in the middle of the lower
  // third with dead canvas beneath it.
  return 4 + MediaQuery.viewPaddingOf(context).bottom;
}

/// Stealth toggle.
/// The top strip.
///
/// Three floating pills and nothing else. They sit on a surface of their own
/// rather than on a band with a rule under it, because the thing that makes
/// a header read as a layer is that it has an edge to float over — a hairline
/// across a canvas that is the same colour everywhere else only draws a
/// boundary the eye has to interpret.
///
/// The right pair is one pill split in two: new conversation, and the
/// overflow beside it that has no other home. Stealth went in there, along
/// with everything else that is configuration rather than conversation.
class _ChatTopBar extends StatelessWidget {
  const _ChatTopBar({
    required this.isStealth,
    required this.onStealthChanged,
    required this.onNewChat,
    required this.onSelectModel,
    required this.onOpenHistory,
    this.onOpenSidebar,
  });

  final bool isStealth;
  final ValueChanged<bool> onStealthChanged;
  final VoidCallback onNewChat;
  final VoidCallback onSelectModel;
  final VoidCallback onOpenHistory;
  final VoidCallback? onOpenSidebar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ClaudeSpacing.md,
        ClaudeSpacing.sm,
        ClaudeSpacing.md,
        ClaudeSpacing.xs,
      ),
      child: Row(
        children: [
          _FloatPill(
            keyValue: 'chat_open_sidebar_button',
            tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
            onPressed: onOpenSidebar,
            child: ClaudeIcon(ClaudeIcons.menu, size: 23, color: context.ink),
          ),
          const Spacer(),
          _FloatPill(
            keyValue: 'chat_new_chat_button',
            tooltip: context.l10n.chatNewConversation,
            onPressed: onNewChat,
            child: ClaudeIcon(
              ClaudeIcons.newChat,
              size: 19,
              color: context.ink,
            ),
          ),
          const SizedBox(width: 6),
          _FloatPill(
            keyValue: 'chat_more_button',
            tooltip: context.l10n.chatMore,
            onPressed: () => _showOverflow(context),
            child: ClaudeIcon(ClaudeIcons.more, size: 23, color: context.ink),
          ),
        ],
      ),
    );
  }

  Future<void> _showOverflow(BuildContext context) async {
    final chat = context.read<ChatProvider>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('chat_stealth_tile'),
              leading: ClaudeIcon(
                ClaudeIcons.ghost,
                size: 20,
                color: isStealth ? context.accent : context.inkSecondary,
              ),
              title: Text(
                isStealth
                    ? context.l10n.chatStealthOn
                    : context.l10n.chatStealthOff,
              ),
              trailing: Switch(
                value: isStealth,
                onChanged: (value) {
                  onStealthChanged(value);
                  Navigator.of(sheetContext).pop();
                },
              ),
              onTap: () {
                onStealthChanged(!isStealth);
                Navigator.of(sheetContext).pop();
              },
            ),
            ListTile(
              key: const Key('chat_model_tile'),
              leading: ClaudeIcon(
                ClaudeIcons.chip,
                size: 20,
                color: context.inkSecondary,
              ),
              title: Text(context.l10n.chatSelectModel),
              // Null rather than an empty Text. A ListTile only collapses to
              // one line when the subtitle is absent; an empty string still
              // counts as present, so the row kept two lines of reserved
              // height and the title rode high above the centre.
              subtitle: (chat.currentModel?.displayName ?? '').trim().isEmpty
                  ? null
                  : Text(
                      chat.currentModel!.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              onTap: () => _closeThen(sheetContext, onSelectModel),
            ),
            ListTile(
              key: const Key('chat_context_tile'),
              leading: ClaudeIcon(
                ClaudeIcons.layers,
                size: 20,
                color: context.inkSecondary,
              ),
              title: Text(context.l10n.chatContextTitle),
              subtitle: Text(
                _contextLine(context, chat),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ListTile(
              key: const Key('chat_history_tile'),
              leading: ClaudeIcon(
                ClaudeIcons.archive,
                size: 20,
                color: context.inkSecondary,
              ),
              title: Text(context.l10n.drawerAllHistoryTooltip),
              onTap: () => _closeThen(sheetContext, onOpenHistory),
            ),
          ],
        ),
      ),
    );
  }

  /// Dismisses this sheet, then runs [action].
  ///
  /// Deferred rather than immediate: the sheet owns the navigator until its
  /// own pop animation finishes, and pushing a second route on top of a
  /// sheet still animating out puts two surfaces in one transition.
  /// "12.4k / 128k" when the engine told us its window, and an honest
  /// "unknown" when it did not.
  static String _contextLine(BuildContext context, ChatProvider chat) {
    final window = context.read<EngineRuntimeProvider?>()?.contextWindow;
    if (window == null || window <= 0) return context.l10n.chatContextUnknown;
    final used = estimateTokens(chat.visibleMessages);
    return context.l10n.chatContextValue(
      formatTokenCount(used),
      formatTokenCount(window),
    );
  }

  static void _closeThen(BuildContext sheetContext, VoidCallback action) {
    Navigator.of(sheetContext).pop();
    Future<void>.delayed(const Duration(milliseconds: 200), action);
  }
}

/// A control that floats on the canvas instead of being stamped into a bar.
///
/// The soft fill plus the hairline is what separates it from the transcript
/// underneath; without the fill, a pill reads as a floating outline with no
/// material, and with it the header stops competing with the messages for
/// attention.
/// The header pills are a touch target, not decoration: 42 was below the
/// 48dp guideline and felt cramped against the icons inside them.
const double _pillSize = 50;

class _FloatPill extends StatelessWidget {
  const _FloatPill({
    required this.tooltip,
    required this.onPressed,
    required this.child,
    this.keyValue,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;
  final String? keyValue;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: context.surface,
          borderRadius: BorderRadius.circular(ClaudeRadius.pill),
          child: InkWell(
            key: keyValue == null ? null : Key(keyValue!),
            onTap: onPressed,
            customBorder: const StadiumBorder(),
            child: Container(
              width: _pillSize,
              height: _pillSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ClaudeRadius.pill),
                border: Border.all(color: context.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(12),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stealth toggle.
///
/// Sits at the trailing corner because it is a promise about what will
/// happen to this conversation, and promises live where the eye already
/// rests after reading. When it is on the whole bar takes a faint tint, so
/// the mode is visible for the rest of the conversation rather than only at
/// the moment it was switched.
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
/// A bare round control. No label, no background until it is pressed.
