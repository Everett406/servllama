import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/core/storage/server_prefs_keys.dart';
import 'package:servllama/features/downloads/models/download_task.dart';
import 'package:servllama/features/downloads/services/model_download_service.dart';
import 'package:servllama/features/knowledge/models/embedding_model_descriptor.dart';

/// An embedding GGUF the user actually has on the device.
///
/// The three built-in descriptors are a menu, not a cage. Everything in
/// ggml's own conversion ecosystem is a GGUF, and a user who has already
/// run a converter has a file they want to point at — not three suggestions
/// they have to download first.
class InstalledEmbeddingModel {
  const InstalledEmbeddingModel({
    required this.id,
    required this.name,
    required this.path,
    required this.sizeBytes,
    this.dimensions,
    this.maxTokens = 512,
    this.custom = false,
  });

  final String id;
  final String name;
  final String path;
  final int sizeBytes;

  /// Null when unknown, which is the normal case for a model the user brought.
  ///
  /// It matters: a mismatch between the declared and the actual width makes
  /// every stored vector unusable, so an unknown width is something to *find
  /// out* before indexing rather than a number to guess.
  final int? dimensions;
  final int maxTokens;

  /// True when the user brought it rather than picking a built-in.
  final bool custom;

  /// Whether this can back a knowledge base at all.
  ///
  /// A chat GGUF has no embedding head. Pointed at `/v1/embeddings` it either
  /// errors or returns zeros, and both look like "the search found nothing".
  bool get looksLikeEmbeddingModel {
    final lower = name.toLowerCase();
    return lower.contains('embed') ||
        lower.contains('bge') ||
        lower.contains('e5') ||
        lower.contains('gte') ||
        lower.contains('minilm');
  }
}

/// Downloads the built-in embedding models, adopts the user's own GGUF, and
/// remembers which one is selected.
class EmbeddingModelStore {
  EmbeddingModelStore({
    ModelDownloadService? downloader,
    KvStorage? kvStorage,
  }) : _downloader = downloader ?? ModelDownloadService(),
       _kvStorage = kvStorage ?? KvStorage.instance;

  final ModelDownloadService _downloader;
  final KvStorage _kvStorage;

  String? _selectedId;
  String? _selectedPath;
  int? _selectedDimensions;

  String? get selectedId => _selectedId;

  /// The file to hand the embedding server. Null means "nothing chosen",
  /// which the UI says outright rather than quietly falling back to a model
  /// the user did not pick.
  String? get selectedPath => _selectedPath;

  int? get selectedDimensions => _selectedDimensions;

