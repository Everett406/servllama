import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';
import 'package:servllama/app/widgets/brand_mark.dart';
import 'package:servllama/app/widgets/claude_icons.dart';
import 'package:servllama/core/models/engine_runtime_state.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/features/chat/pages/chat_history_page.dart';
import 'package:servllama/features/chat/pages/chat_page.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/chat/widgets/chat_session_list.dart';
import 'package:servllama/features/downloads/providers/download_provider.dart';
import 'package:servllama/features/server/pages/model_management_page.dart';
import 'package:servllama/features/server/pages/server_page.dart';
import 'package:servllama/features/settings/pages/settings_page.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/push_sidebar.dart';

/// The application shell: a persistent sidebar on wide screens, an overlay
/// on phones, and the chat canvas as the single child.
///
/// The sidebar deliberately stays chrome-free — no boxed "menu tiles", no
/// nested cards. Warm neutrals plus a single accent only reads as calm if
/// the structure comes from type and whitespace instead of borders.
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  final PushSidebarController _sidebar = PushSidebarController();
  double _sidebarWidth = 272;

  void _closeSidebarIfOverlay() {
    if (_sidebar.isDrawerMode && _sidebar.isOpen) {
      unawaited(_sidebar.close());
    }
  }

  Future<void> _openSidebar() => _sidebar.open();

  Future<void> _push(Widget page) async {
    final navigator = Navigator.of(context);
    await navigator.push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _pushHistory() async {
    final navigator = Navigator.of(context);
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ChatHistoryPage(onSessionOpened: _closeSidebarIfOverlay),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final runtime = context.watch<EngineRuntimeProvider?>();
    final downloads = context.watch<DownloadProvider?>();
    final chat = context.watch<ChatProvider?>();

    return _DownloadCompletedListener(
      child: Scaffold(
        body: PushSidebar(
          controller: _sidebar,
          semanticLabel: context.l10n.appTitle,
          embeddedSidebarWidth: _sidebarWidth,
          onSidebarWidthChanged: (w) => setState(() => _sidebarWidth = w),
          maxScrimOpacity: 0.18,
          drawer: DecoratedBox(
            decoration: BoxDecoration(
              color: context.sidebar,
              border: Border(right: BorderSide(color: context.border)),
            ),
            child: SafeArea(
              right: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SidebarHeader(
                    controller: _sidebar,
                    runtime: runtime,
                    onNewChat: () {
                      _closeSidebarIfOverlay();
                      chat?.createSession();
                    },
                    onEngineTap: () => _push(const ServerPage()),
                  ),
                  const SizedBox(height: ClaudeSpacing.sm),
                  Expanded(
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black,
                          Colors.black,
                          Colors.transparent,
                        ],
                        stops: [0, 0.045, 0.955, 1],
                      ).createShader(bounds),
                      blendMode: BlendMode.dstIn,
                      child: ChatSessionList(
                        onSessionOpened: _closeSidebarIfOverlay,
                      ),
                    ),
                  ),
                  _SidebarFooter(
                    activeDownloads: downloads?.activeTaskCount ?? 0,
                    onSearch: () {
                      _closeSidebarIfOverlay();
                      _pushHistory();
                    },
                    onOpenModels: () => _push(const ModelManagementPage()),
                    onOpenSettings: () => _push(const SettingsPage()),
                  ),
                ],
              ),
            ),
          ),
          child: ChatPage(
            onOpenSidebar: _openSidebar,
            onOpenHistory: _pushHistory,
          ),
        ),
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({
    required this.controller,
    required this.runtime,
    required this.onNewChat,
    required this.onEngineTap,
  });

  final PushSidebarController controller;
  final EngineRuntimeProvider? runtime;
  final VoidCallback onNewChat;
  final VoidCallback onEngineTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ClaudeSpacing.lg,
        ClaudeSpacing.xl,
        ClaudeSpacing.lg,
        ClaudeSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: BrandLockup(size: 30)),
              // An icon pill, not a full-width labelled row. "New
              // conversation" spelled out across the drawer was a bar of text
              // for something the plus already says, and it cost the list a
              // whole row of height.
              VelaIconPill(
                key: const Key('sidebar_new_chat_button'),
                icon: ClaudeIcons.plus,
                tooltip: context.l10n.chatNewConversation,
                onPressed: onNewChat,
              ),
              // No close control. On a phone the drawer is dismissed by
              // swiping, tapping the scrim, or picking something — a lone
              // chevron in the corner adds a third way to do one thing and
              // takes the eye's attention off the list.
              if (controller.isDrawerMode) ...[
                const SizedBox(width: ClaudeSpacing.xs),
                ClaudeIcon(
                  ClaudeIcons.slash,
                  size: 14,
                  color: context.inkTertiary.withAlpha(90),
                ),
              ],
            ],
          ),
          const SizedBox(height: ClaudeSpacing.sm),
          _EngineStatusLine(runtime: runtime, onTap: onEngineTap),
        ],
      ),
    );
  }
}

