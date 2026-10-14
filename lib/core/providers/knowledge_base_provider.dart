import 'dart:io';

import 'package:dio/dio.dart';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:servllama/features/chat/services/builtin_tools.dart';
import 'package:servllama/features/knowledge/models/embedding_model_descriptor.dart';
import 'package:servllama/features/knowledge/models/retrieval_settings.dart';
import 'package:servllama/features/knowledge/services/embedding_model_store.dart';
import 'package:servllama/features/knowledge/services/embedding_server.dart';
import 'package:servllama/features/knowledge/services/knowledge_base_service.dart';
import 'package:servllama/features/knowledge/services/knowledge_index.dart';

/// Owns the knowledge base and wires it into the tool the model can call.
///
/// Documents are imported as **text**, not copied as files. The original
/// stays where the user put it, so deleting it from the knowledge base does
/// not quietly take a file with it, and there is no second copy of a library
/// that might be large.
class KnowledgeBaseProvider extends ChangeNotifier {
  KnowledgeBaseProvider({
    KnowledgeBaseService? service,
    EmbeddingModelStore? modelStore,
    EmbeddingServer? embeddingServer,
    RetrievalSettingsStore? settingsStore,
  }) : _service = service,
       _modelStore = modelStore ?? EmbeddingModelStore(),
       _embeddingServer = embeddingServer ?? EmbeddingServer(),
       _settingsStore = settingsStore ?? RetrievalSettingsStore();

  KnowledgeBaseService? _service;
  final EmbeddingModelStore _modelStore;
  final EmbeddingServer _embeddingServer;
  final RetrievalSettingsStore _settingsStore;

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

  /// True when the vectors on disk were made by a different model than the one
  /// now selected, and every stored vector is therefore unusable.
  bool get needsRebuild {
    final selected = selectedModel?.id;
    if (selected == null) return false;
    return _service?.needsRebuildFor(selected) ?? false;
  }

