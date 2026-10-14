import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Evaluates a small JavaScript-shaped expression language.
///
/// Shaped like JS because that is what a model writes by default:
/// `**`, `Math.sin(x)`, `let r = 3; r ** 2`, `sqrt(16)`. Not *run* like JS —
/// there is no `eval`, no host bridge, and no way to reach anything but the
/// symbol table below.
///
/// Every identifier is resolved through [symbols] or a variable this
/// evaluation declared. That table is the entire attack surface, and it holds
/// numbers. A name that is not in it is an error, not a lookup on some object.
///
/// It exists because a phone-sized model cannot do six-digit arithmetic in its
/// head, and a bare `+ - * /` parser cannot express `Math.hypot` or a
/// compound expression with variables in it. Those are exactly the questions
/// that end in a confidently wrong number.
class ScriptEvaluator {
  ScriptEvaluator._(this._source);

  final String _source;
  final Map<String, double> _variables = <String, double>{};
  int _pos = 0;

  /// Guards against an expression that never ends — a long chain of
  /// multiplications, or a mistake that loops. Counted rather than timed so
  /// the bound holds on a slow phone too.
  int _steps = 0;

  void _tick() {
    if (++_steps > maxSteps) {
      throw _ScriptError('That took too long to work out.');
    }
  }

  static const int maxLength = 2000;
  static const int maxSteps = 20000;

  // ---- entry point -----------------------------------------------------

