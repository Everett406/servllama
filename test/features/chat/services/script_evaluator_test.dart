import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/chat/services/script_evaluator.dart';

double? value(String source) {
  final result = ScriptEvaluator.evaluate(source);
  return result.isError ? null : result.value;
}

void main() {
  // A phone-sized model cannot do six-digit arithmetic in its head, and a
  // bare `+ - * /` parser cannot express Math.hypot or a compound expression
  // with variables — which is exactly the set of questions that end in a
  // confidently wrong number.
  group('arithmetic', () {
    test('the basics', () {
      expect(value('3+4'), 7);
      expect(value('10-3-2'), 5);
      expect(value('3*4'), 12);
      expect(value('10/4'), 2.5);
      expect(value('10%3'), 1);
    });

    test('precedence and parentheses', () {
      expect(value('2+3*4'), 14);
      expect(value('(2+3)*4'), 20);
      expect(value('-3+5'), 2);
      expect(value('10-(2-8)'), 16);
    });

    // Both spellings, because a model writes both and one of them means "xor"
    // in some of the languages it was trained on.
    test('power, both spellings and right-associative', () {
      expect(value('2^10'), 1024);
      expect(value('2**10'), 1024);
      expect(value('2**3**2'), 512);
      expect(value('(2**3)**2'), 64);
      expect(value('2**-1'), 0.5);
    });

    test('decimal and scientific notation', () {
      expect(value('3.5'), 3.5);
      expect(value('3.5+1.5'), 5);
      expect(value('1.5e3'), 1500);
      expect(value('2e-2'), 0.02);
    });
  });

  group('variables', () {
    test('a declared variable is usable afterwards', () {
      expect(value('let r = 3; r ** 2'), 9);
      expect(value('const a = 2; let b = 5; a * b'), 10);
    });

    // A typo that quietly becomes zero is how a model reports a confident
    // wrong answer.
    test('an unknown name is an error, not a zero', () {
      final result = ScriptEvaluator.evaluate('rr ** 2');
      expect(result.isError, isTrue);
      expect(result.error, contains('not defined'));
    });

    test('a new statement shadows an old value', () {
      expect(value('let x = 1; let x = 2; x'), 2);
    });
  });

  group('functions', () {
    test('bare and Math.-prefixed both work', () {
      expect(value('sqrt(16)'), 4);
      expect(value('Math.sqrt(16)'), 4);
      expect(value('abs(-3)'), 3);
      expect(value('Math.abs(-3)'), 3);
    });

    test('trigonometry takes radians by default and degrees on request', () {
      expect(value('sin(0)'), 0);
      expect(value('toRad(90)'), closeTo(1.5708, 0.0001));
      expect(value('toDeg(PI)'), closeTo(180, 0.0001));
    });

    test('logarithms', () {
      expect(value('log10(1000)'), closeTo(3, 0.0001));
      expect(value('log(1)'), 0);
      expect(value('ln(E)'), closeTo(1, 0.0001));
    });

    test('rounding', () {
      expect(value('floor(2.7)'), 2);
      expect(value('ceil(2.1)'), 3);
      expect(value('round(2.5)'), 3);
      expect(value('sign(-4)'), -1);
    });

    // These take two arguments, and the single-argument reader would parse
    // hypot(3,4) as hypot(3) and then choke on the comma.
    test('two-argument functions', () {
      expect(value('Math.hypot(3,4)'), 5);
      expect(value('hypot(3,4)'), 5);
      expect(value('Math.pow(2,10)'), 1024);
      expect(value('pow(2,10)'), 1024);
      expect(value('Math.atan2(1,1)'), closeTo(0.7854, 0.0001));
    });

    test('constants', () {
      expect(value('PI'), closeTo(3.14159, 0.0001));
      expect(value('E'), closeTo(2.71828, 0.0001));
    });

    test('an unknown function is named', () {
      final result = ScriptEvaluator.evaluate('sinh2(3)');
      expect(result.isError, isTrue);
    });
  });

  group('not a scripting host', () {
    // Every name resolves through the symbol table, which holds numbers.
    // That table is the entire surface: no objects, no properties to walk,
    // no method to reach through.
    test('nothing outside the symbol table is reachable', () {
      for (final attempt in <String>[
        'System',
        'process',
        'globalThis',
        'require("fs")',
        'this',
        'constructor',
        '__proto__',
        'Math',
        'eval("1+1")',
        'print(1)',
        'a.b.c',
        'x[0]',
        'new Date()',
      ]) {
        final result = ScriptEvaluator.evaluate(attempt);
        expect(
          result.isError,
          isTrue,
          reason: 'should refuse: $attempt',
        );
      }
    });

    test('a function call is only callable from the table', () {
      expect(ScriptEvaluator.evaluate('abs(-1)').isError, isFalse);
      expect(ScriptEvaluator.evaluate('myOwnFn(1)').isError, isTrue);
    });

    test('refuses unbounded work', () {
      // The length cap, which is the one a phone can afford to check first.
      expect(ScriptEvaluator.evaluate('1' * 3000).isError, isTrue);
      // The step cap, for something short but deeply nested: parens nest
      // without bound and every level costs a step, so this trips the counter
      // rather than the length cap.
      const depth = 4000;
      expect(
        ScriptEvaluator.evaluate(
          '${List<String>.filled(depth, '(').join()}1'
          '${List<String>.filled(depth, ')').join()}',
        ).isError,
        isTrue,
      );
    });

    test('division by zero is an error, never infinity', () {
      final result = ScriptEvaluator.evaluate('1/0');
      expect(result.isError, isTrue);
      // "inf" travelling back through the model reads as a glitch.
      expect(result.toJsonString(), isNot(contains('Infinity')));
    });

    test('malformed input is an error, not a guess', () {
      for (final bad in <String>[
        '1+',
        '(1+2',
        '1+2)',
        '..5',
        '1..2',
        '',
        '   ',
        'let = 5',
        'let x 5',
      ]) {
        expect(
          ScriptEvaluator.evaluate(bad).isError,
          isTrue,
          reason: 'should refuse: "$bad"',
        );
      }
    });
  });

  group('result shape', () {
    test('a whole number reads as a whole number', () {
      // The model copies what it sees back to the user.
      expect(ScriptResult.value(42).toJsonString(), contains('"result":"42"'));
      expect(
        ScriptResult.value(42.5).toJsonString(),
        contains('"result":"42.5"'),
      );
    });

    test('a non-finite result says so rather than printing Infinity', () {
      expect(
        ScriptResult.value(double.infinity).toJsonString(),
        contains('not finite'),
      );
    });

    test('an error is returned, not thrown', () {
      // A model that asks for 1/0 has to be able to read "that is undefined"
      // and answer something else, rather than ending the conversation.
      final result = ScriptEvaluator.evaluate('1/0');
      expect(result.toJsonString(), contains('"error"'));
    });
  });
}
