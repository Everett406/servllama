import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';
import 'package:servllama/app/widgets/brand_mark.dart';
import 'package:servllama/app/widgets/claude_icons.dart';
import 'package:servllama/app/widgets/shell_bits.dart';
import 'package:servllama/core/models/engine_runtime_state.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/features/chat/pages/chat_history_page.dart';
import 'package:servllama/features/chat/pages/chat_page.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/chat/widgets/chat_session_list.dart';
import 'package:servllama/features/chat/widgets/chat_session_search_field.dart';
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
                  _SidebarHeader(controller: _sidebar),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      ClaudeSpacing.md,
                      4,
                      ClaudeSpacing.md,
                      ClaudeSpacing.md,
                    ),
                    child: _NewChatButton(
                      onPressed: () {
                        _closeSidebarIfOverlay();
                        chat?.createSession();
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ClaudeSpacing.md,
                    ),
                    child: ChatSessionSearchField(
                      key: const Key('drawer_search_box'),
                      fieldKey: const Key('drawer_search_input'),
                      hintText: context.l10n.chatSearchHint,
                      onOpenHistory: () {
                        _closeSidebarIfOverlay();
                        _pushHistory();
                      },
                    ),
                  ),
                  Expanded(
                    child: ChatSessionList(
                      onSessionOpened: _closeSidebarIfOverlay,
                    ),
                  ),
                  _SidebarFooter(
                    runtime: runtime,
                    activeDownloads: downloads?.activeTaskCount ?? 0,
                    onOpenServer: () => _push(const ServerPage()),
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
  const _SidebarHeader({required this.controller});

  final PushSidebarController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ClaudeSpacing.lg,
        ClaudeSpacing.lg,
        ClaudeSpacing.lg,
        ClaudeSpacing.sm,
      ),
      child: Row(
        children: [
          const Expanded(child: BrandLockup(size: 20)),
          // No close control. On a phone the drawer is dismissed by
          // swiping, tapping the scrim, or picking something — a lone
          // chevron in the corner adds a third way to do one thing and
          // takes the eye's attention off the list.
          if (controller.isDrawerMode)
            ClaudeIcon(
              ClaudeIcons.slash,
              size: 14,
              color: context.inkTertiary.withAlpha(90),
            ),
        ],
      ),
    );
  }
}

class _NewChatButton extends StatelessWidget {
  const _NewChatButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: OutlinedButton.icon(
        key: const Key('sidebar_new_chat_button'),
        onPressed: onPressed,
        icon: ClaudeIcon(ClaudeIcons.plus, size: 18),
        label: Text(context.l10n.chatNewConversation),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          backgroundColor: context.surface,
          side: BorderSide(color: context.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ClaudeRadius.md),
          ),
          padding: const EdgeInsets.symmetric(horizontal: ClaudeSpacing.md),
        ),
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({
    required this.runtime,
    required this.activeDownloads,
    required this.onOpenServer,
    required this.onOpenModels,
    required this.onOpenSettings,
  });

  final EngineRuntimeProvider? runtime;
  final int activeDownloads;
  final VoidCallback onOpenServer;
  final VoidCallback onOpenModels;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ClaudeSpacing.md,
          ClaudeSpacing.sm,
          ClaudeSpacing.md,
          ClaudeSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The engine, then settings. Model library and About moved into
            // settings: they are configuration, and a sidebar that only ever
            // answers "is it running and where do I change things" is a
            // sidebar anyone can hold in their head.
            _EngineStrip(runtime: runtime, onTap: onOpenServer),
            const SizedBox(height: ClaudeSpacing.xs),
            _SidebarNavRow(
              keyValue: 'sidebar_models_row',
              icon: ClaudeIcons.chip,
              label: l10n.modelLibraryTitle,
              badge: activeDownloads == 0 ? null : '$activeDownloads',
              onTap: onOpenModels,
            ),
            _SidebarNavRow(
              keyValue: 'drawer_settings_action',
              icon: ClaudeIcons.sliders,
              label: l10n.drawerSettings,
              onTap: onOpenSettings,
            ),
          ],
        ),
      ),
    );
  }
}

/// Runtime summary strip. Doubles as the entry point to the server page
/// because it is the one place that always answers "is anything running".
class _EngineStrip extends StatelessWidget {
  const _EngineStrip({required this.runtime, required this.onTap});

  final EngineRuntimeProvider? runtime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = runtime?.status ?? EngineRuntimeStatus.idle;
    final (dotColor, label) = switch (status) {
      EngineRuntimeStatus.ready => (
        context.okText,
        context.l10n.serverStatusRunning,
      ),
      EngineRuntimeStatus.preparing => (
        context.accent,
        context.l10n.serverStatusPreparing,
      ),
      EngineRuntimeStatus.stopping => (
        context.accent,
        context.l10n.serverStatusStopping,
      ),
      EngineRuntimeStatus.error => (
        context.dangerText,
        context.l10n.serverStatusError,
      ),
      EngineRuntimeStatus.idle => (
        context.inkTertiary,
        context.l10n.sidebarEngineIdle,
      ),
    };

    final engineName = runtime?.activeEngine.displayName ?? 'llama.cpp';
    final modelName = runtime?.activeModelName;
    final detail = modelName == null || modelName.isEmpty
        ? engineName
        : '$engineName · $modelName';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ClaudeRadius.md),
      child: InkWell(
        key: const Key('drawer_server_action'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(ClaudeRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ClaudeSpacing.sm,
            vertical: ClaudeSpacing.sm,
          ),
          child: Row(
            children: [
              StatusDot(
                key: const Key('sidebar_engine_status_badge'),
                color: dotColor,
                size: 7,
                pulsing:
                    status == EngineRuntimeStatus.preparing ||
                    status == EngineRuntimeStatus.stopping,
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: dotColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarNavRow extends StatelessWidget {
  const _SidebarNavRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.keyValue,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? keyValue;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ClaudeRadius.sm),
      child: InkWell(
        key: keyValue == null ? null : Key(keyValue!),
        onTap: onTap,
        borderRadius: BorderRadius.circular(ClaudeRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ClaudeSpacing.sm,
            vertical: 9,
          ),
          child: Row(
            children: [
              ClaudeIcons.render(icon, size: 18, color: context.inkSecondary),
              const SizedBox(width: ClaudeSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: context.ink),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: context.accent,
                    borderRadius: BorderRadius.circular(ClaudeRadius.pill),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: ClaudeColors.onAccent,
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
