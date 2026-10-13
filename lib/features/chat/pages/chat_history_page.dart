import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';
import 'package:servllama/app/widgets/page_scaffold.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/chat/widgets/chat_session_list.dart';
import 'package:servllama/features/chat/widgets/chat_session_search_field.dart';
import 'package:servllama/l10n/l10n.dart';

/// Full-screen conversation history.
///
/// Deliberately reuses [ChatSessionList] rather than keeping a second
/// implementation: the sidebar and this page showed the same data in two
/// different visual languages before, which is exactly the kind of drift a
/// redesign is supposed to end.
class ChatHistoryPage extends StatelessWidget {
  const ChatHistoryPage({super.key, this.onSessionOpened});

  final VoidCallback? onSessionOpened;

  Future<void> _openSession(
    BuildContext context,
    ChatProvider provider,
    String sessionId,
  ) async {
    unawaited(provider.switchSession(sessionId));
    Navigator.of(context).pop();
    onSessionOpened?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PageScaffold(
      title: l10n.chatHistoryTitle,
      maxWidth: 560,
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ClaudeSpacing.lg,
              ClaudeSpacing.md,
              ClaudeSpacing.lg,
              ClaudeSpacing.md,
            ),
            child: const ChatSessionSearchField(
              key: Key('history_page_search_box'),
              fieldKey: Key('history_page_search_input'),
            ),
          ),
          Divider(height: 1, color: context.border),
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, provider, _) {
                // The page owns navigation: tapping a row must close this
                // route rather than just switching the transcript behind it.
                //
                // Deliberately not wrapped in a VelaAnchor: inside this page's
                // ListView the row anchor's render object resolves to a sliver,
                // which has no rect for a menu to hang off, and the menu's
                // route never built. No anchor means showSessionActions falls
                // back to the sheet, which is what this page used before.
                return ChatSessionList(
                  itemKeyPrefix: 'history_session_item',
                  menuKeyPrefix: 'history_session_menu',
                  onSessionOpened: () {},
                  onSessionSelected: (sessionId) =>
                      _openSession(context, provider, sessionId),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