  /// Where embedding models live. Separate from the chat models directory so
  /// the model list is not cluttered with a 26 MB BERT the chat server can
  /// never load.
  Future<Directory> modelsDirectory() async {
    final base = await getApplicationSupportDirectory();
    final directory = Directory(
      '${base.path}/kb/models',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<void> load() async {
    _selectedId = await _kvStorage.getString(ServerPrefsKeys.embeddingModelId);
    _selectedPath = await _kvStorage.getString(ServerPrefsKeys.embeddingModelPath);
    final dimensions = await _kvStorage.getInt(
      ServerPrefsKeys.embeddingModelDimensions,
    );
    _selectedDimensions = dimensions;
  }

  Future<void> select(InstalledEmbeddingModel model) async {
    _selectedId = model.id;
    _selectedPath = model.path;
    _selectedDimensions = model.dimensions;
    await _kvStorage.setString(ServerPrefsKeys.embeddingModelId, model.id);
    await _kvStorage.setString(ServerPrefsKeys.embeddingModelPath, model.path);
    if (model.dimensions != null) {
      await _kvStorage.setInt(
        ServerPrefsKeys.embeddingModelDimensions,
        model.dimensions!,
      );
    }
  }

  Future<void> clearSelection() async {
    _selectedId = null;
    _selectedPath = null;
    _selectedDimensions = null;
    await _kvStorage.remove(ServerPrefsKeys.embeddingModelId);
    await _kvStorage.remove(ServerPrefsKeys.embeddingModelPath);
    await _kvStorage.remove(ServerPrefsKeys.embeddingModelDimensions);
  }

  /// What is on disk right now: the built-ins the user downloaded, plus any
  /// GGUF they pointed at.
  Future<List<InstalledEmbeddingModel>> installed() async {
    final directory = await modelsDirectory();
    if (!await directory.exists()) return const <InstalledEmbeddingModel>[];
    final models = <InstalledEmbeddingModel>[];
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final name = entity.path.split('/').last;
      if (!name.toLowerCase().endsWith('.gguf')) continue;
      final builtIn = EmbeddingModelDescriptor.byFileName(name);
      final size = await entity.length();
      models.add(
        InstalledEmbeddingModel(
          id: builtIn?.id ?? 'custom:${size}_${name.hashCode}',
          name: builtIn?.name ?? name,
          path: entity.path,
          sizeBytes: size,
          // A built-in keeps its declared width. A user's file has none, and
          // inventing one is exactly the guess that makes an index silently
          // unsearchable.
          dimensions: builtIn?.dimensions,
          maxTokens: builtIn?.maxTokens ?? 512,
          custom: builtIn == null,
        ),
      );
    }
    models.sort((a, b) {
      if (a.custom != b.custom) return a.custom ? 1 : -1;
      return a.sizeBytes.compareTo(b.sizeBytes);
    });
    return models;
  }

  /// Download one of the built-in descriptors.
  Future<InstalledEmbeddingModel> download(
    EmbeddingModelDescriptor descriptor, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final directory = await modelsDirectory();
    final file = await _downloader.downloadFile(
      url: descriptor.url,
      file: DownloadFileRecord(
        remotePath: descriptor.fileName,
        fileName: descriptor.fileName,
        totalBytes: descriptor.approxBytes,
      ),
      targetDirectory: directory,
      // The service reports a running total, not a fraction; the UI wants a
      // fraction, so the conversion happens here rather than at the call site.
      onProgress: onProgress == null
          ? null
          : (file, receivedDelta) =>
                onProgress(file.receivedBytes, file.totalBytes),
      cancelToken: cancelToken,
    );
    debugPrint('EmbeddingModelStore: got ${file.path}');
    return InstalledEmbeddingModel(
      id: descriptor.id,
      name: descriptor.name,
      path: file.path,
      sizeBytes: await file.length(),
      dimensions: descriptor.dimensions,
      maxTokens: descriptor.maxTokens,
    );
  }

  /// Copy a GGUF the user picked from elsewhere into the models directory.
  ///
  /// Copied rather than referenced: a knowledge base that breaks because
  /// someone moved a file in a file manager looks like data loss, and it is
  /// indistinguishable from it to the person who did it.
  Future<InstalledEmbeddingModel> adopt(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw StateError('No such file: $sourcePath');
    }
    final directory = await modelsDirectory();
    final name = sourcePath.split('/').last;
    final destination = File('${directory.path}/$name');
    if (await destination.exists()) {
      final existing = await destination.length();
      final incoming = await source.length();
      if (existing == incoming) {
        return InstalledEmbeddingModel(
          id: 'custom:${incoming}_${name.hashCode}',
          name: name,
          path: destination.path,
          sizeBytes: existing,
          custom: true,
        );
      }
      // Same name, different bytes. Refusing beats overwriting: the file on
      // disk may be the one the index was built from.
      throw StateError(
        'A different file named "$name" is already here. Rename yours and '
        'try again.',
      );
    }
    await source.copy(destination.path);
    final size = await destination.length();
    return InstalledEmbeddingModel(
      id: 'custom:${size}_${name.hashCode}',
      name: name,
      path: destination.path,
      sizeBytes: size,
      custom: true,
    );
  }

  Future<void> delete(InstalledEmbeddingModel model) async {
    final file = File(model.path);
    if (await file.exists()) await file.delete();
    if (_selectedPath == model.path) {
      await clearSelection();
    }
  }
}