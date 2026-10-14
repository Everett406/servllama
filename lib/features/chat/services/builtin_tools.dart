import 'dart:convert';

import 'package:servllama/features/chat/models/chat_tool_call.dart';
import 'package:servllama/features/chat/services/script_evaluator.dart';
import 'package:servllama/shared/widgets/tool_settings.dart';

/// The JSON-schema descriptions sent to the model.
///
/// Small and few on purpose. A model on a phone is already the bottleneck, and
/// every tool in the list is a tool it may be tempted to call instead of
/// answering — a long menu of capabilities makes a chat model a worse chat
/// model.
class BuiltinToolSpec {
  const BuiltinToolSpec({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': 'function',
    'function': <String, dynamic>{
      'name': name,
      'description': description,
      'parameters': parameters,
    },
  };
}

const String currentTimeToolName = 'current_time';
const String calculatorToolName = 'calculator';
const String knowledgeSearchToolName = 'knowledge_search';

final List<BuiltinToolSpec> builtinToolSpecs = <BuiltinToolSpec>[
  const BuiltinToolSpec(
    name: currentTimeToolName,
    description:
        'Get the current local date and time. Use this whenever the answer '
        'depends on what time it is now.',
    parameters: <String, dynamic>{
      'type': 'object',
      'properties': <String, dynamic>{
        'timezone': <String, dynamic>{
          'type': 'string',
          'description':
              'IANA timezone name such as Asia/Shanghai. Omit for the device '
              "s own timezone.",
        },
      },
    },
  ),
  const BuiltinToolSpec(
    name: calculatorToolName,
    description:
        'Evaluate a mathematical expression and return the result. Supports '
        '+ - * / % ** ^, parentheses, variables (let x = 3), scientific '
        'notation, and functions such as sqrt, pow, abs, log, sin, cos, atan2, '
        'hypot, floor, ceil, round, min/max via Math.*. Use this for any '
        'arithmetic instead of doing it in your head.',
    parameters: <String, dynamic>{
      'type': 'object',
      'properties': <String, dynamic>{
        'expression': <String, dynamic>{
          'type': 'string',
          'description':
              'The expression to evaluate, e.g. "let r = 5; Math.sqrt(r**2 + '
              'r**2)" or "(3+4)*2"',
        },
      },
      'required': <String>['expression'],
    },
  ),
  const BuiltinToolSpec(
    name: knowledgeSearchToolName,
    description:
        'Search the user\'s own documents for passages relevant to a query. '
        'Use this before answering anything the documents might cover.',
    parameters: <String, dynamic>{
      'type': 'object',
      'properties': <String, dynamic>{
        'query': <String, dynamic>{
          'type': 'string',
          'description': 'What to look for, in the user\'s own words.',
        },
      },
      'required': <String>['query'],
    },
  ),
];

/// Where a knowledge search gets its passages.
///
/// A function rather than a direct dependency so the tool layer has no idea
/// whether a knowledge base exists yet, and can be tested without one.
typedef KnowledgeSearchCallback =
    Future<String> Function(String query);

/// Runs the tools the model asks for.
///
/// Stateless: everything it needs comes in through [now] and [search], which
/// is what makes it testable at a fixed clock without a device.
class BuiltinTools {
  const BuiltinTools({
    this.searchKnowledge,
    this.enabled = const ToolSettings(),
  });

  final KnowledgeSearchCallback? searchKnowledge;

  /// Which tools are on. Defaults to all of them, because a tool that silently
  /// stops working is worse than one that was never offered.
  final ToolSettings enabled;

  /// Whether [tool] should go into the request at all.
  ///
  /// The knowledge search additionally needs something to search: advertising
  /// a tool that always comes back empty teaches the model to call a useless
  /// one.
  bool isOffered(String toolName) {
    switch (toolName) {
      case currentTimeToolName:
        return enabled.clock;
      case calculatorToolName:
        return enabled.calculator;
      case knowledgeSearchToolName:
        return enabled.knowledgeSearch && searchKnowledge != null;
      default:
        return false;
    }
  }

  Map<String, dynamic> toRequestFields() {
    final specs = builtinToolSpecs
        .where((spec) => isOffered(spec.name))
        .map((spec) => spec.toJson())
        .toList();
    // No `tools` key at all when nothing is switched on. An empty array is
    // read by some servers as "this model has no tools" and by others as
    // malformed, and the honest answer to "all off" is to say nothing.
    if (specs.isEmpty) return const <String, dynamic>{};
    return <String, dynamic>{
      'tools': specs,
      // "auto" is the only honest value here: forcing a tool call would make
      // the model stop answering questions, and forbidding them would make the
      // feature dead weight.
      'tool_choice': 'auto',
    };
  }

  /// Run one call and return what to hand back to the model.
  ///
  /// Never throws. A tool that fails has to produce an error string the model
  /// can read and recover from — an exception here would abort a conversation
  /// the user is in the middle of.
  Future<ChatToolResult> run(ChatToolCall call) async {
    final arguments = call.parsedArguments;
    try {
      switch (call.name) {
        case currentTimeToolName:
          return ChatToolResult(
            callId: call.id,
            name: call.name,
            arguments: call.arguments,
            result: _currentTime(arguments['timezone']),
          );
        case calculatorToolName:
          return ChatToolResult(
            callId: call.id,
            name: call.name,
            arguments: call.arguments,
            result: runCalculator(arguments['expression']),
          );
        case knowledgeSearchToolName:
          final search = searchKnowledge;
          if (search == null) {
            return _error(
              call,
              'No knowledge base is available. Answer without it.',
            );
          }
          final query = (arguments['query'] ?? '').toString().trim();
          if (query.isEmpty) {
            return _error(call, 'The query was empty.');
          }
          return ChatToolResult(
            callId: call.id,
            name: call.name,
            arguments: call.arguments,
            result: await search(query),
          );
        default:
          return _error(call, 'Unknown tool: ${call.name}');
      }
    } catch (error) {
      return _error(call, '$error');
    }
  }

  ChatToolResult _error(ChatToolCall call, String message) => ChatToolResult(
    callId: call.id,
    name: call.name,
    arguments: call.arguments,
    result: '',
    error: message,
  );

  static String _currentTime(Object? timezone) {
    final now = DateTime.now();
    if (timezone is! String || timezone.trim().isEmpty) {
      return jsonEncode(<String, dynamic>{
        'iso8601': now.toIso8601String(),
        'timezone': 'device local',
        'formatted': _format(now),
      });
    }
    // Without a timezone database, the device's own offset is all there is to
    // say. Claiming otherwise would be worse than saying this.
    return jsonEncode(<String, dynamic>{
      'iso8601': now.toIso8601String(),
      'timezone': timezone,
      'note': 'Offset is the device local one; this build does not ship a '
          'timezone database, so the named zone may differ.',
      'formatted': _format(now),
    });
  }

  static String _format(DateTime value) =>
      '${value.year}-${_pad(value.month)}-${_pad(value.day)} '
      '${_pad(value.hour)}:${_pad(value.minute)}:${_pad(value.second)}';

  static String _pad(int value) => value.toString().padLeft(2, '0');
}
