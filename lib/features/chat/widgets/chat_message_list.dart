import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';
import 'package:servllama/features/chat/controllers/chat_scroll_coordinator.dart';
import 'package:servllama/features/chat/controllers/streaming_chat_message_notifier.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/widgets/chat_message_sheets.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/chat/widgets/chat_message_item.dart';

/// The transcript.
///
/// Every message is capped at a reading measure and centred, so long code
/// blocks and short replies share the same optical left edge instead of the
/// user bubble and the answer fighting for the same column.
class ChatMessageListView extends StatefulWidget {
  const ChatMessageListView({super.key, required this.coordinator});

  final ChatScrollCoordinator coordinator;

  @override
  State<ChatMessageListView> createState() => _ChatMessageListViewState();
}

class _ChatMessageListViewState extends State<ChatMessageListView> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    // Bumping the revision keeps the list identity stable while streaming so
    // Flutter doesn't tear down and rebuild every row on each token.
    final revision = provider.visibleMessagesRevision;
    final messages = provider.visibleMessages;
    final conversationKey = provider.selectedSession?.id ?? 'draft';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.coordinator.handleConversationBodyCommitted(conversationKey);
      }
    });

    if (messages.isEmpty) return const SizedBox.shrink();

    return NotificationListener<ScrollNotification>(
      onNotification: widget.coordinator.handleMessageScrollNotification,
      child: Scrollbar(
        controller: widget.coordinator.scrollController,
        child: ListView.builder(
          key: const ValueKey('chat_message_list'),
          controller: widget.coordinator.scrollController,
          padding: const EdgeInsets.only(bottom: ClaudeSpacing.lg),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final stream = provider.streamingMessages.listenableFor(
              message.id,
            );
            if (stream != null) {
              return ValueListenableBuilder<StreamingChatMessageData>(
                valueListenable: stream,
                builder: (context, data, _) => _buildItem(
                  provider,
                  data.message,
                  revision,
                  isStreaming: data.isStreaming,
                ),
              );
            }
            return _buildItem(provider, message, revision);
          },
        ),
      ),
    );
  }

  Future<void> _editMessage(
    ChatProvider provider,
    ChatMessageRecord message,
  ) async {
    final edited = await showEditMessageSheet(
      context: context,
      initialValue: message.content,
    );
    if (edited == null || !mounted) return;
    await provider.editMessage(messageId: message.id, newContent: edited);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.chatMessageUpdated)),
    );
  }

  Widget _buildItem(
    ChatProvider provider,
    ChatMessageRecord message,
    int revision, {
    bool isStreaming = false,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: ClaudeSpacing.readingWidth),
        child: ChatMessageItem(
          message: message,
          isStreaming: isStreaming,
          canManage: provider.canManageMessages,
          onCopy: () async {
            await Clipboard.setData(ClipboardData(text: message.content));
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.chatMessageCopied)),
            );
          },
          onRegenerate: () => provider.regenerateFromMessage(message.id),
          onEdit: () => _editMessage(provider, message),
          onDelete: () => provider.deleteMessage(message.id),
        ),
      ),
    );
  }
}

/// Floating "jump to latest" affordance. Only appears once the user has
/// scrolled away from the bottom, so it never occupies the resting layout.
class JumpToLatestButton extends StatelessWidget {
  const JumpToLatestButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surface,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black.withAlpha(40),
      child: InkWell(
        key: const Key('chat_jump_to_latest_button'),
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(Icons.arrow_downward_rounded, size: 18, color: context.ink),
        ),
      ),
    );
  }
}