  /// Where the library lives on disk, for the page to show.
  Future<Directory> rootDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    return Directory('${base.path}/kb');
  }

  // ---- embedding model -------------------------------------------------

  EmbeddingModelStore get modelStore => _modelStore;
  EmbeddingServer get embeddingServer => _embeddingServer;

  List<InstalledEmbeddingModel> _models = const <InstalledEmbeddingModel>[];
  List<InstalledEmbeddingModel> get models => _models;

  InstalledEmbeddingModel? get selectedModel {
    final path = _modelStore.selectedPath;
    if (path == null) return null;
    for (final model in _models) {
      if (model.path == path) return model;
    }
    // The selection points at a file that is gone. Saying so beats silently
    // falling back to some other model and answering from the wrong vectors.
    return null;
  }

  bool get hasModel => _modelStore.selectedPath != null;

  /// Download progress for the model currently downloading, 0..1.
  double? get downloadProgress => _downloadProgress;
  double? _downloadProgress;

  Future<void> refreshModels() async {
    _models = await _modelStore.installed();
    notifyListeners();
  }

  Future<void> selectModel(InstalledEmbeddingModel model) async {
    await _modelStore.select(model);
    // A different model means the stored vectors are not comparable with it.
    notifyListeners();
  }

  Future<void> downloadModel(
    EmbeddingModelDescriptor descriptor, {
    CancelToken? cancelToken,
  }) async {
    _busy = true;
    _lastError = null;
    _downloadProgress = 0;
    notifyListeners();
    try {
      final installed = await _modelStore.download(
        descriptor,
        cancelToken: cancelToken,
        onProgress: (received, total) {
          if (total <= 0) return;
          final next = (received / total).clamp(0.0, 1.0);
          if ((next - (_downloadProgress ?? 0)) < 0.01) return;
          _downloadProgress = next;
          notifyListeners();
        },
      );
      await _modelStore.select(installed);
      await refreshModels();
    } catch (error) {
      _lastError = '$error';
    } finally {
      _busy = false;
      _downloadProgress = null;
      notifyListeners();
    }
  }

  /// Take a GGUF the user already has.
  Future<bool> adoptModelFile(String path) async {
    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      final adopted = await _modelStore.adopt(path);
      await _modelStore.select(adopted);
      await refreshModels();
      return true;
    } catch (error) {
      _lastError = '$error';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> deleteModel(InstalledEmbeddingModel model) async {
    await _modelStore.delete(model);
    await refreshModels();
  }

  // ---- retrieval settings ---------------------------------------------

  RetrievalSettings _settings = RetrievalPreset.balanced.settings;
  RetrievalSettings get settings => _settings;

  Future<void> updateSettings(RetrievalSettings settings) async {
    final safe = settings.sanitized();
    // A hand-moved value is no longer any preset, and saying so is what keeps
    // a slider from snapping back the moment it is touched.
    final stillPreset = RetrievalPreset.values
        .where((candidate) => candidate.settings == safe)
        .firstOrNull;
    _settings = safe.copyWith(
      preset: stillPreset,
      clearPreset: stillPreset == null,
    );
    _service?.applySettings(_settings);
    notifyListeners();
    await _settingsStore.save(_settings);
  }

  Future<void> applyPreset(RetrievalPreset preset) =>
      updateSettings(preset.settings);

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
    await _modelStore.load();
    _models = await _modelStore.installed();
    _settings = await _settingsStore.load();
    _service!.applySettings(_settings);
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
  /// Only plain text and Markdown. PDF is deferred rather than half-done — a
  /// PDF that indexes to empty strings is worse than a clear "not yet".
  Future<KnowledgeDocument?> importFile({
    required String path,
    CancelToken? cancelToken,
    void Function(String title, int done, int total)? onProgress,
  }) async {
    final service = _service;
    final model = selectedModel;
    if (service == null) return null;

    final lower = path.toLowerCase();
    if (!lower.endsWith('.md') &&
        !lower.endsWith('.txt') &&
        !lower.endsWith('.markdown')) {
      _lastError = 'Only .md and .txt are supported for now.';
      notifyListeners();
      return null;
    }
    if (model == null) {
      _lastError = 'Choose an embedding model first.';
      notifyListeners();
      return null;
    }

    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      final text = await File(path).readAsString();
      final title = path.split('/').last;
      final document = await service.addText(
        title: title,
        text: text,
        embeddingModelId: model.id,
        // Started here rather than borrowed from the chat server: that one is
        // in single-model mode, where the `model` field of a request is
        // ignored, so an embedding request would be answered by a chat model.
        baseUrl: await _ensureEmbeddingServer(model),
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
      return document;
    } catch (error) {
      _lastError = '$error';
      return null;
    } finally {
      await _embeddingServer.stop();
      _busy = false;
      notifyListeners();
    }
  }

  /// Bring the embedding server up on [model] and return its base URL.
  Future<String> _ensureEmbeddingServer(InstalledEmbeddingModel model) async {
    if (_embeddingServer.isRunning && await _embeddingServer.isReady()) {
      _embeddingServer.keepAlive();
      return 'http://127.0.0.1:${_embeddingServer.port}';
    }
    return _embeddingServer.start(modelPath: model.path);
  }

  Future<void> remove(String documentId) async {
    await _service?.remove(documentId);
    notifyListeners();
  }

  /// Drop every vector and keep the files.
  ///
  /// Needed whenever the embedding model changes: vectors from two models are
  /// not comparable, and answering from a mixed index produces confident
  /// nonsense.
  Future<void> rebuild() async {
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
  Future<String> search(String query, {CancelToken? cancelToken}) async {
    final service = _service;
    final model = selectedModel;
    if (!_retrievalEnabled || service == null || model == null) return '';
    if (!service.hasIndexedDocuments) return '';
    try {
      final baseUrl = await _ensureEmbeddingServer(model);
      try {
        return await service.search(
          query: query,
          embeddingModelId: model.id,
          baseUrl: baseUrl,
          cancelToken: cancelToken,
        );
      } finally {
        await _embeddingServer.stop();
      }
    } catch (error) {
      debugPrint('KnowledgeBaseProvider.search: $error');
      return '';
    }
  }

  /// A tool wired to this library, or null when there is nothing to search.
  ///
  /// Null rather than a tool that returns nothing: advertising a search that
  /// always comes back empty teaches the model to call a useless tool.
  BuiltinTools? toolsFor() {
    if (!_retrievalEnabled || !hasIndexedDocuments || !hasModel) return null;
    return BuiltinTools(searchKnowledge: (query) => search(query));
  }

  /// Stop the embedding server now, rather than waiting out its idle timer.
  /// Called when the knowledge base page closes.
  Future<void> shutdown() => _embeddingServer.stop();
}
