import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:servllama/features/knowledge/services/knowledge_index.dart';
import 'package:servllama/features/knowledge/services/text_chunker.dart';

/// Talks to llama-server's `/v1/embeddings`.
///
/// The embedding model runs inside the same llama-server the chat model runs
/// in — not a second process. A 26 MB model is not worth a second copy of the
/// runtime, the second port, and the second thing that can be left running.
class EmbeddingClient {
  EmbeddingClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  /// Embed [inputs], in order.
  ///
  /// Batched because a phone pays per-request overhead, and a document with
  /// forty chunks would otherwise be forty round trips to localhost.
  Future<List<List<double>>> embed({
    required List<String> inputs,
    required String baseUrl,
    String? apiKey,
    CancelToken? cancelToken,
    int batchSize = 8,
  }) async {
    if (inputs.isEmpty) return const <List<double>>[];

    final results = <List<double>>[];
    for (var start = 0; start < inputs.length; start += batchSize) {
      final end = (start + batchSize).clamp(0, inputs.length);
      final batch = inputs.sublist(start, end);
      final response = await _dio.post<dynamic>(
        '$baseUrl/v1/embeddings',
        data: <String, dynamic>{
          'model': currentEmbeddingModelId ?? '',
          'input': batch,
        },
        cancelToken: cancelToken,
        options: Options(
          headers: <String, String>{
            'Content-Type': 'application/json',
            if (apiKey != null && apiKey.isNotEmpty)
              'Authorization': 'Bearer $apiKey',
          },
        ),
      );

      final data = response.data;
      if (data is! Map) continue;
      final items = data['data'];
      if (items is! List) continue;

      // The API returns them indexed, not in request order. Trusting the
      // array order instead silently mislabels every vector after the first.
      final byIndex = <int, List<double>>{};
      for (final item in items.whereType<Map>()) {
        final index = (item['index'] as num?)?.toInt();
        final vector = item['embedding'];
        if (index == null || vector is! List) continue;
        byIndex[index] = vector
            .map((value) => (value as num).toDouble())
            .toList();
      }
      for (var i = 0; i < batch.length; i++) {
        final vector = byIndex[i];
        if (vector != null) results.add(normalizeEmbedding(vector));
      }
    }
    return results;
  }

  /// Which embedding model the server currently has loaded.
  ///
  /// Public because it decides whether a search can work at all: asking for
  /// vectors from a server that has a chat model loaded returns nothing, and
  /// the honest answer is "nothing" rather than a wrong number.
  String? currentEmbeddingModelId;

  /// What the server reports as loaded, for the "rebuild needed" check.
  Future<String?> queryLoadedModel({required String baseUrl, String? apiKey}) async {
    try {
      final response = await _dio.get<dynamic>(
        '$baseUrl/v1/models',
        options: Options(
          headers: <String, String>{
            if (apiKey != null && apiKey.isNotEmpty)
              'Authorization': 'Bearer $apiKey',
          },
        ),
      );
      final data = response.data;
      if (data is! Map) return null;
      final models = data['data'];
      if (models is! List || models.isEmpty) return null;
      final first = models.first;
      if (first is! Map) return null;
      return first['id'] as String?;
    } catch (_) {
      // The server being unreachable is the caller's problem to report; here
      // it only means "cannot tell", which is not the same as "changed".
      return null;
    }
  }
}

/// Adds documents, indexes them, and answers searches.
class KnowledgeBaseService {
  KnowledgeBaseService({
    required KnowledgeIndex index,
    required EmbeddingClient embeddings,
    TextChunker chunker = const TextChunker(),
    KnowledgeRetriever retriever = const KnowledgeRetriever(),
  }) : _index = index,
       _embeddings = embeddings,
       _chunker = chunker,
       _retriever = retriever;

  final KnowledgeIndex _index;
  final EmbeddingClient _embeddings;
  final TextChunker _chunker;
  final KnowledgeRetriever _retriever;

  KnowledgeRetriever get retriever => _retriever;

  List<KnowledgeDocument> _documents = const <KnowledgeDocument>[];
  bool _loaded = false;

  List<KnowledgeDocument> get documents => List<KnowledgeDocument>.unmodifiable(_documents);
  bool get isLoaded => _loaded;

  /// Whether the library has anything worth searching.
  bool get hasIndexedDocuments => _documents.any((document) => document.isIndexed);

  /// The embedding model the stored vectors were produced with, when they all
  /// agree.
  String? get indexedEmbeddingModelId {
    final ids = _documents
        .where((document) => document.isIndexed)
        .map((document) => document.embeddingModelId)
        .whereType<String>()
        .toSet();
    // A library with vectors from two models is not comparable with itself.
    return ids.length == 1 ? ids.first : null;
  }

