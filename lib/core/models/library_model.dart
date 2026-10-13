import 'package:servllama/core/models/inference_engine.dart';

/// One entry of the unified model library. GGUF models (llama.cpp) and MNN
/// model directories are listed side by side and told apart by [engine]
/// (design decision D2).
class LibraryModel {
  const LibraryModel({
    required this.id,
    required this.runtimeId,
    required this.engine,
    required this.name,
    required this.sizeBytes,
    required this.importedAt,
    required this.storagePath,
    this.supportsVision = false,
    this.supportsToolCalling = false,
    this.hasMmproj = false,
    this.sourceValue,
    this.repoId,
    this.revision,
    this.warnings = const <String>[],
    this.alias,
  });

  /// Key for library operations (rename, delete). Namespaced by engine because
  /// the two stores generate ids independently. MNN renames change this key
  /// because its directory name is also its native model id.
  final String id;

  /// Identifier the engine itself uses when asked to load this model. For both
  /// engines this is the model directory name.
  final String runtimeId;

  final InferenceEngine engine;
  final String name;

  /// A name the user chose for this model, shown instead of [name].
  ///
  /// Display only. [runtimeId] — what the server is actually launched with —
  /// is untouched by it, as is the file on disk.
  final String? alias;

  /// What to show for this model: the alias when there is one, else the real
  /// name.
  String get title {
    final trimmed = alias?.trim();
    return (trimmed != null && trimmed.isNotEmpty) ? trimmed : name;
  }

  /// Whether this model has been given a different name to show.
  bool get hasAlias {
    final trimmed = alias?.trim();
    return trimmed != null && trimmed.isNotEmpty;
  }
  final int sizeBytes;
  final DateTime importedAt;

  /// GGUF file path, or MNN model directory path.
  final String storagePath;

  final bool supportsVision;
  final bool supportsToolCalling;

  /// llama.cpp only: a sibling GGUF whose name contains `mmproj`, enabling image input.
  final bool hasMmproj;

  /// Hub source of a downloaded GGUF. Null for local imports and MNN models.
  final String? sourceValue;
  final String? repoId;
  final String? revision;

  final List<String> warnings;

  bool get canDownloadMmproj {
    if (engine != InferenceEngine.llamaCpp) {
      return false;
    }
    final source = sourceValue?.trim();
    final repo = repoId?.trim();
    return source != null &&
        source.isNotEmpty &&
        repo != null &&
        repo.isNotEmpty;
  }

  /// Null means "keep what is there", except for [alias], which has to be
  /// clearable — hence the sentinel.
  static const _unset = Object();

  LibraryModel copyWith({
    String? id,
    String? runtimeId,
    InferenceEngine? engine,
    String? name,
    int? sizeBytes,
    DateTime? importedAt,
    String? storagePath,
    bool? supportsVision,
    bool? supportsToolCalling,
    bool? hasMmproj,
    String? sourceValue,
    String? repoId,
    String? revision,
    List<String>? warnings,
    Object? alias = _unset,
  }) {
    return LibraryModel(
      id: id ?? this.id,
      runtimeId: runtimeId ?? this.runtimeId,
      engine: engine ?? this.engine,
      name: name ?? this.name,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      importedAt: importedAt ?? this.importedAt,
      storagePath: storagePath ?? this.storagePath,
      supportsVision: supportsVision ?? this.supportsVision,
      supportsToolCalling: supportsToolCalling ?? this.supportsToolCalling,
      hasMmproj: hasMmproj ?? this.hasMmproj,
      sourceValue: sourceValue ?? this.sourceValue,
      repoId: repoId ?? this.repoId,
      revision: revision ?? this.revision,
      warnings: warnings ?? this.warnings,
      alias: identical(alias, _unset) ? this.alias : alias as String?,
    );
  }
}
