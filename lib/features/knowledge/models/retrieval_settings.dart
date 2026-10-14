import 'dart:convert';

import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/core/storage/server_prefs_keys.dart';

/// The knobs that decide what a search hands the model.
///
/// These were compiled-in constants, which made the retrieval quality
/// unarguable with. A large library wants fewer, longer passages; a small one
/// wants many short ones; and nobody can tell in advance which they have, so
/// the choice belongs here.
class RetrievalSettings {
  const RetrievalSettings({
    this.maxChunks = 4,
    this.minScore = 0.28,
    this.charBudget = 2000,
    this.perChunkChars = 600,
    this.preset = RetrievalPreset.balanced,
  });

  /// How many passages come back at all.
  final int maxChunks;

  /// Below this the passage is noise. Higher means fewer but safer answers.
  final double minScore;

  /// Total characters handed to the model, across every passage.
  final int charBudget;

  /// Characters from one passage before it gets cut.
  ///
  /// Separate from [charBudget] because "four passages" and "four long
  /// passages" are different requests, and only one of them fits a window.
  final int perChunkChars;

  /// Which preset produced these values, or null once one has been moved by
  /// hand — a slider that snaps back to a preset every time it is touched is
  /// a slider you cannot set a value on.
  final RetrievalPreset? preset;

  /// Whether the current values still match their preset exactly.
  bool matchesPreset(RetrievalPreset candidate) => candidate.settings == this;

  /// A copy that keeps its preset name **only if the values still match it**.
  ///
  /// Carrying the old name forward is what makes a slider snap back: the chip
  /// stays lit for "balanced" while the numbers under it no longer are. The
  /// user is not fighting the app here, they are setting a value.
  RetrievalSettings copyWith({
    int? maxChunks,
    double? minScore,
    int? charBudget,
    int? perChunkChars,
    RetrievalPreset? preset,
    bool clearPreset = false,
  }) {
    final candidate = RetrievalSettings(
      maxChunks: maxChunks ?? this.maxChunks,
      minScore: minScore ?? this.minScore,
      charBudget: charBudget ?? this.charBudget,
      perChunkChars: perChunkChars ?? this.perChunkChars,
      preset: null,
    );
    if (clearPreset) return candidate;
    // Landing back exactly on a preset's numbers re-identifies it, so the
    // chip lights up again for the right reason. Built directly rather than
    // through another copyWith — that would recurse, since this method is what
    // decides the preset in the first place.
    final matched = RetrievalPreset.values
        .where((option) => option.settings.matchesValues(candidate))
        .firstOrNull;
    final chosen = preset ?? matched;
    if (chosen == null || !chosen.settings.matchesValues(candidate)) {
      return candidate;
    }
    return RetrievalSettings(
      maxChunks: candidate.maxChunks,
      minScore: candidate.minScore,
      charBudget: candidate.charBudget,
      perChunkChars: candidate.perChunkChars,
      preset: chosen,
    );
  }

  /// Whether [other] has these numbers, ignoring which preset claims them.
  bool matchesValues(RetrievalSettings other) =>
      other.maxChunks == maxChunks &&
      other.minScore == minScore &&
      other.charBudget == charBudget &&
      other.perChunkChars == perChunkChars;

  RetrievalPreset get effectivePreset => preset ?? RetrievalPreset.balanced;

  /// Clamp into ranges a server and a window can actually take.
  ///
  /// A stored value is user input like any other; an out-of-range one has to
  /// be corrected here rather than becoming a failed request at send time.
  RetrievalSettings sanitized() => copyWith(
    maxChunks: maxChunks.clamp(1, 16),
    minScore: minScore.clamp(0.0, 1.0),
    charBudget: charBudget.clamp(200, 8000),
    perChunkChars: perChunkChars.clamp(80, 2000),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'maxChunks': maxChunks,
    'minScore': minScore,
    'charBudget': charBudget,
    'perChunkChars': perChunkChars,
    if (preset case final preset?) 'preset': preset.name,
  };

