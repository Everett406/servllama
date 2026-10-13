import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:servllama/core/models/generation_params.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/core/storage/server_prefs_keys.dart';
import 'package:servllama/features/chat/services/llama_chat_api_client.dart';

/// How a conversation gets its name.
///
/// The alternative is the first line of the user's message with an ellipsis,
/// which is a heading made of truncation: it starts "can you help me…" far more
/// often than it names anything. A model asked for four or five words does
/// noticeably better, and it is the same model that is already loaded.
///
/// Title generation is a *second* request, deliberately:
///   - It runs after the first answer has finished, never during it. Two
///     concurrent streams to one llama-server means two decode loops competing
///     for the same context and the same memory, and the answer the user is
///     actually waiting for would be the one that slows down.
///   - It is fire-and-forget. A title is not worth surfacing an error for.
///   - It never replaces a title the user has typed or renamed.
class SessionTitleGenerator {
  SessionTitleGenerator({
    required LlamaChatApiClient apiClient,
    KvStorage? kvStorage,
  }) : _apiClient = apiClient,
       _kvStorage = kvStorage ?? KvStorage.instance;

  final LlamaChatApiClient _apiClient;
  final KvStorage _kvStorage;

  static const String _systemPrompt =
      'You name conversations. Reply with a title of at most six words in the '
      'same language as the user. No quotes, no punctuation at the end, no '
      'explanation. Output the title and nothing else.';

  bool _enabled = true;
  String? _modelOverrideId;

  /// Whether to spend a request on a name at all.
  bool get enabled => _enabled;

  /// A dedicated model for titles, or null to reuse whatever is running.
  String? get modelOverrideId => _modelOverrideId;

  bool get _overrideConfigured => (_modelOverrideId ?? '').isNotEmpty;

  Future<void> load() async {
    _enabled = (await _kvStorage.getString(ServerPrefsKeys.titleGenerationEnabled)) != 'false';
    _modelOverrideId = await _kvStorage.getString(ServerPrefsKeys.titleGenerationModel);
  }

  Future<void> setEnabled(bool enabled) async {
    if (_enabled == enabled) return;
    _enabled = enabled;
    await _kvStorage.setString(
      ServerPrefsKeys.titleGenerationEnabled,
      enabled ? 'true' : 'false',
    );
  }

  Future<void> setModelOverride(String? modelId) async {
    final cleaned = (modelId ?? '').trim();
    final next = cleaned.isEmpty ? null : cleaned;
    if (_modelOverrideId == next) return;
    _modelOverrideId = next;
    await _kvStorage.setString(ServerPrefsKeys.titleGenerationModel, cleaned);
  }

  /// Ask for a name, or return null for anything that goes wrong.
  ///
  /// Null is the answer in every failure case on purpose: a title is a nicety,
  /// and surfacing "could not name this conversation" to someone mid-chat
  /// would be worse than leaving the fallback in place.
  Future<String?> generate({
    required String modelId,
    required String firstUserMessage,
  }) async {
    if (!_enabled) return null;
    final prompt = firstUserMessage.trim();
    if (prompt.isEmpty) return null;

    final cancelToken = CancelToken();
    try {
      final response = await _apiClient.completeTitle(
        modelId: _overrideConfigured ? _modelOverrideId! : modelId,
        systemPrompt: _systemPrompt,
        userPrompt: prompt,
        cancelToken: cancelToken,
        // A title is a few words; leaving the cap to the server invites a long
        // answer that costs real decode time on a phone.
        generationParams: const GenerationParams(
          temperature: 0.3,
          maxTokens: 24,
        ),
      );
      return _clean(response);
    } catch (error) {
      debugPrint('SessionTitleGenerator: $error');
      return null;
    }
  }

  /// The "sure, here you go" lines models prepend when told to output only a
  /// title. Both scripts, because a reply follows the language of the prompt.
  static final RegExp _preamble = RegExp(
    r'^(?:here (?:is|are)[^\n]*'
    r'|(?:title|sure|certainly|okay|ok)\s*[\uFF1A!\uFF01-]?\s*'
    r'|\u6807\u9898\s*[\uFF1A!\uFF01-]?\s*'
    r'|\u597D\u7684?\s*[\uFF1A!\uFF01-]?\s*'
    r'|\u53EF\u4EE5\s*[\uFF1A!\uFF01-]?\s*)$',
    caseSensitive: false,
  );

  /// The same preamble, but as a prefix to strip rather than a whole line to
  /// skip — a model often writes the label and the title on one line.
  static final RegExp _preamblePrefix = RegExp(
    r'^\s*(?:here (?:is|are)[^\n]*'
    r'|(?:title|sure|certainly|okay|ok)\s*[\uFF1A!\uFF01-]?\s*'
    r'|\u6807\u9898\s*[\uFF1A!\uFF01-]?\s*'
    r'|\u597D\u7684?\s*[\uFF1A!\uFF01-]?\s*'
    r'|\u53EF\u4EE5\s*[\uFF1A!\uFF01-]?)[\s\uFF1A\uFF01]*',
    caseSensitive: false,
  );

  static final RegExp _leadingQuotes = RegExp(
    r'^[\s\-*\u2022#>\d.\u3001)]+|['
    '\u0022\u201c\u201d\u0027\u2018\u2019\u300c\u300e\u300a\u3010[]+',
  );
  static final RegExp _trailingQuotes = RegExp(
    '[\u0022\u201c\u201d\u0027\u2018\u2019\u300d\u300f\u300b\u3011\\]]+\$',
  );

  /// Exposed for the tests that pin the cleanup rules; not part of the API the
  /// app uses.
  @visibleForTesting
  static String? cleanForTest(String? raw) => _clean(raw);

  /// Strip the things a title must not keep: quotes, a trailing full stop,
  /// a leading list marker, and any attempt to explain itself across lines.
  static String? _clean(String? raw) {
    if (raw == null) return null;
    var title = raw.trim();
    if (title.isEmpty) return null;

    // A model that ignored the instruction says so first, then puts the title
    // on the next line. Skip the preamble and take the first line that is
    // actually a title — taking line one blindly would file the conversation
    // under "Here is a title:".
    // "标题：关于异步的讨论" — the preamble is not always on a line of its
    // own, so it also has to come off the front of a line.
    title = title.replaceFirst(_preamblePrefix, '');
    final lines = title
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;
    final first = lines.firstWhere(
      (line) => !_preamble.hasMatch(line),
      orElse: () => lines.first,
    );
    title = first;

    title = title
        .replaceAll(RegExp(r'^[\s\-*•#>\d.、)]+'), '')
        .replaceAll(_leadingQuotes, '')
        .replaceAll(_trailingQuotes, '')
        .trim();
    title = title.replaceFirst(RegExp(r'[。．.，,、;；:：]+$'), '').trim();

    if (title.isEmpty) return null;
    // CJK titles are short by character count; a Latin one is short by words.
    // A cap that suits neither is a cap that truncates one of them.
    if (title.runes.length <= 40) return title;
    return String.fromCharCodes(title.runes.take(40));
  }
}
