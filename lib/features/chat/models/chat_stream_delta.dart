import 'package:servllama/features/chat/models/chat_tool_call.dart';

class ChatStreamDelta {
  const ChatStreamDelta({
    this.content = '',
    this.reasoningContent = '',
    this.toolCalls = const <ChatToolCallDelta>[],
  });

  final String content;
  final String reasoningContent;

  /// Fragments of tool calls in this delta. Accumulated by index across the
  /// whole stream — the JSON arguments arrive in pieces.
  final List<ChatToolCallDelta> toolCalls;

  bool get isEmpty =>
      content.isEmpty &&
      reasoningContent.isEmpty &&
      toolCalls.every((call) => call.isEmpty);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatStreamDelta &&
          runtimeType == other.runtimeType &&
          content == other.content &&
          reasoningContent == other.reasoningContent;

  @override
  int get hashCode => Object.hash(content, reasoningContent);
}
