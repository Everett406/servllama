import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/models/generation_params.dart';

void main() {
  group('toRequestFields', () {
    test('an unset parameter is left out of the body entirely', () {
      // Sending nulls is not the same as omitting: some servers read an
      // explicit null as "use the launch default" and others reject it.
      // There is nothing to gain by finding out which.
      const params = GenerationParams();
      expect(params.isEmpty, isTrue);
      expect(params.toRequestFields(), isEmpty);
    });

    test('only the set parameters appear', () {
      const params = GenerationParams(temperature: 0.7, topK: 40);
      expect(params.toRequestFields(), {'temperature': 0.7, 'top_k': 40});
      expect(params.isEmpty, isFalse);
    });

    test('every parameter reaches the body under its server name', () {
      const params = GenerationParams(
        temperature: 0.6,
        topP: 0.9,
        topK: 30,
        repeatPenalty: 1.1,
        maxTokens: 2048,
      );
      expect(params.toRequestFields(), {
        'temperature': 0.6,
        'top_p': 0.9,
        'top_k': 30,
        'repeat_penalty': 1.1,
        'max_tokens': 2048,
      });
    });
  });

  group('sanitized', () {
    test('clamps to what a server will accept', () {
      const wild = GenerationParams(
        temperature: 9,
        topP: 4,
        topK: 9999,
        repeatPenalty: -3,
      );
      final safe = wild.sanitized();
      expect(safe.temperature, 2.0);
      expect(safe.topP, 1.0);
      expect(safe.topK, 200);
      expect(safe.repeatPenalty, 0.5);
    });

    // A cap below one would cut every reply off before its first token, which
    // is worse than sending no cap at all.
    test('drops a max_tokens below one rather than sending it', () {
      expect(const GenerationParams(maxTokens: 0).sanitized().maxTokens, isNull);
      expect(const GenerationParams(maxTokens: -5).sanitized().maxTokens, isNull);
      expect(const GenerationParams(maxTokens: 1).sanitized().maxTokens, 1);
    });

    test('leaves unset parameters unset', () {
      final safe = const GenerationParams().sanitized();
      expect(safe.isEmpty, isTrue);
    });
  });

  group('copyWith', () {
    test('changes one parameter and keeps the rest', () {
      const before = GenerationParams(temperature: 0.5, topK: 20);
      final after = before.copyWith(topP: 0.8);
      expect(after.temperature, 0.5);
      expect(after.topK, 20);
      expect(after.topP, 0.8);
    });

    test('clear flags remove a parameter', () {
      const before = GenerationParams(temperature: 0.5, topK: 20);
      final after = before.copyWith(clearTopK: true);
      expect(after.topK, isNull);
      expect(after.temperature, 0.5);
    });

    test('copyWith with no arguments changes nothing', () {
      const before = GenerationParams(temperature: 0.5, topK: 20);
      expect(before.copyWith(), before);
    });
  });

  group('json round trip', () {
    test('survives a save and load', () {
      const params = GenerationParams(
        temperature: 0.42,
        topP: 0.85,
        topK: 7,
        repeatPenalty: 1.15,
        maxTokens: 512,
      );
      expect(
        GenerationParams.fromJson(params.toJson()),
        params,
      );
    });

    test('an absent or malformed blob costs the settings, not the app', () {
      expect(GenerationParams.fromJson(null).isEmpty, isTrue);
      expect(GenerationParams.fromJson(<String, dynamic>{}).isEmpty, isTrue);
      // Strings survive because a blob written by an older build, or edited by
      // hand, may well hold them.
      expect(
        GenerationParams.fromJson({'temperature': '0.7'}).temperature,
        0.7,
      );
      expect(
        GenerationParams.fromJson({'temperature': 'nonsense'}).temperature,
        isNull,
      );
    });
  });
}
