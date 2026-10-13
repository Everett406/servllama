import 'dart:convert';

/// A tool call as it arrives from the model, one fragment at a time.
///
/// OpenAI-style streaming sends `tool_calls` in the delta with an `index` and
/// pieces of a JSON `arguments` string. The pieces must be concatenated in
/// index order *before* they parse — the JSON is usually split mid-token, so
/// a fragment is not a document and treating it as one loses calls silently.
class ChatToolCallDelta {
  const ChatToolCallDelta({
    required this.index,
    this.id,
    this.name,
    this.arguments = '',
  });

  final int index;
  final String? id;
  final String? name;
  final String arguments;

  bool get isEmpty => (id ?? '').isEmpty && (name ?? '').isEmpty && arguments.isEmpty;

  @override
  String toString() =>
      'ChatToolCallDelta(index: $index, id: $id, name: $name, args: $arguments)';
}

/// A fully accumulated call, ready to run.
class ChatToolCall {
  const ChatToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;
  final String arguments;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'arguments': arguments,
  };

  factory ChatToolCall.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ChatToolCall(id: '', name: '', arguments: '');
    }
    return ChatToolCall(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      arguments: (json['arguments'] ?? '').toString(),
    );
  }

  /// The parsed arguments, or an empty map when they are not valid JSON.
  ///
  /// Never throws. A model that emits a half-written argument string should
  /// produce a failed call the user can see, not an exception that takes the
  /// conversation down mid-sentence.
  Map<String, dynamic> get parsedArguments {
    final trimmed = arguments.trim();
    if (trimmed.isEmpty) return const <String, dynamic>{};
    try {
      final decoded = jsonDecode(trimmed);
      return decoded is Map ? decoded.cast<String, dynamic>() : const <String, dynamic>{};
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  @override
  String toString() => 'ChatToolCall($name, $arguments)';
}

/// Accumulates the fragments of one tool call across deltas.
class ChatToolCallAccumulator {
  ChatToolCallAccumulator({required this.index, String? id, String? name})
    : _id = id,
      _name = name;

  final int index;
  String? _id;
  String? _name;
  final StringBuffer _arguments = StringBuffer();

  void add(ChatToolCallDelta delta) {
    if (delta.id != null && delta.id!.isNotEmpty) _id = delta.id;
    if (delta.name != null && delta.name!.isNotEmpty) _name = delta.name;
    _arguments.write(delta.arguments);
  }

  /// Null until there is a name to run — a call whose name never arrived is
  /// not a call.
  ChatToolCall? build() {
    final name = _name;
    if (name == null || name.isEmpty) return null;
    return ChatToolCall(
      // A server that omits the id still gave us an ordered list, so the
      // index is a usable identity for the `role: tool` reply.
      id: (_id != null && _id!.isNotEmpty) ? _id! : 'call_$index',
      name: name,
      arguments: _arguments.toString(),
    );
  }
}

/// A call a tool returned, as stored on the message.
class ChatToolResult {
  const ChatToolResult({
    required this.callId,
    required this.name,
    required this.arguments,
    required this.result,
    this.error,
  });

  final String callId;
  final String name;
  final String arguments;
  final String result;

  /// Non-null when the tool failed. Kept as a string rather than a flag so
  /// the failure can be shown and sent back to the model verbatim.
  final String? error;

  bool get failed => error != null;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'callId': callId,
    'name': name,
    'arguments': arguments,
    'result': result,
    if (error != null) 'error': error,
  };

  factory ChatToolResult.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ChatToolResult(
        callId: '',
        name: '',
        arguments: '',
        result: '',
      );
    }
    return ChatToolResult(
      callId: (json['callId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      arguments: (json['arguments'] ?? '').toString(),
      result: (json['result'] ?? '').toString(),
      error: json['error'] is String ? json['error'] as String : null,
    );
  }
}

/// Tool data is stored as two JSON strings on the message rather than as a
/// list of Hive objects: the shape is small, the fields change as tools do, and
/// a plain string reads in a box file without a decoder.
String encodeToolCalls(List<ChatToolCall> calls) =>
    jsonEncode(calls.map((call) => call.toJson()).toList());

String encodeToolResults(List<ChatToolResult> results) =>
    jsonEncode(results.map((result) => result.toJson()).toList());

List<ChatToolCall> decodeToolCalls(String? raw) => _decodeList(
  raw,
  (json) => ChatToolCall.fromJson(json),
);

List<ChatToolResult> decodeToolResults(String? raw) => _decodeList(
  raw,
  (json) => ChatToolResult.fromJson(json),
);

List<T> _decodeList<T>(String? raw, T Function(Map<String, dynamic>) build) {
  if (raw == null || raw.isEmpty) return const <Never>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <Never>[];
    return decoded
        .whereType<Map>()
        .map((entry) => build(entry.cast<String, dynamic>()))
        .toList();
  } catch (_) {
    // A box written by an older build, or truncated by a bad shutdown. Losing
    // the tool history is survivable; refusing to open the box is not.
    return const <Never>[];
  }
}
