import 'package:flutter/material.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';
import 'package:servllama/app/widgets/brand_mark.dart';
import 'package:servllama/app/widgets/claude_icons.dart';
import 'package:servllama/core/models/engine_runtime_state.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/l10n/l10n.dart';

/// The first-run hero shown above an empty transcript.
///
/// It states the one thing blocking the user and offers exactly one button
/// for it. A stack of options here reads as a settings screen; the job is to
/// get to a first message.
class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({
    super.key,
    required this.status,
    required this.hasModels,
    required this.onStartServer,
    required this.onSelectModel,
    required this.onBrowseModels,
  });

  final EngineRuntimeStatus status;
  final bool hasModels;
  final VoidCallback onStartServer;
  final VoidCallback onSelectModel;
  final VoidCallback onBrowseModels;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layout = _EmptyLayout.resolve(
      l10n,
      status: status,
      hasModels: hasModels,
      onStartServer: onStartServer,
      onSelectModel: onSelectModel,
      onBrowseModels: onBrowseModels,
    );
    final isBusy =
        status == EngineRuntimeStatus.preparing ||
        status == EngineRuntimeStatus.stopping;

    return LayoutBuilder(
      builder: (context, constraints) {
        // On short screens the hero must not push the composer off-screen, so
        // it yields vertical space instead of scaling the type down forever.
        final compact = constraints.maxHeight < 420;
        return SingleChildScrollView(
          // Biased below centre on purpose. Dead centre reads as a splash
          // screen; a third of the way down reads as a page you are about
          // to type into, which is what it is.
          padding: EdgeInsets.fromLTRB(
            ClaudeSpacing.lg,
            compact ? 72 : 132,
            ClaudeSpacing.lg,
            ClaudeSpacing.xl,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ClaudeSpacing.readingWidth,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: BrandMark(
                    key: const Key('chat_empty_state_logo'),
                    size: compact ? 34 : 44,
                    color: context.accent.withAlpha(compact ? 200 : 255),
                  ),
                ),
                SizedBox(height: compact ? ClaudeSpacing.lg : ClaudeSpacing.xl),
                Text(
                  layout.title,
                  textAlign: TextAlign.center,
                  style:
                      (compact
                              ? Theme.of(context).textTheme.headlineSmall
                              : Theme.of(context).textTheme.displaySmall)
                          ?.copyWith(color: context.ink),
                ),
                const SizedBox(height: ClaudeSpacing.sm),
                Text(
                  layout.subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.inkSecondary,
                    height: 1.6,
                  ),
                ),
                SizedBox(height: compact ? ClaudeSpacing.lg : ClaudeSpacing.xl),
                Center(
                  child: FilledButton.icon(
                    key: const Key('chat_empty_state_action_button'),
                    onPressed: isBusy ? null : layout.action,
                    icon: ClaudeIcons.render(
                      layout.actionIcon,
                      size: 18,
                      color: ClaudeColors.onAccent,
                    ),
                    label: Text(layout.actionLabel),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: ClaudeSpacing.xl,
                      ),
                    ),
                  ),
                ),
                if (!hasModels) ...[
                  const SizedBox(height: ClaudeSpacing.sm),
                  TextButton(
                    key: const Key('chat_empty_discover_button'),
                    onPressed: onBrowseModels,
                    child: Text(l10n.sidebarBrowseModels),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Which single blocker the hero describes, derived from the runtime state.
class _EmptyLayout {
  const _EmptyLayout({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.actionIcon,
    required this.action,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback action;

  static _EmptyLayout resolve(
    AppLocalizations l10n, {
    required EngineRuntimeStatus status,
    required bool hasModels,
    required VoidCallback onStartServer,
    required VoidCallback onSelectModel,
    required VoidCallback onBrowseModels,
  }) {
    if (!hasModels) {
      return _EmptyLayout(
        title: l10n.chatEmptyTitle,
        subtitle: l10n.chatEmptyNoModelsDescription,
        actionLabel: l10n.sidebarBrowseModels,
        actionIcon: ClaudeIcons.download,
        action: onBrowseModels,
      );
    }

    final running =
        status == EngineRuntimeStatus.ready ||
        status == EngineRuntimeStatus.preparing;

    if (!running) {
      return _EmptyLayout(
        title: l10n.chatHeroTitle,
        subtitle: l10n.chatHeroDescriptionStartServer,
        actionLabel: l10n.chatStartServer,
        actionIcon: ClaudeIcons.play,
        action: onStartServer,
      );
    }

    return _EmptyLayout(
      title: l10n.chatEmptyTitle,
      subtitle: l10n.chatHeroDescriptionSelectModel,
      actionLabel: l10n.chatSelectModel,
      actionIcon: ClaudeIcons.chip,
      action: onSelectModel,
    );
  }
}
