import 'dart:convert';

import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/core/storage/server_prefs_keys.dart';

/// Sampling settings sent with every chat request.
///
/// These belong to the *request*, not to the server process: llama-server
/// accepts all of them per call, so changing one takes effect on the next
/// message without restarting anything. That is the whole reason they are not
/// launch flags alongside the context size.
///
/// Every value here has a null meaning "let the model decide", which is the
/// default. Sending an explicit number the user never chose is how an app
/// ends up with a temperature it never mentioned and cannot find again.
class GenerationParams {
  const GenerationParams({
    this.temperature,
    this.topP,
    this.topK,
    this.repeatPenalty,
    this.maxTokens,
  });

  /// Null on every field means the parameter is left to the server.
  final double? temperature;
  final double? topP;
  final int? topK;
  final double? repeatPenalty;

  /// Cap on the reply. Null means "no cap", which is what lets a long answer
  /// actually finish instead of being cut at a number chosen by someone else.
  final int? maxTokens;

  /// Whether anything is set at all — used to skip the keys entirely rather
  /// than send a body of nulls.
  bool get isEmpty =>
      temperature == null &&
      topP == null &&
      topK == null &&
      repeatPenalty == null &&
      maxTokens == null;

  /// The body fragment for a chat request.
  ///
  /// Only the set parameters appear. Sending nulls is not equivalent to
  /// omitting them: some servers read an explicit null as "use the launch
  /// default", which is fine, but others reject it — and there is nothing to
  /// gain by finding out which one this build is pointed at.
  Map<String, dynamic> toRequestFields() {
    final fields = <String, dynamic>{};
    if (temperature != null) fields['temperature'] = temperature;
    if (topP != null) fields['top_p'] = topP;
    if (topK != null) fields['top_k'] = topK;
    if (repeatPenalty != null) fields['repeat_penalty'] = repeatPenalty;
    if (maxTokens != null) fields['max_tokens'] = maxTokens;
    return fields;
  }

  GenerationParams copyWith({
    double? temperature,
    double? topP,
    int? topK,
    double? repeatPenalty,
    int? maxTokens,
    bool clearTemperature = false,
    bool clearTopP = false,
    bool clearTopK = false,
    bool clearRepeatPenalty = false,
    bool clearMaxTokens = false,
  }) {
    return GenerationParams(
      temperature: clearTemperature ? null : (temperature ?? this.temperature),
      topP: clearTopP ? null : (topP ?? this.topP),
      topK: clearTopK ? null : (topK ?? this.topK),
      repeatPenalty: clearRepeatPenalty
          ? null
          : (repeatPenalty ?? this.repeatPenalty),
      maxTokens: clearMaxTokens ? null : (maxTokens ?? this.maxTokens),
    );
  }

  Map<String, dynamic> toJson() => {
    if (temperature != null) 'temperature': temperature,
    if (topP != null) 'top_p': topP,
    if (topK != null) 'top_k': topK,
    if (repeatPenalty != null) 'repeat_penalty': repeatPenalty,
    if (maxTokens != null) 'max_tokens': maxTokens,
  };

  factory GenerationParams.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const GenerationParams();
    double? asDouble(Object? value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    int? asInt(Object? value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    return GenerationParams(
      temperature: asDouble(json['temperature']),
      topP: asDouble(json['top_p']),
      topK: asInt(json['top_k']),
      repeatPenalty: asDouble(json['repeat_penalty']),
      maxTokens: asInt(json['max_tokens']),
    );
  }

  /// Drop anything outside the range a server will accept rather than sending
  /// it and getting an error back at the worst moment.
  GenerationParams sanitized() {
    return GenerationParams(
      temperature: temperature?.clamp(0.0, 2.0),
      topP: topP?.clamp(0.0, 1.0),
      topK: topK?.clamp(1, 200),
      repeatPenalty: repeatPenalty?.clamp(0.5, 2.0),
      maxTokens: maxTokens != null && maxTokens! < 1 ? null : maxTokens,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GenerationParams &&
      other.temperature == temperature &&
      other.topP == topP &&
      other.topK == topK &&
      other.repeatPenalty == repeatPenalty &&
      other.maxTokens == maxTokens;

  @override
  int get hashCode =>
      Object.hash(temperature, topP, topK, repeatPenalty, maxTokens);

  @override
  String toString() =>
      'GenerationParams(${toJson().entries.map((e) => '${e.key}=${e.value}').join(', ')})';
}

/// Loads and stores [GenerationParams].
class GenerationParamsLoader {
  GenerationParamsLoader({KvStorage? kvStorage})
    : _kvStorage = kvStorage ?? KvStorage.instance;

  final KvStorage _kvStorage;

  Future<GenerationParams> load() async {
    final raw = await _kvStorage.getString(ServerPrefsKeys.generationParams);
    if (raw == null || raw.isEmpty) return const GenerationParams();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const GenerationParams();
      return GenerationParams.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      // A corrupt blob should cost the user their settings, not the app's
      // ability to start a conversation.
      return const GenerationParams();
    }
  }

  Future<void> save(GenerationParams params) async {
    await _kvStorage.setString(
      ServerPrefsKeys.generationParams,
      params.isEmpty ? '' : jsonEncode(params.toJson()),
    );
  }
}