  Future<void> load() async {
    _documents = await _index.loadDocuments();
    _loaded = true;
  }

  /// Index [text] as a document titled [title].
  ///
  /// The caller passes text rather than a path because decoding is where the
  /// formats differ, and that decision belongs next to the file it is about.
  Future<KnowledgeDocument> addText({
    required String title,
    required String text,
    required String embeddingModelId,
    required String baseUrl,
    String? apiKey,
    CancelToken? cancelToken,
  }) async {
    final now = DateTime.now();
    final id = 'doc_${now.microsecondsSinceEpoch}';
    final document = KnowledgeDocument(
      id: id,
      title: title,
      path: '',
      addedAt: now,
      chunkCount: 0,
      indexedAt: now,
    );

    final chunks = _chunker.split(text);
    if (chunks.isEmpty) {
      final failed = document.copyWith(
        error: 'The document has no text to index.',
        embeddingModelId: embeddingModelId,
      );
      _documents = <KnowledgeDocument>[..._documents, failed];
      await _index.saveDocuments(_documents);
      return failed;
    }

    try {
      final vectors = await _embeddings.embed(
        inputs: chunks,
        baseUrl: baseUrl,
        apiKey: apiKey,
        cancelToken: cancelToken,
      );
      if (vectors.length != chunks.length) {
        throw StateError(
          'the server returned ${vectors.length} vectors for ${chunks.length} chunks',
        );
      }
      final stored = <KnowledgeChunk>[
        for (var i = 0; i < chunks.length; i++)
          KnowledgeChunk(
            documentId: id,
            index: i,
            text: chunks[i],
            embedding: vectors[i],
          ),
      ];
      await _index.saveChunks(id, stored);

      final indexed = document.copyWith(
        chunkCount: stored.length,
        embeddingModelId: embeddingModelId,
      );
      _documents = <KnowledgeDocument>[..._documents, indexed];
      await _index.saveDocuments(_documents);
      return indexed;
    } catch (error) {
      // Kept in the list with the reason attached rather than dropped: a
      // document that silently never indexed is worse than one that failed
      // where the user can see it.
      final failed = document.copyWith(
        error: '$error',
        embeddingModelId: embeddingModelId,
      );
      _documents = <KnowledgeDocument>[..._documents, failed];
      await _index.saveDocuments(_documents);
      return failed;
    }
  }

  Future<void> remove(String documentId) async {
    _documents = _documents
        .where((document) => document.id != documentId)
        .toList();
    await _index.removeDocument(documentId);
    await _index.saveDocuments(_documents);
  }

  /// Drop every vector and keep the files.
  ///
  /// Needed whenever the embedding model changes: vectors from two models are
  /// not comparable, and answering from a mixed index produces confident
  /// nonsense.
  Future<void> clearIndex() async {
    for (final document in _documents) {
      await _index.removeDocument(document.id);
    }
    _documents = _documents
        .map(
          (document) => document.copyWith(chunkCount: 0, clearError: true),
        )
        .toList();
    await _index.saveDocuments(_documents);
  }

  /// Find passages for [query].
  ///
  /// Returns an empty string when there is nothing to offer, which is the
  /// signal the tool passes to the model as "answer without this".
  Future<String> search({
    required String query,
    required String embeddingModelId,
    required String baseUrl,
    String? apiKey,
    CancelToken? cancelToken,
  }) async {
    if (!hasIndexedDocuments) return '';

    final vectors = await _embeddings.embed(
      inputs: <String>[query],
      baseUrl: baseUrl,
      apiKey: apiKey,
      cancelToken: cancelToken,
    );
    if (vectors.isEmpty) return '';

    final stored = await _index.loadChunks(_documents);
    final ranked = _retriever.rank(vectors.first, stored);
    if (ranked.isEmpty) return '';

    final titles = <String, String>{
      for (final document in _documents) document.id: document.title,
    };
    final passages = <KnowledgeChunk>[
      for (final hit in ranked)
        KnowledgeChunk(
          documentId: hit.chunk.documentId,
          index: hit.chunk.index,
          text: '${titles[hit.chunk.documentId] ?? hit.chunk.documentId}'
              '\n${hit.chunk.text}',
          embedding: hit.chunk.embedding,
        ),
    ];
    return _retriever.formatForPrompt(passages);
  }

  /// Whether the library has to be rebuilt for [modelId].
  bool needsRebuildFor(String modelId) {
    final indexed = indexedEmbeddingModelId;
    return indexed != null && indexed != modelId;
  }

  /// The library as JSON, for a settings page to show sizes.
  String statsJson() => jsonEncode(<String, dynamic>{
    'documents': _documents.length,
    'chunks': _documents.fold<int>(0, (sum, d) => sum + d.chunkCount),
  });
}
