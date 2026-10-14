import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/chat/models/chat_tool_call.dart';
import 'package:servllama/shared/widgets/tool_settings.dart';
import 'package:servllama/features/chat/services/builtin_tools.dart';

/// The numeric value, or null when the evaluation failed.
void main() {
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

    test('the request offers the switched-on tools and lets the model choose', () {
      final withSearch = BuiltinTools(
        searchKnowledge: (query) async => 'passage',
      );
      final fields = withSearch.toRequestFields();
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

    // Advertising a tool that always comes back empty teaches the model to
    // call a useless one, so the search is omitted when there is nothing
    // behind it.
    test('the search is omitted when there is no knowledge base', () {
      final fields = const BuiltinTools().toRequestFields();
      final names = (fields['tools']! as List)
          .map((spec) => ((spec as Map)['function'] as Map)['name'])
          .toList();
      expect(names, isNot(contains('knowledge_search')));
      expect(names, contains('calculator'));
    });

    // A knowledge base that is not set up must not take the clock and the
    // calculator with it. It used to: all three lived behind the same check.
    test('a missing knowledge base leaves the other tools alone', () {
      final fields = const BuiltinTools().toRequestFields();
      expect(fields.containsKey('tools'), isTrue);
      expect((fields['tools']! as List), hasLength(2));
    });

    test('a switched-off tool is not offered', () {
      const off = BuiltinTools(
        enabled: ToolSettings(clock: false, calculator: false),
      );
      // "All off" says nothing at all rather than sending an empty array,
      // which some servers read as malformed.
      expect(off.toRequestFields(), isEmpty);

      const onlyClock = BuiltinTools(
        enabled: ToolSettings(calculator: false, knowledgeSearch: false),
      );
      final names = (onlyClock.toRequestFields()['tools']! as List)
          .map((spec) => ((spec as Map)['function'] as Map)['name'])
          .toList();
      expect(names, <String>['current_time']);
    });
  });
}
