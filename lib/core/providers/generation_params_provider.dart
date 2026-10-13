import 'package:flutter/foundation.dart';
import 'package:servllama/core/models/generation_params.dart';

/// Holds the sampling settings and persists every change.
///
/// Reads are cheap and synchronous: the chat path needs the current params at
/// the moment a request goes out, and it must not be holding a copy from when
/// the app started.
class GenerationParamsProvider extends ChangeNotifier {
  GenerationParamsProvider({GenerationParamsLoader? loader})
    : _loader = loader ?? GenerationParamsLoader();

  final GenerationParamsLoader _loader;

  GenerationParams _params = const GenerationParams();
  bool _loaded = false;

  GenerationParams get params => _params;

  /// Whether the settings have been read from storage yet. The chat path can
  /// send a request before this completes; it sends no parameters rather than
  /// defaults, which is the safe direction to be wrong in.
  bool get isLoaded => _loaded;

  Future<void> load() async {
    _params = await _loader.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> update(GenerationParams params) async {
    if (params == _params) return;
    _params = params;
    notifyListeners();
    await _loader.save(params);
  }

  /// Reset one parameter to "let the model decide".
  Future<void> clear(GenerationParamField field) =>
      update(_params.copyWith(clearTemperature: field == GenerationParamField.temperature,
        clearTopP: field == GenerationParamField.topP,
        clearTopK: field == GenerationParamField.topK,
        clearRepeatPenalty: field == GenerationParamField.repeatPenalty,
        clearMaxTokens: field == GenerationParamField.maxTokens,
      ));

  /// Back to everything unset, in one step.
  Future<void> reset() => update(const GenerationParams());
}

/// Which parameter a row on the settings page edits.
enum GenerationParamField { temperature, topP, topK, repeatPenalty, maxTokens }
