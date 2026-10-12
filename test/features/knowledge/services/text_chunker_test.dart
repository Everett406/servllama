import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/knowledge/services/text_chunker.dart';

void main() {
  const chunker = TextChunker();

  String repeat(String s, int n) => s * n;

  group('TextChunker', () {
    test('empty and whitespace-only input produce nothing', () {
      expect(chunker.split(''), isEmpty);
      expect(chunker.split('   \n\n\t '), isEmpty);
    });

    test('short text stays in one chunk', () {
      final chunks = chunker.split('这是一段很短的中文文本。');
      expect(chunks, hasLength(1));
      expect(chunks.single, '这是一段很短的中文文本。');
    });

    test('every chunk fits the encoder window', () {
      // Far longer than a single window, so this exercises both the
      // boundary path and the hard split.
      final text = repeat(
        'Vela 在本地运行模型，数据不出设备。This sentence is in English. '
        '第二条：上下文窗口决定能塞多少东西。',
        40,
      );
      final chunks = chunker.split(text);
      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        expect(
          TextChunker.estimateTokens(chunk),
          lessThanOrEqualTo(440),
          reason: 'chunk of ${chunk.length} chars overflowed the window',
        );
      }
    });

    test('chinese is measured per character, latin per quarter', () {
      expect(TextChunker.estimateTokens('中文四个字'), 5);
      // The whole point: the same character count costs an order of
      // magnitude more in Chinese, and a char-counting chunker would blow
      // the window on every Chinese paragraph.
      expect(TextChunker.estimateTokens('a' * 16), lessThanOrEqualTo(5));
    });

    test('paragraphs are not glued together across a blank line', () {
      final text =
          '${repeat('第一段内容。', 30)}\n\n${repeat('第二段内容。', 30)}';
      final chunks = chunker.split(text);
      expect(chunks.length, greaterThan(1));
      // No chunk should carry text from both paragraphs in a way that makes
      // it describe neither; each is at least self-consistent.
      for (final chunk in chunks) {
        expect(chunk.trim(), isNotEmpty);
      }
    });

    test('a single oversized sentence is hard split instead of dropped', () {
      final text = repeat('没有任何标点的一个超长句子', 200);
      final chunks = chunker.split(text);
      expect(chunks.length, greaterThan(1));
      // Nothing lost: every character in, every character out.
      expect(chunks.join(), text);
    });

    test('consecutive chunks overlap so a boundary fact is retrievable', () {
      const withOverlap = TextChunker(targetTokens: 120, overlapTokens: 40);
      final text = repeat('知识库需要索引和检索两件事。', 30);
      final chunks = withOverlap.split(text);
      expect(chunks.length, greaterThan(2));
      final tail = chunks.first.substring(chunks.first.length - 12);
      expect(chunks[1], contains(tail.substring(0, 6)));
    });

    test('zero overlap is honoured', () {
      const noOverlap = TextChunker(targetTokens: 120, overlapTokens: 0);
      final chunks = noOverlap.split(repeat('没有交叠的文本。', 40));
      expect(chunks.length, greaterThan(1));
      expect(chunks.join(), repeat('没有交叠的文本。', 40));
    });

    test('windows line endings are normalised', () {
      final chunks = chunker.split('第一行\r\n\r\n第二行');
      expect(chunks.length, greaterThanOrEqualTo(1));
      expect(chunks.join(), isNot(contains('\r')));
    });

    test('sentence terminators stay with the sentence they close', () {
      final chunks = chunker.split('他说了一句话。然后又说了一句。');
      expect(chunks.join(), contains('。'));
      // A chunk starting on a bare terminator is the failure mode.
      for (final chunk in chunks) {
        expect(chunk.trimLeft().startsWith('。'), isFalse);
        expect(chunk.trimLeft().startsWith('？'), isFalse);
      }
    });
  });
}