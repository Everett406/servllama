import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/chat/services/session_title_generator.dart';

void main() {
  // A title comes back from a model, which means it comes back with whatever
  // the model felt like wrapping it in. All of this is the cleanup that keeps a
  // conversation list from filling up with "1. 关于…" and "标题：…".
  group('title cleanup', () {
    String? clean(String? raw) => SessionTitleGenerator.cleanForTest(raw);

    test('a plain title passes through', () {
      expect(clean('Rust 所有权与借用'), 'Rust 所有权与借用');
      expect(clean('Docker compose networking'), 'Docker compose networking');
    });

    test('quotes come off', () {
      expect(clean('"关于异步的讨论"'), '关于异步的讨论');
      expect(clean('「关于异步的讨论」'), '关于异步的讨论');
      expect(clean('“nested”'), 'nested');
    });

    test('list markers and leading punctuation come off', () {
      expect(clean('- Rust 所有权'), 'Rust 所有权');
      expect(clean('1. Rust 所有权'), 'Rust 所有权');
      expect(clean('### Rust 所有权'), 'Rust 所有权');
      expect(clean('• 异步'), '异步');
    });

    test('a trailing full stop comes off', () {
      expect(clean('Rust 所有权。'), 'Rust 所有权');
      expect(clean('Docker networking.'), 'Docker networking');
    });

    test('an explanation on later lines is dropped, not shown', () {
      // Models that ignore "output the title and nothing else" tend to answer
      // on two lines. Showing both would put a paragraph in a list row.
      expect(clean('Rust 所有权\n\n这个标题描述了借用检查器。'), 'Rust 所有权');
      expect(clean('Here is a title:\nRust ownership'), 'Rust ownership');
      expect(clean('标题：关于异步的讨论'), '关于异步的讨论');
      expect(clean('Sure!\nRust ownership'), 'Rust ownership');
    });

    test('empty and unusable input yields null', () {
      expect(clean(null), isNull);
      expect(clean(''), isNull);
      expect(clean('   '), isNull);
      // Stripped down to nothing but punctuation and quotes.
      expect(clean('""'), isNull);
      expect(clean('「」'), isNull);
    });

    test('a long title is cut on a character boundary', () {
      final long = 'a' * 200;
      expect(clean(long)!.runes.length, 40);
      // A cut in the middle of a 3-byte rune produces replacement characters.
      final cjk = '模' * 200;
      final cut = clean(cjk)!;
      expect(cut.runes.length, 40);
      expect(cut.contains('�'), isFalse);
    });

    // Both scripts are short by different measures — a Latin title is short in
    // words, a CJK one in characters — so the cut is measured in code points,
    // which is the unit that cannot land inside a rune.
    test('a CJK title under the cap is untouched', () {
      expect(clean('关于 Flutter 渲染管线'), '关于 Flutter 渲染管线');
    });
  });
}