/// The engine's state, one tappable line, under the title.
///
/// It was at the bottom of the drawer, under three labelled rows, which made
/// it read as a status bar belonging to something else. The header is where
/// the chat page puts the same information.
class _EngineStatusLine extends StatelessWidget {
  const _EngineStatusLine({required this.runtime, required this.onTap});

  final EngineRuntimeProvider? runtime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = runtime?.status ?? EngineRuntimeStatus.idle;
    final running = (runtime?.isRunning ?? false) && state == EngineRuntimeStatus.ready;
    final busy = runtime?.isBusy ?? false;
    final String label = running
        ? context.l10n.serverStatusRunning
        : busy
        ? context.l10n.engineMenuRunning
        : context.l10n.sidebarEngineIdle;
    final Color color = running
        ? context.okText
        : busy
        ? context.accent
        : context.inkTertiary;

    return InkWell(
      key: const Key('sidebar_engine_status'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(ClaudeRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: ClaudeSpacing.sm),
            Expanded(
              child: Text(
                running
                    ? '$label \u00b7 ${runtime?.activeEngine.displayName ?? ''}'
                    : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A round icon button. The chat header's pills and the drawer's two.
class VelaIconPill extends StatelessWidget {
  const VelaIconPill({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 34,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final button = Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: context.surface,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: ClaudeIcon(icon, size: size * 0.46, color: context.ink),
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({
    required this.activeDownloads,
    required this.onSearch,
    required this.onOpenModels,
    required this.onOpenSettings,
  });

  final int activeDownloads;
  final VoidCallback onSearch;
  final VoidCallback onOpenModels;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // No top rule. The list above already dissolves into this edge; a line
    // would cut across that instead of meeting it.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ClaudeSpacing.md,
        ClaudeSpacing.sm,
        ClaudeSpacing.md,
        ClaudeSpacing.md,
      ),
      child: Row(
        children: [
          // A wide, quiet pill on the left: the thumb reaches the bottom of
          // the screen, and searching is the thing done most often there.
          Expanded(
            child: InkWell(
              key: const Key('sidebar_search_button'),
              onTap: onSearch,
              borderRadius: BorderRadius.circular(ClaudeRadius.pill),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(
                  horizontal: ClaudeSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: context.surfaceSunken,
                  borderRadius: BorderRadius.circular(ClaudeRadius.pill),
                  border: Border.all(color: context.border),
                ),
                child: Row(
                  children: [
                    ClaudeIcon(
                      ClaudeIcons.search,
                      size: 15,
                      color: context.inkTertiary,
                    ),
                    const SizedBox(width: ClaudeSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.chatSearchHint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.inkTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: ClaudeSpacing.sm),
          _FooterPill(
            keyValue: 'sidebar_models_row',
            icon: ClaudeIcons.chip,
            tooltip: l10n.modelLibraryTitle,
            badge: activeDownloads == 0 ? null : '$activeDownloads',
            onTap: onOpenModels,
          ),
          const SizedBox(width: ClaudeSpacing.xs),
          _FooterPill(
            keyValue: 'drawer_settings_action',
            icon: ClaudeIcons.sliders,
            tooltip: l10n.drawerSettings,
            onTap: onOpenSettings,
          ),
        ],
      ),
    );
  }
}

/// An icon-only button for the drawer's bottom row. These two destinations
/// are rare; spelling them out spent two of the list's rows on them.
class _FooterPill extends StatelessWidget {
  const _FooterPill({
    required this.keyValue,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badge,
  });

  final String keyValue;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            KeyedSubtree(
              key: Key(keyValue),
              child: VelaIconPill(icon: icon, size: 40, onPressed: onTap),
            ),
            if (badge != null)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: context.accent,
                    borderRadius: BorderRadius.circular(ClaudeRadius.pill),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bridges the kernel's `onDownloadCompleted` hook to a snackbar. Lives here
/// rather than in the provider because the kernel must not know about
/// ScaffoldMessenger.
class _DownloadCompletedListener extends StatefulWidget {
  const _DownloadCompletedListener({required this.child});

  final Widget child;

  @override
  State<_DownloadCompletedListener> createState() =>
      _DownloadCompletedListenerState();
}

class _DownloadCompletedListenerState
    extends State<_DownloadCompletedListener> {
  DownloadProvider? _downloads;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final downloads = context.read<DownloadProvider?>();
    if (identical(_downloads, downloads)) return;
    _unbind();
    _downloads = downloads;
    _downloads?.onDownloadCompleted = _showCompleted;
  }

  void _showCompleted(String fileName) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(context.l10n.downloadCompleted(fileName))),
    );
  }

  void _unbind() {
    if (_downloads?.onDownloadCompleted == _showCompleted) {
      _downloads?.onDownloadCompleted = null;
    }
  }

  @override
  void dispose() {
    _unbind();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
