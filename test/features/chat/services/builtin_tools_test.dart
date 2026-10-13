import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/chat/models/chat_tool_call.dart';
import 'package:servllama/features/chat/services/builtin_tools.dart';

void main() {
  group('calculator', () {
    // A calculator that can be talked into executing code is not a
    // calculator. Everything here is parsed by a hand-written grammar, so
    // these cases are the boundary of what it will even look at.
    test('arithmetic', () {
      expect(ExpressionEvaluator.tryEvaluate('3+4'), 7);
      expect(ExpressionEvaluator.tryEvaluate('3 + 4'), 7);
      expect(ExpressionEvaluator.tryEvaluate('10-3-2'), 5);
      expect(ExpressionEvaluator.tryEvaluate('3*4'), 12);
      expect(ExpressionEvaluator.tryEvaluate('10/4'), 2.5);
      expect(ExpressionEvaluator.tryEvaluate('10%3'), 1);
    });

    // A calculator that cannot do 3.5 is not a calculator. This was broken and
    // every other case here was an integer, so nothing caught it.
    test('decimal literals', () {
      expect(ExpressionEvaluator.tryEvaluate('3.5'), 3.5);
      expect(ExpressionEvaluator.tryEvaluate('3.5+1.5'), 5.0);
      expect(ExpressionEvaluator.tryEvaluate('0.1+0.2')!.toStringAsFixed(6),
          '0.300000');
      expect(ExpressionEvaluator.tryEvaluate('.5+.5'), 1.0);
      expect(ExpressionEvaluator.tryEvaluate('1.'), isNull);
    });

    test('precedence and parentheses', () {
      expect(ExpressionEvaluator.tryEvaluate('2+3*4'), 14);
      expect(ExpressionEvaluator.tryEvaluate('(2+3)*4'), 20);
      expect(ExpressionEvaluator.tryEvaluate('((1+2)*(3+4))'), 21);
      expect(ExpressionEvaluator.tryEvaluate('-3+5'), 2);
      expect(ExpressionEvaluator.tryEvaluate('10-(2-8)'), 16);
    });

    test('powers, right-associative', () {
      expect(ExpressionEvaluator.tryEvaluate('2^10'), 1024);
      expect(ExpressionEvaluator.tryEvaluate('2^3^2'), 512);
      expect(ExpressionEvaluator.tryEvaluate('(2^3)^2'), 64);
      expect(ExpressionEvaluator.tryEvaluate('2^-1'), 0.5);
    });

    test('fractional powers', () {
      expect(ExpressionEvaluator.tryEvaluate('2^0.5'), closeTo(1.4142, 0.0001));
      expect(ExpressionEvaluator.tryEvaluate('9^0.5'), closeTo(3, 0.0001));
    });

    test('division by zero is refused, not infinity', () {
      // "inf" travelling back through the model reads as a glitch.
      expect(ExpressionEvaluator.tryEvaluate('1/0'), isNull);
      expect(ExpressionEvaluator.tryEvaluate('5%0'), isNull);
    });

    test('anything that is not arithmetic is refused', () {
      expect(ExpressionEvaluator.tryEvaluate(''), isNull);
      expect(ExpressionEvaluator.tryEvaluate('hello'), isNull);
      expect(ExpressionEvaluator.tryEvaluate('1+'), isNull);
      expect(ExpressionEvaluator.tryEvaluate('(1+2'), isNull);
      expect(ExpressionEvaluator.tryEvaluate('1+2)'), isNull);
      expect(ExpressionEvaluator.tryEvaluate('1..2'), isNull);
      expect(ExpressionEvaluator.tryEvaluate('1e999999'), isNull);
    });

    // The character whitelist is the actual defence. Anything that could be
    // code never reaches the parser.
    test('rejects anything containing a letter or a quote', () {
      for (final attempt in <String>[
        'System.exit(0)',
        'print(1)',
        '"1"',
        "'a'",
        '1;2',
        '1&&2',
        '1\n2',
        '\$var',
        '0x10',
      ]) {
        expect(
          ExpressionEvaluator.tryEvaluate(attempt),
          isNull,
          reason: 'should refuse: $attempt',
        );
      }
    });

    test('refuses absurdly long input', () {
      expect(ExpressionEvaluator.tryEvaluate('1+' * 300 + '1'), isNull);
    });
  });

  group('tool call accumulation', () {
    // The arguments arrive as pieces, usually split mid-token. Concatenating
    // in index order before parsing is the whole job; losing the order loses
    // calls silently rather than loudly.
    test('accumulates fragments into one valid call', () {
      final accumulator = ChatToolCallAccumulator(
        index: 0,
        id: 'call_abc',
        name: 'calculator',
      );
      accumulator
        ..add(const ChatToolCallDelta(index: 0, arguments: '{"expr'))
        ..add(const ChatToolCallDelta(index: 0, arguments: 'ession": "(3+4)'))
        ..add(const ChatToolCallDelta(index: 0, arguments: '*2"}'));

      final call = accumulator.build()!;
      expect(call.id, 'call_abc');
      expect(call.name, 'calculator');
      expect(call.parsedArguments['expression'], '(3+4)*2');
    });

    test('a name arriving in a later fragment still counts', () {
      final accumulator = ChatToolCallAccumulator(index: 0);
      accumulator
        ..add(const ChatToolCallDelta(index: 0, arguments: '{}'))
        ..add(const ChatToolCallDelta(index: 0, name: 'current_time'));
      expect(accumulator.build()!.name, 'current_time');
    });

    test('a call that never got a name is not built', () {
      // Building it would produce a call to a tool that does not exist.
      final accumulator = ChatToolCallAccumulator(index: 0)
        ..add(const ChatToolCallDelta(index: 0, arguments: '{}'));
      expect(accumulator.build(), isNull);
    });

    test('an omitted id falls back to the index', () {
      final accumulator = ChatToolCallAccumulator(index: 2, name: 'calculator')
        ..add(const ChatToolCallDelta(index: 2, arguments: '{}'));
      expect(accumulator.build()!.id, 'call_2');
    });

    // A model emitting half-written JSON must produce a visible failure, not
    // an exception that ends the conversation.
    test('malformed arguments parse to empty rather than throwing', () {
      const call = ChatToolCall(
        id: 'x',
        name: 'calculator',
        arguments: '{"expression": ',
      );
      expect(call.parsedArguments, isEmpty);

      const notJson = ChatToolCall(
        id: 'x',
        name: 'calculator',
        arguments: '3+4',
      );
      expect(notJson.parsedArguments, isEmpty);

      const empty = ChatToolCall(id: 'x', name: 'calculator', arguments: '');
      expect(empty.parsedArguments, isEmpty);
    });
  });

  group('running a tool', () {
    const tools = BuiltinTools();

    test('the calculator returns a value the model can quote', () {
      final result = tools.run(
        const ChatToolCall(
          id: 'call_1',
          name: 'calculator',
          arguments: '{"expression":"(3+4)*2"}',
        ),
      );
      // Run synchronously enough for the test: the tool is not async in here.
      return result.then((value) {
        expect(value.failed, isFalse);
        expect(value.result, contains('14'));
      });
    });

    test('a bad expression comes back as an error the model can read', () {
      return tools
          .run(
            const ChatToolCall(
              id: 'call_2',
              name: 'calculator',
              arguments: '{"expression":"1/0"}',
            ),
          )
          .then((value) {
        expect(value.failed, isFalse);
        // Not a thrown exception — an answer, so the model can recover.
        expect(value.result, contains('error'));
      });
    });

    test('an unknown tool fails loudly instead of doing nothing', () {
      return tools
          .run(
            const ChatToolCall(
              id: 'call_3',
              name: 'rm_rf',
              arguments: '{}',
            ),
          )
          .then((value) {
        expect(value.failed, isTrue);
        expect(value.error, contains('rm_rf'));
      });
    });

    test('knowledge search without a knowledge base says so', () {
      return tools
          .run(
            const ChatToolCall(
              id: 'call_4',
              name: 'knowledge_search',
              arguments: '{"query":"anything"}',
            ),
          )
          .then((value) {
        expect(value.failed, isTrue);
      });
    });

    test('knowledge search calls through', () async {
      final withSearch = BuiltinTools(
        searchKnowledge: (query) async => 'the passage',
      );
      final result = await withSearch.run(
        const ChatToolCall(
          id: 'call_5',
          name: 'knowledge_search',
          arguments: '{"query":"anything"}',
        ),
      );
      expect(result.failed, isFalse);
      expect(result.result, 'the passage');
    });

    test('the request offers all three tools and lets the model choose', () {
      final fields = tools.toRequestFields();
      final specs = fields['tools'] as List;
      expect(specs, hasLength(3));
      // Forcing a call would stop the model answering questions; forbidding
      // them would make the feature dead weight.
      expect(fields['tool_choice'], 'auto');
      final names = specs
          .map((spec) => ((spec as Map)['function'] as Map)['name'])
          .toList();
      expect(names, contains('current_time'));
      expect(names, contains('calculator'));
      expect(names, contains('knowledge_search'));
    });
  });
}
