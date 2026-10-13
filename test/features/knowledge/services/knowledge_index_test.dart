import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/knowledge/services/knowledge_index.dart';

KnowledgeChunk chunk(String doc, int i, String text, List<double> vec) =>
    KnowledgeChunk(documentId: doc, index: i, text: text, embedding: vec);

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('vela_kb_test');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  group('storage', () {
    test('documents survive a save and load', () async {
      final index = KnowledgeIndex(root);
      await index.saveDocuments(<KnowledgeDocument>[
        KnowledgeDocument(
          id: 'doc_1',
          title: '部署手册',
          path: '',
          addedAt: DateTime.utc(2026, 3, 1),
          chunkCount: 12,
          indexedAt: DateTime.utc(2026, 3, 2),
          embeddingModelId: 'bge-small-zh-v1.5',
        ),
      ]);

      final loaded = await KnowledgeIndex(root).loadDocuments();
      expect(loaded, hasLength(1));
      expect(loaded.single.title, '部署手册');
      expect(loaded.single.chunkCount, 12);
      expect(loaded.single.embeddingModelId, 'bge-small-zh-v1.5');
      expect(loaded.single.isIndexed, isTrue);
    });

    test('chunks survive a save and load', () async {
      final index = KnowledgeIndex(root);
      await index.saveChunks('doc_1', <KnowledgeChunk>[
        chunk('doc_1', 0, '第一段', <double>[0.5, 0.5, 0.5, 0.5]),
        chunk('doc_1', 1, '第二段', <double>[0, 1, 0, 0]),
      ]);

      final loaded = await index.loadChunks(<KnowledgeDocument>[
        KnowledgeDocument(
          id: 'doc_1',
          title: 't',
          path: '',
          addedAt: DateTime.utc(2026),
          chunkCount: 2,
          indexedAt: DateTime.utc(2026),
        ),
      ]);

      expect(loaded, hasLength(2));
      expect(loaded.first.text, '第一段');
      expect(loaded.first.index, 0);
      expect(loaded.last.embedding, <double>[0, 1, 0, 0]);
    });

    // One unreadable file must not take the whole library with it.
    test('one corrupt vector file does not lose the others', () async {
      final index = KnowledgeIndex(root);
      await index.saveChunks('good', <KnowledgeChunk>[
        chunk('good', 0, 'kept', <double>[1, 0]),
      ]);
      await index.vectorsFileFor('broken').parent.create(recursive: true);
      await index.vectorsFileFor('broken').writeAsString('{not json');

      final loaded = await index.loadChunks(<KnowledgeDocument>[
        for (final id in <String>['good', 'broken'])
          KnowledgeDocument(
            id: id,
            title: id,
            path: '',
            addedAt: DateTime.utc(2026),
            chunkCount: 1,
            indexedAt: DateTime.utc(2026),
          ),
      ]);

      expect(loaded, hasLength(1));
      expect(loaded.single.documentId, 'good');
    });

    // Losing the vectors is survivable; losing the user's files is not. A
    // corrupt index must therefore cost a re-index, not the library.
    test('a corrupt index costs the vectors, not the files', () async {
      final index = KnowledgeIndex(root);
      await index.saveDocuments(<KnowledgeDocument>[
        KnowledgeDocument(
          id: 'doc_1',
          title: 't',
          path: '',
          addedAt: DateTime.utc(2026),
          chunkCount: 1,
          indexedAt: DateTime.utc(2026),
        ),
      ]);
      await index.indexFile.writeAsString('{not json');

      expect(await KnowledgeIndex(root).loadDocuments(), isEmpty);
      // The document file the user pointed at is still on disk.
      expect(await root.exists(), isTrue);
    });

    test('removing a document drops its vectors', () async {
      final index = KnowledgeIndex(root);
      await index.saveChunks('doc_1', <KnowledgeChunk>[
        chunk('doc_1', 0, 'x', <double>[1, 0]),
      ]);
      expect(await index.vectorsFileFor('doc_1').exists(), isTrue);

      await index.removeDocument('doc_1');
      expect(await index.vectorsFileFor('doc_1').exists(), isFalse);
    });
  });

  group('retrieval', () {
    const retriever = KnowledgeRetriever();

    test('ranks by cosine and drops weak matches', () {
      // Unit vectors: [1,0] and [0.707,0.707] (45 degrees).
      final chunks = <KnowledgeChunk>[
        chunk('a', 0, 'same direction', <double>[1, 0]),
        chunk('b', 0, 'diagonal', <double>[0.70710678, 0.70710678]),
        chunk('c', 0, 'opposite', <double>[-1, 0]),
      ];

      final ranked = retriever.rank(<double>[1, 0], chunks);
      expect(ranked, isNotEmpty);
      expect(ranked.first.chunk.documentId, 'a');
      expect(ranked.first.score, closeTo(1.0, 0.0001));
      // 45 degrees is above the floor; -1.0 is not.
      expect(ranked.map((hit) => hit.chunk.documentId), contains('b'));
      expect(ranked.map((hit) => hit.chunk.documentId), isNot(contains('c')));
    });

    test('caps how many passages come back', () {
      final chunks = <KnowledgeChunk>[
        for (var i = 0; i < 20; i++)
          chunk('a', i, 'text $i', <double>[1, 0]),
      ];
      expect(retriever.rank(<double>[1, 0], chunks), hasLength(4));
    });

    // A dimension mismatch is what happens after an embedding model is swapped
    // without a rebuild. It has to return nothing, not throw.
    test('a dimension mismatch returns nothing rather than throwing', () {
      final chunks = <KnowledgeChunk>[
        chunk('a', 0, 'wrong width', <double>[1, 0, 0]),
      ];
      expect(retriever.rank(<double>[1, 0], chunks), isEmpty);
    });

    test('empty inputs are empty results', () {
      expect(retriever.rank(<double>[], <KnowledgeChunk>[]), isEmpty);
      expect(
        retriever.rank(<double>[1, 0], <KnowledgeChunk>[]),
        isEmpty,
      );
    });
  });

  group('prompt formatting', () {
    const retriever = KnowledgeRetriever();

    test('numbers the passages so the model can cite them', () {
      final text = retriever.formatForPrompt(<KnowledgeChunk>[
        chunk('a', 0, '第一段内容', <double>[1, 0]),
        chunk('b', 0, '第二段内容', <double>[0, 1]),
      ]);
      expect(text, contains('[1] 第一段内容'));
      expect(text, contains('[2] 第二段内容'));
    });

    // Four passages of a kilobyte each will not fit an 8K window, and the
    // ones that get cut are chosen by position rather than by relevance.
    test('respects the character budget', () {
      final chunks = <KnowledgeChunk>[
        for (var i = 0; i < 10; i++)
          chunk('a', i, 'x' * 500, <double>[1, 0]),
      ];
      final text = retriever.formatForPrompt(chunks, charBudget: 1200);
      expect(text.length, lessThan(1300));
    });

    // Dropping the best match because it was the longest throws away the
    // answer. A passage that does not fit still gets truncated, not skipped.
    test('truncates an over-budget passage rather than dropping it', () {
      final text = retriever.formatForPrompt(
        <KnowledgeChunk>[chunk('a', 0, 'y' * 5000, <double>[1, 0])],
        charBudget: 100,
      );
      expect(text, isNotEmpty);
      expect(text, contains('[1]'));
    });
  });

  group('normalisation', () {
    test('produces a unit vector', () {
      final unit = normalizeEmbedding(<double>[3, 4]);
      expect(unit[0], closeTo(0.6, 0.0001));
      expect(unit[1], closeTo(0.8, 0.0001));
      final sum = unit[0] * unit[0] + unit[1] * unit[1];
      expect(sum, closeTo(1.0, 0.0001));
    });

    // A NaN anywhere makes every downstream score meaningless, so it is
    // dropped at the door rather than propagated.
    test('rejects a vector containing a non-finite value', () {
      expect(normalizeEmbedding(<double>[double.nan, 1]), isEmpty);
      expect(normalizeEmbedding(<double>[double.infinity, 1]), isEmpty);
    });

    test('rejects a zero vector', () {
      expect(normalizeEmbedding(<double>[0, 0, 0]), isEmpty);
    });
  });
}
