import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/sheet/vela_menu.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/chat/widgets/chat_session_actions.dart';
import 'package:servllama/l10n/l10n.dart';

class ChatSessionDrawerSection extends StatelessWidget {
  const ChatSessionDrawerSection({
    super.key,
    required this.presentationContext,
    required this.isChatSelected,
    required this.onOpenChat,
  });

  final BuildContext presentationContext;
  final bool isChatSelected;
  final FutureOr<void> Function() onOpenChat;

  Future<void> _openSession(ChatProvider provider, String sessionId) async {
    unawaited(Future<void>.sync(onOpenChat));
    await provider.switchSession(sessionId, staged: true);
  }

  Future<void> _showSessionActions(
    BuildContext context,
    BuildContext anchor,
    ChatSessionRecord session,
  ) async {
    await ChatSessionActions.showSessionActions(
      context: context,
      presentationContext: presentationContext,
      anchorContext: anchor,
      session: session,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final l10n = context.l10n;
        final filteredSessions = provider.filteredSessions;
        final isQueryEmpty = provider.sessionQuery.trim().isEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: provider.isLoading && provider.sessions.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : provider.sessions.isEmpty || filteredSessions.isEmpty
                  ? Center(
                      child: Text(
                        isQueryEmpty
                            ? l10n.chatSessionEmpty
                            : l10n.chatSessionNotFound,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
                      itemCount: filteredSessions.length,
                      itemBuilder: (context, index) {
                        final session = filteredSessions[index];
                        final isSelected =
                            isChatSelected &&
                            provider.selectedSession?.id == session.id;
                        final selectedBackgroundColor = colorScheme.primary
                            .withAlpha(24);
                        final selectedForegroundColor = colorScheme.primary;
                        final defaultForegroundColor = colorScheme.onSurface;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          // The row is itself an anchor, so the long-press
                          // menu hangs off the conversation it acts on. Without
                          // this the lookup found nothing and the menu simply
                          // did not open.
                          child: VelaAnchor(
                            // A context *inside* the anchor. The enclosing
                            // build method's context sits above it, so
                            // VelaAnchor.of() found nothing and the menu
                            // silently did not open.
                            child: Builder(
                              builder: (rowContext) => Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: Key('chat_session_item_${session.id}'),
                              borderRadius: BorderRadius.circular(14),
                              onTap: provider.canManageSessions
                                  ? () => _openSession(provider, session.id)
                                  : null,
                              // Long press has no button of its own, so the
                              // row is the anchor. The three-dot button is
                              // the one that gets used.
                              onLongPress: provider.canManageSessions
                                  ? () => _showSessionActions(
                                      context,
                                      rowContext,
                                      session,
                                    )
                                  : null,
                              child: Ink(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? selectedBackgroundColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    12,
                                    12,
                                    11,
                                  ),
                                  child: Text(
                                    session.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: isSelected
                                          ? selectedForegroundColor
                                          : defaultForegroundColor,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