  /// Run [source] and return its value, or null with a reason.
  static ScriptResult evaluate(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return const ScriptResult.error('Nothing to calculate.');
    }
    if (trimmed.length > maxLength) {
      return const ScriptResult.error(
        'The expression is too long. Keep it under $maxLength characters.',
      );
    }
    final evaluator = ScriptEvaluator._(trimmed);
    return evaluator._run();
  }

  ScriptResult _run() {
    try {
      final value = _parseStatements();
      _skipSpace();
      if (_pos != _source.length) {
        return ScriptResult.error(
          'Unexpected text at position $_pos: "${_source.substring(_pos, (_pos + 12).clamp(0, _source.length))}"',
        );
      }
      return ScriptResult.value(value);
    } on _ScriptError catch (error) {
      return ScriptResult.error(error.message);
    } catch (error) {
      // ignore: avoid_print
      print('EVAL DEBUG: ${error.runtimeType} $error');
      // A runaway expression (1e308 * 1e308 * ...) must come back as a
      // number the model can see went wrong, not as a missing answer.
      return const ScriptResult.error(
        'Could not evaluate that. Check for a division by zero, a typo, or a '
        'number too large.',
      );
    }
  }

  double _parseStatements() {
    _skipSpace();
    var last = 0.0;
    while (_pos < _source.length) {
      _tick();
      _skipSpace();
      final saved = _pos;
      final name = _tryReadDeclarationKeyword();
      if (name != null) {
        final variable = _readIdentifier();
        _expect('=');
        last = _parseExpression();
        // Under the variable's own name. Storing under the keyword means
        // `let r = 3; r ** 2` answers "r is not defined".
        _variables[variable] = last;
        _expectSeparator();
        continue;
      }
      // Not a declaration: this is the whole statement.
      _pos = saved;
      last = _parseExpression();
      _expectSeparator();
    }
    return last;
  }

  /// `let` / `const` / `var`, or null.
  String? _tryReadDeclarationKeyword() {
    final start = _pos;
    final word = _tryReadWord();
    if (word == 'let' || word == 'const' || word == 'var') {
      _skipSpace();
      return word;
    }
    _pos = start;
    return null;
  }

  void _expect(String text) {
    _skipSpace();
    if (!_source.startsWith(text, _pos)) {
      throw _ScriptError('Expected "$text".');
    }
    _pos += text.length;
  }

  /// `;` or the end of the input. Newlines are fine as separators.
  void _expectSeparator() {
    _skipSpace();
    if (_pos < _source.length && _source[_pos] == ';') {
      _pos += 1;
    }
  }

  // ---- grammar ---------------------------------------------------------

  double _parseExpression() {
    var left = _parseTerm();
    while (true) {
      _tick();
      _skipSpace();
      if (_pos >= _source.length) return left;
      final op = _source[_pos];
      if (op == '+' || op == '-') {
        _pos += 1;
        final right = _parseTerm();
        left = op == '+' ? left + right : left - right;
        continue;
      }
      return left;
    }
  }

  double _parseTerm() {
    var left = _parseUnary();
    while (true) {
      _skipSpace();
      if (_pos >= _source.length) return left;
      final op = _source[_pos];
      if (op != '*' && op != '/' && op != '%') return left;
      _pos += 1;
      final right = _parseUnary();
      if ((op == '/' || op == '%') && right == 0) {
        // "inf" travelling back through the model reads as a glitch.
        throw _ScriptError('Division by zero.');
      }
      left = switch (op) {
        '*' => left * right,
        '/' => left / right,
        _ => left % right,
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
    // Bounds-checked before indexing: `startsWith` is safe at the end of the
    // string, `[]` is not, and "3+4" parses as a power whose operand runs
    // straight off the end.
    if (_pos >= _source.length) return base;
    // `**` first, then `^`. Both spellings because a model writes both, and
    // one of them means "xor" in some languages it might have been trained on.
    if (_source.startsWith('**', _pos)) {
      _pos += 2;
      // Right-associative: 2**3**2 is 2**(3**2).
      return _pow(base, _parseUnary());
    }
    if (_source[_pos] == '^') {
      _pos += 1;
      return _pow(base, _parseUnary());
    }
    return base;
  }

  double _pow(double base, double exponent) => math.pow(base, exponent).toDouble();

  double _parseAtom() {
    _skipSpace();
    if (_pos >= _source.length) throw _ScriptError('The expression ends early.');
    final char = _source[_pos];

    if (char == '(') {
      _pos += 1;
      final value = _parseExpression();
      _expect(')');
      return value;
    }
    if (_isDigit(char) || char == '.') return _parseNumber();
    if (_isIdentifierStart(char)) return _parseIdentifier();

    throw _ScriptError('Unexpected "$char".');
  }

  double _parseNumber() {
    final start = _pos;
    while (_pos < _source.length && _isDigit(_source[_pos])) {
      _pos += 1;
    }
    if (_pos < _source.length && _source[_pos] == '.') {
      _pos += 1;
      final fractionStart = _pos;
      while (_pos < _source.length && _isDigit(_source[_pos])) {
        _pos += 1;
      }
      if (_pos == fractionStart) {
        // Consuming the dot alone would leave ".5" in the stream and fail the
        // trailing check, which reads as "cannot do decimals" rather than as
        // a parser bug.
        throw _ScriptError('A decimal point needs digits after it.');
      }
    }
    // Scientific notation: a model writing 1e-9 is not rare, and reading it
    // as `1` followed by garbage is worse than not supporting it.
    if (_pos < _source.length && (_source[_pos] == 'e' || _source[_pos] == 'E')) {
      final save = _pos;
      _pos += 1;
      if (_pos < _source.length && (_source[_pos] == '+' || _source[_pos] == '-')) {
        _pos += 1;
      }
      final expStart = _pos;
      while (_pos < _source.length && _isDigit(_source[_pos])) {
        _pos += 1;
      }
      if (_pos == expStart) _pos = save;
    }
    final value = double.tryParse(_source.substring(start, _pos));
    if (value == null) throw _ScriptError('"${_source.substring(start, _pos)}" is not a number.');
    return value;
  }

  double _parseIdentifier() {
    // `Math.sin(1)` and a bare `sin(1)` both work: a model reaches for
    // whichever, and rejecting one of them produces a failed call rather than
    // an answer.
    if (_source.startsWith('Math.', _pos)) {
      _pos += 5;
      final member = _readIdentifier();
      // _tryReadArgument reads a single value, so 'hypot(3,4)' would parse as
      // hypot(3) and then choke on the comma. Two-argument functions have to
      // be routed before it.
      if (_twoArgumentFunctions.contains(member)) {
        return _applyTwoArgument(member);
      }
      final argument = _tryReadArgument();
      return _applyMath(member, argument);
    }

    final name = _readIdentifier();
    // Same ordering problem as the Math. branch: reading one argument first
    // would swallow '(3' out of 'hypot(3,4)' and leave the comma stranded.
    if (_twoArgumentFunctions.contains(name)) {
      return _applyTwoArgument(name);
    }
    final argument = _tryReadArgument();
    if (argument != null) {
      final fn = _functions[name];
      if (fn == null) throw _ScriptError('There is no function called "$name".');
      return fn(argument);
    }
    final variable = _variables[name];
    if (variable != null) return variable;
    final constant = _constants[name];
    if (constant != null) return constant;
    // Deliberately not "unknown identifier treated as zero": a typo that
    // quietly becomes 0 is how a model reports a confident wrong answer.
    throw _ScriptError(
      '"$name" is not defined. Use a number, Math.<fn>(), or declare it first '
      'with "let".',
    );
  }

  double? _tryReadArgument() {
    final save = _pos;
    _skipSpace();
    if (_pos < _source.length && _source[_pos] == '(') {
      _pos += 1;
      final value = _parseExpression();
      _expect(')');
      return value;
    }
    _pos = save;
    return null;
  }

  /// `atan2(y, x)`, `hypot(a, b)`, `pow(a, b)`.
  ///
  /// They need two numbers and do not fit the one-argument table, so they
  /// read their arguments straight from the source — which is also why
  /// `Math.hypot(3, 4)` has to be routed here rather than through
  /// [\_tryReadArgument].
  double _applyTwoArgument(String name) {
    _skipSpace();
    if (_pos >= _source.length || _source[_pos] != '(') {
      throw _ScriptError('$name() needs two numbers.');
    }
    _pos += 1;
    final first = _parseExpression();
    _expect(',');
    final second = _parseExpression();
    _expect(')');
    return switch (name) {
      'atan2' => math.atan2(first, second),
      'hypot' => math.sqrt(first * first + second * second),
      _ => math.pow(first, second).toDouble(),
    };
  }

  double _applyMath(String name, double? argument) {
    // The Math. branch never went through _tryReadArgument, so nothing has
    // consumed the '(' yet and _applyTwoArgument reads it from here.
    if (argument == null) {
      throw _ScriptError('Math.$name() needs a number.');
    }
    final fn = _functions[name];
    if (fn == null) throw _ScriptError('There is no Math.$name().');
    return fn(argument);
  }

  String _readIdentifier() {
    final start = _pos;
    while (_pos < _source.length && _isIdentifierPart(_source[_pos])) {
      _pos += 1;
    }
    if (_pos == start) throw _ScriptError('Expected a name.');
    return _source.substring(start, _pos);
  }

  String? _tryReadWord() {
    if (_pos >= _source.length || !_isIdentifierStart(_source[_pos])) {
      return null;
    }
    final start = _pos;
    while (_pos < _source.length && _isIdentifierPart(_source[_pos])) {
      _pos += 1;
    }
    return _source.substring(start, _pos);
  }

  void _skipSpace() {
    while (_pos < _source.length) {
      final char = _source[_pos];
      if (char == ' ' || char == '\n' || char == '\t' || char == '\r') {
        _pos += 1;
      } else {
        return;
      }
    }
  }

  // ---- the entire symbol table -----------------------------------------

  static const Map<String, double> _constants = <String, double>{
    'PI': math.pi,
    'E': math.e,
    'pi': math.pi,
    'Infinity': double.infinity,
  };

  /// Everything reachable by name. Numbers in, numbers out — there is no
  /// object here, so there is no chain of properties to walk and no method to
  /// reach through.
  ///
  /// Not const: the entries are closures. That is fine — the table is built
  /// once, and "which names exist" is still a fixed, inspectable set.
  static const Set<String> _twoArgumentFunctions = <String>{
    'atan2',
    'hypot',
    'pow',
  };

  static final Map<String, double Function(double)> _functions =
      <String, double Function(double)>{
        'abs': (x) => x.abs(),
        'sqrt': math.sqrt,
        'cbrt': (x) => _signed(
          math.pow(x.abs(), 1 / 3).toDouble(),
          x,
        ),
        'exp': math.exp,
        'log': math.log,
        'log2': (x) => math.log(x) / math.ln2,
        'log10': (x) => math.log(x) / math.ln10,
        'ln': math.log,
        'sin': math.sin,
        'cos': math.cos,
        'tan': math.tan,
        'asin': math.asin,
        'acos': math.acos,
        'atan': math.atan,
        // Not on dart:math, and a model asking for sinh is asking for a
        // real function, not a missing one.
        'sinh': _sinh,
        'cosh': _cosh,
        'tanh': _tanh,
        'floor': (x) => x.floorToDouble(),
        'ceil': (x) => x.ceilToDouble(),
        'round': (x) => x.roundToDouble(),
        'sign': (x) => x.sign,
        // Degrees, because that is how a question is phrased.
        'toRad': (x) => x * math.pi / 180,
        'toDeg': (x) => x * 180 / math.pi,
      };

  static double _signed(double value, double original) =>
      original < 0 ? -value : value;

  // (e^x - e^-x)/2. Computing both halves separately rather than by dividing
  // `exp` by itself keeps the cancellation error out of the result.
  static double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;

  static double _cosh(double x) => (math.exp(x) + math.exp(-x)) / 2;

  static double _tanh(double x) {
    if (x > 20) return 1;
    if (x < -20) return -1;
    final e = math.exp(2 * x);
    return (e - 1) / (e + 1);
  }

  static bool _isDigit(String char) =>
      char.isNotEmpty && char.codeUnitAt(0) >= 0x30 && char.codeUnitAt(0) <= 0x39;

  static bool _isIdentifierStart(String char) {
    if (char.isEmpty) return false;
    final unit = char.codeUnitAt(0);
    return (unit >= 0x41 && unit <= 0x5A) ||
        (unit >= 0x61 && unit <= 0x7A) ||
        char == '_';
  }

  static bool _isIdentifierPart(String char) =>
      _isIdentifierStart(char) || _isDigit(char);
}

/// What an evaluation produced.
class ScriptResult {
  const ScriptResult.value(this.value)
    : error = null,
      isError = false;

  const ScriptResult.error(this.error)
    : value = null,
      isError = true;

  final double? value;
  final String? error;
  final bool isError;

  /// What to hand back to the model.
  ///
  /// Errors are returned, not thrown. A model that asks for `1/0` has to be
  /// able to read "that is undefined" and answer something else, rather than
  /// ending the conversation.
  String toJsonString() {
    if (!isError) {
      return jsonEncode(<String, dynamic>{'result': _render(value!)});
    }
    return jsonEncode(<String, dynamic>{'error': error});
  }

  static String _render(double value) {
    if (!value.isFinite) return 'undefined (the result is not finite)';
    // A whole number reads as 42 rather than 42.0, and the model copies what
    // it sees back to the user.
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toInt().toString();
    }
    return value.toString();
  }
}

class _ScriptError implements Exception {
  _ScriptError(this.message);

  final String message;
}

/// Runs the calculator tool.
String runCalculator(String? expression) {
  if (expression == null || expression.trim().isEmpty) {
    return jsonEncode(<String, dynamic>{
      'error': 'No expression was given.',
    });
  }
  final result = ScriptEvaluator.evaluate(expression);
  debugPrint(
    'BuiltinTools.calculator: $expression -> '
    '${result.isError ? 'error(${result.error})' : result.value}',
  );
  return result.toJsonString();
}