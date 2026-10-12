import 'package:flutter/foundation.dart';
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
import 'package:servllama/features/chat/widgets/token_stats.dart';

/// The transcript.
///
/// Every message is capped at a reading measure and centred, so long code
/// blocks and short replies share the same optical left edge instead of the
/// user bubble and the answer fighting for the same column.
class ChatMessageListView extends StatefulWidget {
  const ChatMessageListView({
    super.key,
    required this.coordinator,
    this.topInset = 0,
    this.bottomInset = 0,
  });

  final ChatScrollCoordinator coordinator;

  /// Clearance for the surfaces that float over the transcript. Without it
  /// the first and last lines can never scroll fully into the open area.
  final double topInset;
  final double bottomInset;

  @override
  State<ChatMessageListView> createState() => _ChatMessageListViewState();
}

class _ChatMessageListViewState extends State<ChatMessageListView> {
  /// One notifier reused across rows; its value is replaced at the top of
  /// each streaming rebuild. Only one sheet can be open at a time, so a
  /// shared handle is enough and avoids allocating one per row.
  final ValueNotifier<String> _liveReasoning = ValueNotifier<String>('');

  @override
  void dispose() {
    _liveReasoning.dispose();
    super.dispose();
  }

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
          padding: EdgeInsets.only(
            top: widget.topInset,
            bottom: widget.bottomInset + ClaudeSpacing.sm,
          ),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            // Thinking ran between the prompt going out and the answer
            // landing. Both are stamped on the stored message, so a
            // conversation reopened tomorrow still reports a real span.
            final promptedAt = _promptedBefore(messages, index);
            final stream = provider.streamingMessages.listenableFor(message.id);
            if (stream != null) {
              return ValueListenableBuilder<StreamingChatMessageData>(
                valueListenable: stream,
                builder: (context, data, _) {
                  TokenStats.observe(
                    data.message.id,
                    data.message.content,
                    isStreaming: data.isStreaming,
                  );
                  // A projection of the stream, so the thought sheet can
                  // rebuild on reasoning without knowing about the message
                  // record wrapper.
                  _liveReasoning.value = data.message.reasoningContent ?? '';
                  return _buildItem(
                    provider,
                    data.message,
                    revision,
                    isStreaming: data.isStreaming,
                    promptedAt: promptedAt,
                    stream: stream,
                    liveReasoning: _liveReasoning,
                  );
                },
              );
            }
            return _buildItem(
              provider,
              message,
              revision,
              promptedAt: promptedAt,
            );
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.chatMessageUpdated)));
  }

  /// The most recent prompt before [index], or null if there isn't one.
  static DateTime? _promptedBefore(
    List<ChatMessageRecord> messages,
    int index,
  ) {
    for (var i = index - 1; i >= 0; i -= 1) {
      if (messages[i].role == ChatRole.user) return messages[i].createdAt;
    }
    return null;
  }

  Widget _buildItem(
    ChatProvider provider,
    ChatMessageRecord message,
    int revision, {
    bool isStreaming = false,
    DateTime? promptedAt,
    ValueListenable<StreamingChatMessageData>? stream,
    ValueListenable<String>? liveReasoning,
  }) {
    return ChatMessageRow(
      child: ChatMessageItem(
        message: message,
        isStreaming: isStreaming,
        promptedAt: promptedAt,
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
    );
  }
}

/// One turn in the transcript, inside the reading measure.
///
/// [Center] used to do two jobs here: capping the measure and centring the
/// result. A message item is a Column that sizes itself to its widest child,
/// so a long turn filled the measure and happened to look right-aligned,
/// while a short one came out narrow and got parked in the middle. Pinning
/// the child to the full measure hands alignment back to the item's own
/// cross-axis, which is the thing that knows whether the turn is yours.
class ChatMessageRow extends StatelessWidget {
  const ChatMessageRow({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: ClaudeSpacing.readingWidth),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

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
          child: Icon(
            Icons.arrow_downward_rounded,
            size: 18,
            color: context.ink,
          ),
        ),
      ),
    );
  }
}
