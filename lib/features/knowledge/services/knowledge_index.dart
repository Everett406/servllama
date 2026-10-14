import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;


/// One indexed piece of a document.
class KnowledgeChunk {
  const KnowledgeChunk({
    required this.documentId,
    required this.index,
    required this.text,
    required this.embedding,
  });

  final String documentId;

  /// Position within the document, so a result can cite a passage rather than
  /// just a file.
  final int index;
  final String text;

  /// Unit-normalised at write time, so retrieval is a plain dot product and
  /// cannot accidentally score by magnitude.
  final List<double> embedding;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'd': documentId,
    'i': index,
    't': text,
    'e': embedding,
  };

  factory KnowledgeChunk.fromJson(Map<String, dynamic> json) {
    return KnowledgeChunk(
      documentId: (json['d'] ?? '').toString(),
      index: (json['i'] as num?)?.toInt() ?? 0,
      text: (json['t'] ?? '').toString(),
      embedding: (json['e'] as List?)
              ?.map((value) => (value as num).toDouble())
              .toList() ??
          const <double>[],
    );
  }
}

/// A document in the library, with the index state that goes with it.
class KnowledgeDocument {
  const KnowledgeDocument({
    required this.id,
    required this.title,
    required this.path,
    required this.addedAt,
    required this.chunkCount,
    required this.indexedAt,
    this.embeddingModelId,
    this.error,
  });

  final String id;
  final String title;
  final String path;
  final DateTime addedAt;
  final int chunkCount;
  final DateTime indexedAt;

  /// The embedding model the stored vectors were produced by. Indexes are not
  /// comparable across models, so this is what makes switching one require a
  /// rebuild rather than silently answering from a mismatched vector space.
  final String? embeddingModelId;

  /// Why this document has no vectors. Shown rather than swallowed: a
  /// document that silently never indexed is worse than one that failed
  /// loudly.
  final String? error;

  bool get isIndexed => error == null && chunkCount > 0;

