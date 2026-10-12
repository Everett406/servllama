import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/chat/widgets/answer_markdown.dart';

/// A phone-width column, which is where both of these regressed.
const Size _phone = Size(360, 640);

const _wideTable = '''
| 姓名 | 性别 | 年龄 | 城市 | 备注 |
| --- | --- | --- | --- | --- |
| 张三丰 | 男 | 二十岁 | 北京市海淀区 | 班长兼体育委员 |
| 李四郎 | 女 | 十九岁 | 上海市浦东新区 | 学习委员 |
''';

const _headings = '''
# 表格示例

# 学生信息表
''';

Future<void> _pump(WidgetTester tester, String content) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: _phone.width,
            child: AnswerMarkdown(content: content, isStreaming: false, style: const TextStyle(fontSize: 15)),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a wide table overflows and scrolls instead of collapsing', (
    tester,
  ) async {
    await _pump(tester, _wideTable);

    final table = tester.widget<Table>(find.byType(Table));
    final width = tester.getSize(find.byType(Table)).width;

    // The bug: FlexColumnWidth divides the available width, so the table
    // came out exactly as wide as the screen with every column crushed to
    // one glyph per line. A table sized to its content is *wider* than the
    // viewport and the package's viewport scrolls it sideways.
    expect(
      width,
      greaterThan(_phone.width),
      reason: 'columns were compressed to fit; they should keep their content width',
    );

    final horizontal = find.descendant(
      of: find.byType(AnswerMarkdown),
      matching: find.byType(SingleChildScrollView),
    );
    expect(
      horizontal,
      findsWidgets,
      reason: 'the wide table needs something to scroll it',
    );

    // The per-cell inset is generous; stacked single characters were also
    // what made the old table ~400dp tall for five cells.
    expect(table.border, isNotNull);
    expect(tester.getSize(find.byType(Table)).height, lessThan(400));
  });

  testWidgets('a second-level heading sits close under a first-level one', (
    tester,
  ) async {
    await _pump(tester, _headings);

    final first = _topOfText(tester, '表格示例');
    final second = _topOfText(tester, '学生信息表');

    // With one flat 22dp for every level, an h2 sitting under an h1 opens as
    // much space as a section break and the pair reads as unrelated.
    final gap = second - first;
    expect(
      gap,
      lessThan(140),
      reason: 'a nested heading should not claim a title\'s worth of space',
    );
    expect(gap, greaterThan(0));
  });
}

/// Vertical offset of the rendered text whose plain content is [text].
double _topOfText(WidgetTester tester, String text) {
  for (final e in find.byType(RichText).evaluate()) {
    final rich = e.widget as RichText;
    if (rich.text.toPlainText().trim() == text) return (e.renderObject! as RenderBox).localToGlobal(Offset.zero).dy;
  }
  fail('no RichText with plain text "$text"');
}
