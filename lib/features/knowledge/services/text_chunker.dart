/// Splits source text into pieces small enough for the embedding model to
/// see whole.
///
/// The constraint is not bytes or words. The encoder has a token window —
/// 512 for every model offered — and a Chinese character costs about one
/// token while an English one costs about a quarter. A chunker that counts
/// characters therefore overshoots on Chinese by roughly four times, and the
/// tail of every chunk gets truncated at encode time with no error and no
/// warning. So everything here is counted in estimated tokens, with CJK
/// weighted at one and Latin text at a quarter.
///
/// Boundaries are respected before length. Cutting mid-sentence produces a
/// chunk that embeds badly — the vector ends up describing a fragment rather
/// than a thought — so paragraphs and sentence ends are tried first and a
/// hard split is the last resort.
class TextChunker {
  const TextChunker({
    this.targetTokens = 320,
    this.overlapTokens = 48,
    this.hardLimitTokens = 440,
  });

  /// Where a chunk aims to land. Under the model's window with room to
  /// spare, because a chunk that only just fits leaves no room for the
  /// punctuation a split tends to strand at the edge.
  final int targetTokens;

  /// How much of the previous chunk to repeat at the head of the next.
  ///
  /// Retrieval works on similarity, so a fact that straddles a boundary is
  /// in neither chunk cleanly. Repeating a little of the tail means at least
  /// one of the two is whole. Too much and every result comes back looking
  /// similar to its neighbours.
  final int overlapTokens;

  /// Absolute ceiling. Past this the split stops caring about boundaries.
  final int hardLimitTokens;

  static final _paragraphBreak = RegExp(r'\n\s*\n');
  static final _sentenceEnd = RegExp(r'[。！？!?；;\n]');

  /// Latin text averages a little under four characters per token. Punctuation
  /// and spaces run lower, so this is deliberately generous: overshooting the
  /// estimate is safe, undershooting it truncates.
  static const double _latinPerToken = 0.28;
  static const double _cjkPerToken = 1.0;

  List<String> split(String text) {
    final normalized = _normalize(text);
    if (normalized.trim().isEmpty) return const [];

    final paragraphs = normalized
        .split(_paragraphBreak)
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (paragraphs.isEmpty) return const [];

    final chunks = <String>[];
    var buffer = <_Piece>[];

    void flush() {
      if (buffer.isEmpty) return;
      final text = _join(buffer);
      if (text.trim().isNotEmpty) chunks.add(text.trim());
      if (overlapTokens <= 0) {
        buffer = [];
        return;
      }
      // Carry the tail of what was just emitted into the next chunk.
      var carried = 0;
      final kept = <_Piece>[];
      for (final piece in buffer.reversed) {
        final cost = estimateTokens(piece.text);
        if (carried + cost > overlapTokens) break;
        carried += cost;
        kept.insert(0, piece);
      }
      buffer = kept;
    }

    for (final paragraph in paragraphs) {
      for (final piece in _pieces(paragraph)) {
        final cost = estimateTokens(piece.text);
        final current = _tokensOf(buffer);

        // A single piece past the hard limit cannot be saved by waiting, so
        // it is split on its own and joined straight back.
        if (cost > hardLimitTokens) {
          flush();
          for (final part in _hardSplit(piece.text)) {
            chunks.add(part);
          }
          continue;
        }

        if (current + cost > targetTokens && current > 0) flush();
        buffer.add(piece);
      }
      // A paragraph break is a real boundary; do not let the next paragraph
      // fuse onto the tail of this one unless there is room for a full chunk.
      if (_tokensOf(buffer) >= targetTokens * 0.6) flush();
    }
    flush();
    return chunks;
  }

  /// Rough token count. Exposed because callers size their own buffers with
  /// it and the estimate is the whole point of the class.
  static int estimateTokens(String text) {
    var tokens = 0.0;
    for (final rune in text.runes) {
      tokens += _isCjk(rune) ? _cjkPerToken : _latinPerToken;
    }
    return tokens.ceil();
  }

  static bool _isCjk(int rune) {
    return (rune >= 0x2E80 && rune <= 0x9FFF) ||
        (rune >= 0xF900 && rune <= 0xFAFF) ||
        (rune >= 0xFF00 && rune <= 0xFFEF) ||
        (rune >= 0x3000 && rune <= 0x303F);
  }

  /// Collapses the whitespace that survives copy-paste out of a browser or a
  /// PDF reader, so a paragraph of ragged indentation does not become its own
  /// chunk boundary.
  static String _normalize(String text) {
    return text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }

  static List<_Piece> _pieces(String paragraph) {
    final pieces = <_Piece>[];
    var index = 0;
    for (final match in _sentenceEnd.allMatches(paragraph)) {
      final end = match.end;
      final slice = paragraph.substring(index, end);
      if (slice.trim().isNotEmpty) {
        pieces.add(_Piece(slice.trim(), isBreak: true));
      }
      index = end;
    }
    if (index < paragraph.length) {
      final rest = paragraph.substring(index);
      if (rest.trim().isNotEmpty) pieces.add(_Piece(rest.trim()));
    }
    return pieces;
  }

  /// Last resort for a sentence longer than a chunk can hold.
  List<String> _hardSplit(String text) {
    final parts = <String>[];
    var current = StringBuffer();
    var currentTokens = 0.0;
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      current.write(char);
      currentTokens += _isCjk(rune) ? _cjkPerToken : _latinPerToken;
      if (currentTokens >= targetTokens) {
        parts.add(current.toString());
        current = StringBuffer();
        currentTokens = 0;
      }
    }
    if (current.isNotEmpty && current.toString().trim().isNotEmpty) {
      parts.add(current.toString());
    }
    return parts;
  }

  static int _tokensOf(List<_Piece> pieces) {
    var total = 0;
    for (final piece in pieces) {
      total += estimateTokens(piece.text);
    }
    return total;
  }

  /// Sentences were split on their terminator, so the terminator is kept with
  /// the sentence it closes rather than starting the next one.
  static String _join(List<_Piece> pieces) => pieces.map((p) => p.text).join();
}

/// A sentence, and whether it ends a sentence. Kept for the overlap walk so
/// a carried tail does not start on a fragment.
class _Piece {
  const _Piece(this.text, {this.isBreak = false});

  final String text;
  final bool isBreak;
}