  KnowledgeDocument copyWith({
    String? title,
    int? chunkCount,
    DateTime? indexedAt,
    String? embeddingModelId,
    String? error,
    bool clearError = false,
  }) {
    return KnowledgeDocument(
      id: id,
      title: title ?? this.title,
      path: path,
      addedAt: addedAt,
      chunkCount: chunkCount ?? this.chunkCount,
      indexedAt: indexedAt ?? this.indexedAt,
      embeddingModelId: embeddingModelId ?? this.embeddingModelId,
      error: clearError ? null : (error ?? this.error),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'path': path,
    'addedAt': addedAt.toIso8601String(),
    'chunkCount': chunkCount,
    'indexedAt': indexedAt.toIso8601String(),
    if (embeddingModelId != null) 'model': embeddingModelId,
    if (error != null) 'error': error,
  };

  factory KnowledgeDocument.fromJson(Map<String, dynamic> json) {
    return KnowledgeDocument(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      path: (json['path'] ?? '').toString(),
      addedAt:
          DateTime.tryParse((json['addedAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      chunkCount: (json['chunkCount'] as num?)?.toInt() ?? 0,
      indexedAt:
          DateTime.tryParse((json['indexedAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      embeddingModelId: json['model'] as String?,
      error: json['error'] as String?,
    );
  }
}

/// On-disk knowledge base: a directory of documents and a JSON index beside
/// them.
///
/// Plain JSON rather than a database. The whole thing is a few hundred
/// kilobytes for a realistic library, it has to be readable when something
/// goes wrong, and a user who wants to delete their index does it by
/// deleting a folder.
class KnowledgeIndex {
  KnowledgeIndex(this.rootDirectory);

  final Directory rootDirectory;

  /// Path joining by hand rather than through `package:path`, which is only a
  /// transitive dependency here. The knowledge base is four directories deep at
  /// most, so this is not where a dependency is worth adding.
  static String join(List<String> parts) =>
      parts.where((part) => part.isNotEmpty).join('/');

  Directory get documentsDirectory =>
      Directory(join(<String>[rootDirectory.path, 'documents']));

  File get indexFile => File(join(<String>[rootDirectory.path, 'index.json']));

  static const String currentIndexVersion = '1';

  Future<List<KnowledgeDocument>> loadDocuments() async {
    if (!await indexFile.exists()) return const <KnowledgeDocument>[];
    try {
      final decoded = jsonDecode(await indexFile.readAsString());
      if (decoded is! Map) return const <KnowledgeDocument>[];
      final documents = decoded['documents'];
      if (documents is! List) return const <KnowledgeDocument>[];
      return documents
          .whereType<Map>()
          .map((entry) => KnowledgeDocument.fromJson(entry.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      // A corrupt index costs the user their library's *vectors*, not their
      // files: the documents are still on disk and can be re-indexed.
      return const <KnowledgeDocument>[];
    }
  }

  Future<void> saveDocuments(List<KnowledgeDocument> documents) async {
    await rootDirectory.create(recursive: true);
    final payload = <String, dynamic>{
      'version': currentIndexVersion,
      'documents': documents.map((document) => document.toJson()).toList(),
    };
    await indexFile.writeAsString(jsonEncode(payload), flush: true);
  }

  File vectorsFileFor(String documentId) =>
      File(join(<String>[rootDirectory.path, 'vectors', '$documentId.json']));

  /// Every vector in the library, flattened with its chunk.
  ///
  /// Loads documents in order rather than caching, because the library is
  /// edited from a page the user is looking at and a cache would then answer
  /// from an index the UI has already changed.
  Future<List<KnowledgeChunk>> loadChunks(
    List<KnowledgeDocument> documents,
  ) async {
    final chunks = <KnowledgeChunk>[];
    for (final document in documents) {
      if (!document.isIndexed) continue;
      final file = vectorsFileFor(document.id);
      if (!await file.exists()) continue;
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is! List) continue;
        for (final entry in decoded.whereType<Map>()) {
          chunks.add(
            KnowledgeChunk.fromJson(entry.cast<String, dynamic>()),
          );
        }
      } catch (_) {
        // One unreadable file must not take the whole library with it.
        continue;
      }
    }
    return chunks;
  }

  Future<void> saveChunks(String documentId, List<KnowledgeChunk> chunks) async {
    final file = vectorsFileFor(documentId);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(chunks.map((chunk) => chunk.toJson()).toList()),
      flush: true,
    );
  }

  Future<void> removeDocument(String documentId) async {
    final file = vectorsFileFor(documentId);
    if (await file.exists()) await file.delete();
  }
}

/// Ranks chunks against a query embedding.
class KnowledgeRetriever {
  const KnowledgeRetriever({
    this.minScore = 0.28,
    this.maxChunks = 4,
    this.charBudget = 2000,
    this.perChunkChars = 600,
  });

  /// Below this, the passage is noise. Set deliberately high: handing a model
  /// a paragraph that has nothing to do with the question produces a confident
  /// answer built out of nothing, which is worse than no retrieval at all.
  final double minScore;

  /// How many passages to return. Four is enough to cover a question with
  /// facets and few enough that they fit the prompt without crowding it.
  final int maxChunks;

  /// Total characters across every passage.
  final int charBudget;

  /// Characters from one passage before it is cut.
  final int perChunkChars;

  /// Rank [chunks] by cosine similarity to [query].
  ///
  /// Vectors are stored unit-length, so the dot product *is* the cosine and
  /// there is no second pass to normalise. A dimension mismatch returns
  /// nothing rather than throwing: that is what happens after an embedding
  /// model is swapped without a rebuild, and it has to be survivable.
  List<({KnowledgeChunk chunk, double score})> rank(
    List<double> query,
    List<KnowledgeChunk> chunks,
  ) {
    if (query.isEmpty || chunks.isEmpty) {
      return const <({KnowledgeChunk chunk, double score})>[];
    }
    final scored = <({KnowledgeChunk chunk, double score})>[];
    for (final chunk in chunks) {
      if (chunk.embedding.length != query.length) continue;
      var dot = 0.0;
      for (var i = 0; i < query.length; i++) {
        dot += query[i] * chunk.embedding[i];
      }
      if (dot >= minScore) scored.add((chunk: chunk, score: dot));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(maxChunks).toList();
  }

  /// Format ranked passages for the model.
  ///
  /// Capped in *characters*, not chunks: four passages of a kilobyte each will
  /// not fit an 8K window, and the ones that get truncated are chosen by
  /// position rather than by relevance. Two thousand characters is roughly a
  /// quarter of that window, leaving room for the question and the answer.
  String formatForPrompt(List<KnowledgeChunk> chunks) {
    final buffer = StringBuffer();
    var used = 0;
    for (var i = 0; i < chunks.length; i++) {
      final text = chunks[i].text.trim();
      if (text.isEmpty) continue;

      // Each passage is cut at its own limit first, so one long chunk cannot
      // eat the whole budget and leave the rest of the list unrepresented.
      final slice = text.length <= perChunkChars
          ? text
          : text.substring(0, perChunkChars);
      if (slice.trim().isEmpty) break;

      // ...and then the total is respected. The first passage always gets at
      // least something: dropping the best match because it was the longest
      // throws away the answer.
      final remaining = charBudget - used;
      final finalSlice = slice.length <= remaining
          ? slice
          : slice.substring(0, remaining.clamp(0, slice.length));
      if (finalSlice.trim().isEmpty) break;

      buffer.write('[${i + 1}] $finalSlice\n\n');
      used += finalSlice.length;
      if (used >= charBudget) break;
    }
    return buffer.toString().trim();
  }
}

/// Unit-normalise a vector, dropping anything that is not finite.
List<double> normalizeEmbedding(List<double> vector) {
  var sum = 0.0;
  for (final value in vector) {
    if (!value.isFinite) return const <double>[];
    sum += value * value;
  }
  if (sum <= 0) return const <double>[];
  final norm = math.sqrt(sum);
  return vector.map((value) => value / norm).toList();
}
