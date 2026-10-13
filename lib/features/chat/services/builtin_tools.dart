import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:servllama/features/chat/models/chat_tool_call.dart';

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
        'Evaluate an arithmetic expression and return the result. Supports '
        '+ - * / % ^ and parentheses. Use this instead of doing arithmetic '
        'in your head.',
    parameters: <String, dynamic>{
      'type': 'object',
      'properties': <String, dynamic>{
        'expression': <String, dynamic>{
          'type': 'string',
          'description': 'The expression to evaluate, e.g. (3+4)*2',
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
  const BuiltinTools({this.searchKnowledge});

  final KnowledgeSearchCallback? searchKnowledge;

  Map<String, dynamic> toRequestFields() => <String, dynamic>{
    'tools': builtinToolSpecs.map((spec) => spec.toJson()).toList(),
    // "auto" is the only honest value here: forcing a tool call would make
    // the model stop answering questions, and forbidding them would make the
    // feature dead weight.
    'tool_choice': 'auto',
  };

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
            result: _calculate(arguments['expression']),
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

/// Evaluate arithmetic without `eval` and without a full parser.
///
/// A recursive-descent parse of exactly the operators a calculator needs. The
/// alternative — handing the string to something that can execute Dart — would
/// turn a model's typo into arbitrary code running on the phone.
class ExpressionEvaluator {
  ExpressionEvaluator._(this._source);

  final String _source;
  int _pos = 0;

  static double? tryEvaluate(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty || trimmed.length > 200) return null;
    // Only the characters the grammar below accepts. Anything else is not a
    // calculator input, and rejecting it here keeps the parser simple.
    if (!RegExp(r'^[0-9+\-*/%^(). ]+$').hasMatch(trimmed)) return null;
    final evaluator = ExpressionEvaluator._(trimmed);
    try {
      final value = evaluator._parseExpression();
      evaluator._skipSpace();
      if (evaluator._pos != trimmed.length) return null;
      if (!value.isFinite) return null;
      return value;
    } catch (_) {
      return null;
    }
  }

  void _skipSpace() {
    while (_pos < _source.length && _source[_pos] == ' ') {
      _pos += 1;
    }
  }

  double _parseExpression() {
    var value = _parseTerm();
    while (true) {
      _skipSpace();
      if (_pos >= _source.length) return value;
      final op = _source[_pos];
      if (op != '+' && op != '-') return value;
      _pos += 1;
      final rhs = _parseTerm();
      value = op == '+' ? value + rhs : value - rhs;
    }
  }

  double _parseTerm() {
    var value = _parseUnary();
    while (true) {
      _skipSpace();
      if (_pos >= _source.length) return value;
      final op = _source[_pos];
      if (op != '*' && op != '/' && op != '%') return value;
      _pos += 1;
      final rhs = _parseUnary();
      // Division by zero yields null rather than infinity: "inf" going back
      // into a conversation reads as a model glitch.
      if ((op == '/' || op == '%') && rhs == 0) {
        throw const FormatException('division by zero');
      }
      value = switch (op) {
        '*' => value * rhs,
        '/' => value / rhs,
        _ => value % rhs,
      };
    }
  }

  double _parseUnary() {
    _skipSpace();
    if (_pos < _source.length && _source[_pos] == '-') {
      _pos += 1;
      return -_parseUnary();
    }
    if (_pos < _source.length && _source[_pos] == '+') {
      _pos += 1;
      return _parseUnary();
    }
    return _parsePower();
  }

  double _parsePower() {
    final base = _parseAtom();
    _skipSpace();
    if (_pos < _source.length && _source[_pos] == '^') {
      _pos += 1;
      // Right-associative: 2^3^2 is 2^(3^2), as in every other calculator.
      return _pow(base, _parseUnary());
    }
    return base;
  }

  double _pow(double base, double exponent) {
    // dart:math rather than a hand-rolled series. This is the one place in the
    // parser that wants transcendentals, and reimplementing exp/ln to avoid
    // an import buys nothing but inaccuracy.
    // num, always. toDouble() because pow returns int when both arguments are.
    return math.pow(base, exponent).toDouble();
  }

  double _parseAtom() {
    _skipSpace();
    if (_pos >= _source.length) throw const FormatException('unexpected end');
    final char = _source[_pos];
    if (char == '(') {
      _pos += 1;
      final value = _parseExpression();
      _skipSpace();
      if (_pos >= _source.length || _source[_pos] != ')') {
        throw const FormatException('missing )');
      }
      _pos += 1;
      return value;
    }
    final start = _pos;
    while (_pos < _source.length && _isDigit(_source[_pos])) {
      _pos += 1;
    }
    // The fractional part is optional but, if the dot is there, the digits
    // after it must be too. Consuming the dot alone would leave ".5" in the
    // stream and fail the whole expression on an unmatched-trailing check —
    // which reads as "the calculator cannot do decimals" rather than as a bug.
    if (_pos < _source.length && _source[_pos] == '.') {
      _pos += 1;
      final fractionStart = _pos;
      while (_pos < _source.length && _isDigit(_source[_pos])) {
        _pos += 1;
      }
      if (_pos == fractionStart) {
        throw const FormatException('a decimal point needs digits after it');
      }
    }
    if (_pos == start) throw const FormatException('expected a number');
    return double.parse(_source.substring(start, _pos));
  }

  static bool _isDigit(String char) => char.compareTo('0') >= 0 && char.compareTo('9') <= 0;

}

String _calculate(Object? expression) {
  if (expression is! String || expression.trim().isEmpty) {
    return jsonEncode(<String, dynamic>{
      'error': 'No expression was given.',
    });
  }
  final value = ExpressionEvaluator.tryEvaluate(expression);
  if (value == null) {
    return jsonEncode(<String, dynamic>{
      'error': 'Could not evaluate "$expression". Send a plain arithmetic '
          'expression using + - * / % ^ and parentheses.',
    });
  }
  // An int that happens to be a whole number reads as 42 rather than 42.0,
  // and the model will copy what it sees back to the user.
  final rendered = value == value.roundToDouble() && value.abs() < 1e15
      ? value.toInt().toString()
      : value.toString();
  debugPrint('BuiltinTools.calculator: $expression = $rendered');
  return jsonEncode(<String, dynamic>{'result': rendered});
}