  factory RetrievalSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return RetrievalPreset.balanced.settings;
    final preset = RetrievalPreset.values
        .where((candidate) => candidate.name == json['preset'])
        .firstOrNull;
    int? asInt(Object? value) => switch (value) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v),
      _ => null,
    };

    double? asDouble(Object? value) => switch (value) {
      double v => v,
      num v => v.toDouble(),
      String v => double.tryParse(v),
      _ => null,
    };

    // A stored blob written by an older build is missing fields. Fall back to
    // the preset's value for each one rather than to the class default, so a
    // half-understood settings blob still lands somewhere coherent.
    // With no preset named in the blob there is nothing to anchor the missing
    // fields to, and a settings object belonging to no preset is not a place
    // the UI can put a chip.
    final base = preset?.settings ?? RetrievalPreset.balanced.settings;
    if (preset == null) {
      return RetrievalSettings(
        maxChunks: asInt(json['maxChunks']) ?? base.maxChunks,
        minScore: asDouble(json['minScore']) ?? base.minScore,
        charBudget: asInt(json['charBudget']) ?? base.charBudget,
        perChunkChars: asInt(json['perChunkChars']) ?? base.perChunkChars,
      );
    }
    return RetrievalSettings(
      maxChunks: asInt(json['maxChunks']) ?? base.maxChunks,
      minScore: asDouble(json['minScore']) ?? base.minScore,
      charBudget: asInt(json['charBudget']) ?? base.charBudget,
      perChunkChars: asInt(json['perChunkChars']) ?? base.perChunkChars,
      preset: preset,
    );
  }

  /// What this costs in prompt. Shown next to the sliders, because the real
  /// constraint is the model's context window and the numbers alone do not
  /// say whether they fit.
  String get budgetSummary => '$maxChunks passages · $charBudget chars total';

  @override
  bool operator ==(Object other) =>
      other is RetrievalSettings &&
      other.maxChunks == maxChunks &&
      other.minScore == minScore &&
      other.charBudget == charBudget &&
      other.perChunkChars == perChunkChars &&
      other.preset == preset;

  @override
  int get hashCode =>
      Object.hash(maxChunks, minScore, charBudget, perChunkChars, preset);
}

/// Ready-made answers to "how much should the model be told".
enum RetrievalPreset {
  /// Nothing unless it is a good match. Right for a library where a wrong
  /// answer is worse than no answer.
  precise(maxChunks: 3, minScore: 0.45, charBudget: 1600, perChunkChars: 520),

  /// The middle.
  balanced(maxChunks: 4, minScore: 0.28, charBudget: 2000, perChunkChars: 600),

  /// More passages and a lower bar. Right for a big library where the answer
  /// is usually in there somewhere and the model needs to see more of it.
  exhaustive(
    maxChunks: 8,
    minScore: 0.18,
    charBudget: 3200,
    perChunkChars: 700,
  );

  const RetrievalPreset({
    required this.maxChunks,
    required this.minScore,
    required this.charBudget,
    required this.perChunkChars,
  });

  // Carried on the enum rather than produced by a switch, so a preset is a
  // const value and can be used where one is required.
  final int maxChunks;
  final double minScore;
  final int charBudget;
  final int perChunkChars;

  RetrievalSettings get settings => RetrievalSettings(
    maxChunks: maxChunks,
    minScore: minScore,
    charBudget: charBudget,
    perChunkChars: perChunkChars,
    preset: this,
  );
}

/// Loads and stores [RetrievalSettings].
class RetrievalSettingsStore {
  RetrievalSettingsStore({KvStorage? kvStorage})
    : _kvStorage = kvStorage ?? KvStorage.instance;

  final KvStorage _kvStorage;

  Future<RetrievalSettings> load() async {
    final raw = await _kvStorage.getString(ServerPrefsKeys.retrievalSettings);
    if (raw == null || raw.isEmpty) return RetrievalPreset.balanced.settings;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return RetrievalPreset.balanced.settings;
      return RetrievalSettings.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      // A corrupt blob costs the tuning, not the knowledge base.
      return RetrievalPreset.balanced.settings;
    }
  }

  Future<void> save(RetrievalSettings settings) async {
    await _kvStorage.setString(
      ServerPrefsKeys.retrievalSettings,
      jsonEncode(settings.toJson()),
    );
  }
}
