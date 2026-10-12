/// Tokens per second, measured from the deltas as they arrive.
///
/// Counted with the same weighted character estimator the context meter
/// uses rather than a real tokenizer: llama.cpp reports per-token timings
/// only when asked over the API, and a number that is within a few percent
/// of true is worth more here than a number that is exactly right and
/// costs a round trip.
///
/// Held outside the widget for the same reason the thinking clock is: these
/// rows live in a lazily built list and get torn down on every scroll.
class TokenStats {
  const TokenStats._();

  static final Map<String, _Sample> _samples = <String, _Sample>{};

  /// Feeds a delta. [isStreaming] false marks the end of measurement.
  static void observe(
    String messageId,
    String content, {
    required bool isStreaming,
  }) {
    if (content.isEmpty && isStreaming) return;
    final now = DateTime.now();
    final sample = _samples[messageId];
    if (sample == null) {
      _samples[messageId] = _Sample(
        startedAt: now,
        endedAt: isStreaming ? null : now,
        characters: content.length,
      );
      return;
    }
    sample.characters = content.length;
    if (!isStreaming) sample.endedAt = now;
  }

  static double? tokensPerSecond(String messageId) {
    final sample = _samples[messageId];
    if (sample == null) return null;
    final end = sample.endedAt;
    if (end == null) return null;
    final seconds = end.difference(sample.startedAt).inMilliseconds / 1000;
    if (seconds <= 0.05) return null;
    return _estimateTokens(sample.characters) / seconds;
  }

  /// Latin runs about four characters to a token; CJK runs closer to one.
  static int _estimateTokens(int characters) {
    if (characters <= 0) return 0;
    return (characters / 3.2).ceil();
  }

  static void forget(String messageId) => _samples.remove(messageId);
}

class _Sample {
  _Sample({
    required this.startedAt,
    required this.endedAt,
    required this.characters,
  });

  final DateTime startedAt;
  DateTime? endedAt;
  int characters;
}
