import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/features/chat/services/builtin_tools.dart';
import 'package:servllama/features/knowledge/models/embedding_model_descriptor.dart';
import 'package:servllama/features/knowledge/services/knowledge_base_service.dart';
import 'package:servllama/features/knowledge/services/knowledge_index.dart';

/// Owns the knowledge base and wires it into the tool the model can call.
///
/// Documents are imported as **text**, not copied as files. The original
/// stays where the user put it, so deleting it from the knowledge base does
/// not quietly take a file with it, and there is no second copy of a library
/// that might be large.
class KnowledgeBaseProvider extends ChangeNotifier {
  KnowledgeBaseProvider({KnowledgeBaseService? service})
    : _service = service;

  KnowledgeBaseService? _service;

  KnowledgeBaseService? get service => _service;

  bool _loaded = false;
  bool _busy = false;
  String? _lastError;

  bool get isLoaded => _loaded;
  bool get isBusy => _busy;
  String? get lastError => _lastError;

  /// Whether retrieval is on. Off means the tool is not advertised behaviour:
  /// the search tool returns nothing and the model answers unaided.
  bool _retrievalEnabled = true;

  bool get retrievalEnabled => _retrievalEnabled;

  /// Whether the model decides when to search, or retrieval always runs.
  bool _modelDecides = true;

  bool get modelDecides => _modelDecides;

  List<KnowledgeDocument> get documents =>
      _service?.documents ?? const <KnowledgeDocument>[];

  bool get hasIndexedDocuments => _service?.hasIndexedDocuments ?? false;

  /// The embedding model the stored vectors belong to.
  String? get indexedEmbeddingModelId => _service?.indexedEmbeddingModelId;

  /// True when the vectors on disk were made by a different model and have to
  /// be rebuilt before a search can mean anything.
  bool needsRebuild(EmbeddingModelDescriptor model) =>
      _service?.needsRebuildFor(model.id) ?? false;

  /// Where the library lives on disk, for the page to show.
  Future<Directory> rootDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    return Directory('${base.path}/kb');
  }

  Future<void> load() async {
    if (_service == null) {
      final directory = await rootDirectory();
      await directory.create(recursive: true);
      _service = KnowledgeBaseService(
        index: KnowledgeIndex(directory),
        embeddings: EmbeddingClient(),
      );
    }
    await _service!.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> setRetrievalEnabled(bool enabled) async {
    if (_retrievalEnabled == enabled) return;
    _retrievalEnabled = enabled;
    notifyListeners();
  }

  Future<void> setModelDecides(bool modelDecides) async {
    if (_modelDecides == modelDecides) return;
    _modelDecides = modelDecides;
    notifyListeners();
  }

  /// Import a file the user picked.
  ///
  /// Only plain text and Markdown in this version. PDF is deferred rather than
  /// half-done — a PDF that indexes to empty strings is worse than a clear
  /// "not yet".
  Future<KnowledgeDocument?> importFile({
    required String path,
    required EmbeddingModelDescriptor model,
    required EngineRuntimeProvider runtime,
  }) async {
    final service = _service;
    if (service == null) return null;

    final lower = path.toLowerCase();
    if (!lower.endsWith('.md') &&
        !lower.endsWith('.txt') &&
        !lower.endsWith('.markdown')) {
      _lastError = 'Only .md and .txt are supported for now.';
      notifyListeners();
      return null;
    }

    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      final text = await File(path).readAsString();
      final document = await service.addText(
        title: path.split('/').last,
        text: text,
        embeddingModelId: model.id,
        baseUrl: runtime.baseUrl,
      );
      return document;
    } catch (error) {
      _lastError = '$error';
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> remove(String documentId) async {
    await _service?.remove(documentId);
    notifyListeners();
  }

  /// Drop every vector and re-index the whole library against [model].
  Future<void> rebuild(EmbeddingModelDescriptor model) async {
    final service = _service;
    if (service == null) return;
    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      await service.clearIndex();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// The search the `knowledge_search` tool performs.
  ///
  /// Returns an empty string when there is nothing to offer. That is the
  /// signal the model gets to answer unaided rather than being handed nothing
  /// and improvising around it.
  Future<String> search(
    String query, {
    required EngineRuntimeProvider runtime,
    required EmbeddingModelDescriptor model,
  }) async {
    final service = _service;
    if (!_retrievalEnabled || service == null) return '';
    if (!service.hasIndexedDocuments) return '';
    try {
      return await service.search(
        query: query,
        embeddingModelId: model.id,
        baseUrl: runtime.baseUrl,
      );
    } catch (error) {
      debugPrint('KnowledgeBaseProvider.search: $error');
      return '';
    }
  }

  /// A tool wired to this library, or null when retrieval is off.
  ///
  /// Null rather than a tool that returns nothing: advertising a search that
  /// always comes back empty teaches the model to call a useless tool.
  BuiltinTools? toolsFor(
    EngineRuntimeProvider runtime,
    EmbeddingModelDescriptor model,
  ) {
    if (!_retrievalEnabled || !hasIndexedDocuments) return null;
    return BuiltinTools(
      searchKnowledge: (query) =>
          search(query, runtime: runtime, model: model),
    );
  }
}
