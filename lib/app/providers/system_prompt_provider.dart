import 'package:flutter/foundation.dart';
import 'package:servllama/core/storage/app_prefs_keys.dart';
import 'package:servllama/core/storage/kv_storage.dart';

/// The instruction prepended to every conversation.
///
/// Most local models are chat-tuned but not instruction-tuned, and the ones
/// that are still bad at it. A user who keeps re-typing "answer in Chinese,
/// be terse" into the first message of every session should not have to.
///
/// Kept separate from the transcript on purpose: a system prompt describes
/// how to talk, not what was said, so it never appears in history and never
/// scrolls past. Editing it mid-conversation applies to the next request,
/// not retroactively to the turns already on screen.
class SystemPromptProvider extends ChangeNotifier {
  SystemPromptProvider({KvStorage? kvStorage})
    : _kvStorage = kvStorage ?? KvStorage.instance;

  static const int maxLength = 4000;

  final KvStorage _kvStorage;

  String _prompt = '';
  bool _hasLoaded = false;

  String get prompt => _prompt;
  bool get hasLoaded => _hasLoaded;
  bool get isEmpty => _prompt.trim().isEmpty;

  Future<void> load() async {
    if (_hasLoaded) return;
    _prompt = (await _kvStorage.getString(AppPrefsKeys.systemPrompt)) ?? '';
    _hasLoaded = true;
    notifyListeners();
  }

  Future<void> updatePrompt(String value) async {
    final next = value.length > maxLength
        ? value.substring(0, maxLength)
        : value;
    if (_prompt == next) return;
    _prompt = next;
    await _kvStorage.setString(AppPrefsKeys.systemPrompt, next);
    notifyListeners();
  }

  Future<void> clear() => updatePrompt('');
}