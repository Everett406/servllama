/// Splits streaming Markdown so a block that is still arriving is not
/// rendered as itself.
///
/// The problem this solves is not a broken table — gpt_markdown already holds
/// a row back until its newline lands, so a table never forms on half a row.
/// It is that a table *grows*, row by row, right under the user's eye while
/// they are trying to read the rows that are already there. Each new row also
/// reflows the columns above it, so the thing being read is never still.
///
/// So while streaming, a table block that has not closed yet renders as a
/// placeholder, and the real table appears in one go when it does. Nothing is
/// hidden: the placeholder says how many rows are on the way.
library;

/// One piece of a streaming reply.
class StreamSegment {
  const StreamSegment.markdown(this.markdown) : table = null;

  const StreamSegment.openTable(this.table) : markdown = null;

  /// Settled Markdown. Render it with the normal renderer.
  final String? markdown;

  /// A table block that is still arriving. Render it as a placeholder.
  final String? table;

  bool get isOpenTable => table != null;

  /// How many data rows have arrived so far, excluding the header and the
  /// delimiter row. Shown so the placeholder says something better than
  /// "working" — the reader can see it filling up.
  int get openRowCount {
    final rows = table!
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        // A line that is just the leading `|` of a row that is still arriving
        // is not a row yet. Counting it would make the placeholder's number
        // jump around while the reader watches it fill.
        .where((line) => line.trim() != '|');
    return rows.length < 2 ? 0 : rows.length - 2;
  }

  @override
  String toString() =>
      isOpenTable ? 'StreamSegment.openTable(${table!.split('\n').length} lines)'
                  : 'StreamSegment.markdown(${markdown!.length} chars)';
}

/// The Markdown to hand to the renderer for a completed answer.
///
/// An empty string, not the table itself: the table is still being written,
/// and rendering it is exactly the thing we are not doing yet.
String settledMarkdown(List<StreamSegment> segments) {
  return segments
      .where((segment) => !segment.isOpenTable)
      .map((segment) => segment.markdown!)
      .join();
}

/// Split [content] into settled Markdown and open table blocks.
///
/// Only the *trailing* block can be open — anything a model has moved past
/// is by definition finished, and a table closed by a blank line stays
/// rendered even if more prose follows it. There is no such thing as an open
/// block in the middle of a stream, so one scan from the end is enough.
List<StreamSegment> splitStreamingBlocks(String content) {
  if (content.isEmpty) {
    return const <StreamSegment>[];
  }

  final lines = content.split('\n');
  // A trailing newline means the last line is complete; without it the last
  // line may still be arriving and the block it belongs to is open.
  final endsWithNewline = content.endsWith('\n');

  // Find the last run of lines that look like table rows.
  var end = endsWithNewline ? lines.length - 1 : lines.length;
  // A blank line at the end closes whatever came before it.
  while (end > 0 && lines[end - 1].trim().isEmpty) {
    end -= 1;
  }
  if (end == 0) {
    return <StreamSegment>[StreamSegment.markdown(content)];
  }

  var start = end;
  while (start > 0 && _isTableRowLine(lines[start - 1])) {
    start -= 1;
  }
  if (start == end) {
    // The stream does not end in a table, so nothing is open.
    return <StreamSegment>[StreamSegment.markdown(content)];
  }

  // A run of `|` lines is only a table if the second line is the delimiter
  // row. Two data rows with no header separator are just text with pipes.
  if (start + 1 >= end || !_isTableDelimiterRow(lines[start + 1])) {
    return <StreamSegment>[StreamSegment.markdown(content)];
  }

  // Closed if a real blank line follows it — the model has moved on.
  //
  // Not merely "the text ends with a newline". `'a\n'.split('\n')` is
  // `['a', '']`, so the trailing newline always leaves a blank element at
  // `end` and any table would look closed the instant a row finished
  // arriving. That is not a finishing line, it is the carriage return on the
  // way to the next row, and treating it as one made a table blink: closed,
  // then open again on the next character.
  //
  // A blank line the model actually typed leaves its own trailing newline
  // behind it, so `a\n\n` has an empty element that is not the split's
  // artefact. Otherwise the blank line must be followed by more content.
  final closed = end < lines.length && lines[end].trim().isEmpty &&
      (end + 1 < lines.length || content.endsWith('\n\n'));
  if (closed) {
    return <StreamSegment>[StreamSegment.markdown(content)];
  }

  final before = lines.sublist(0, start).join('\n');
  final table = lines.sublist(start, end).join('\n');
  final after = end < lines.length ? lines.sublist(end).join('\n') : '';

  return <StreamSegment>[
    if (before.isNotEmpty) StreamSegment.markdown(before),
    StreamSegment.openTable(table),
    if (after.isNotEmpty) StreamSegment.markdown(after),
  ];
}

bool _isTableRowLine(String line) => line.trimLeft().startsWith('|');

/// `|---|:--:|` and friends: a separator row of dashes, colons and pipes.
bool _isTableDelimiterRow(String line) {
  final trimmed = line.trim();
  if (!_isTableRowLine(trimmed)) return false;
  final inner = trimmed.replaceAll(RegExp(r'^\||\|$'), '');
  if (inner.trim().isEmpty) return false;
  return RegExp(r'^[\s\-:|]+$').hasMatch(inner);
}
