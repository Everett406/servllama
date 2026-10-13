import 'package:hive/hive.dart';
import 'package:servllama/features/chat/models/chat_tool_call.dart';

part 'chat_message_record.g.dart';

@HiveType(typeId: 3)
enum ChatRole {
  @HiveField(0)
  user,

  @HiveField(1)
  assistant,
}

@HiveType(typeId: 1)
class ChatMessageRecord {
  const ChatMessageRecord({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.sessionId,
    this.modelName,
    this.reasoningContent,
    this.imageFilePaths = const [],
    this.versionIds = const [],
    this.currentVersionIndex = 0,
    this.toolResults = const [],
    this.toolCalls = const [],
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  final ChatRole role;

  @HiveField(2)
  final String content;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(9)
  final String? sessionId;

  @HiveField(4)
  final String? modelName;

  @HiveField(5)
  final String? reasoningContent;

  @HiveField(6)
  final List<String> imageFilePaths;

  @HiveField(7)
  final List<String> versionIds;

  @HiveField(8)
  final int currentVersionIndex;

  /// Calls the model asked for on this turn, and what came back.
  ///
  /// Stored on the message rather than kept beside it, so a reopened
  /// conversation still shows what it used and a follow-up turn still has the
  /// results in the prompt — a tool call the model cannot see the answer to is
  /// a tool call it will repeat.
  @HiveField(10)
  final List<ChatToolResult> toolResults;

  @HiveField(11)
  final List<ChatToolCall> toolCalls;

  int get versionCount => versionIds.isEmpty ? 1 : versionIds.length;

  bool get hasMultipleVersions => versionIds.length > 1;

  ChatMessageRecord copyWith({
    String? id,
    ChatRole? role,
    String? content,
    DateTime? createdAt,
    String? sessionId,
    bool clearSessionId = false,
    String? modelName,
    String? reasoningContent,
    bool clearModelName = false,
    bool clearReasoningContent = false,
    List<String>? imageFilePaths,
    bool clearImageFilePaths = false,
    List<String>? versionIds,
    bool clearVersionIds = false,
    int? currentVersionIndex,
    List<ChatToolCall>? toolCalls,
    bool clearToolCalls = false,
    List<ChatToolResult>? toolResults,
    bool clearToolResults = false,
  }) {
    return ChatMessageRecord(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      sessionId: clearSessionId ? null : sessionId ?? this.sessionId,
      modelName: clearModelName ? null : modelName ?? this.modelName,
      reasoningContent: clearReasoningContent
          ? null
          : reasoningContent ?? this.reasoningContent,
      imageFilePaths: clearImageFilePaths
          ? const []
          : imageFilePaths ?? this.imageFilePaths,
      versionIds: clearVersionIds ? const [] : versionIds ?? this.versionIds,
      currentVersionIndex: currentVersionIndex ?? this.currentVersionIndex,
      // Clearing matters: a regenerated turn must not keep the previous
      // turn's tool calls and results in the prompt, or the model sees
      // answers to questions it is no longer asking.
      toolCalls: clearToolCalls
          ? const <ChatToolCall>[]
          : toolCalls ?? this.toolCalls,
      toolResults: clearToolResults
          ? const <ChatToolResult>[]
          : toolResults ?? this.toolResults,
    );
  }
}
