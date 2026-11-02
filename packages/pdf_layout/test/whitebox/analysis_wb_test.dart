// Kiểm thử hộp trắng (A18) — lib/src/analysis.dart. Mong đợi chép từ buoc-5-du-lieu-thu.md.
import 'package:pdf_layout/pdf_layout.dart';
import 'package:pdf_layout/src/analysis.dart';
import 'package:test/test.dart';

import '../helpers.dart';

const _o = RebuildOptions();

LayoutWord _w(String t, double x, {double y = 100, double w = 10, double h = 10, double fs = 10, bool bold = false}) =>
    LayoutWord(text: t, bounds: LayoutRect(left: x, top: y, width: w, height: h), fontSize: fs, bold: bold);

LayoutLine _line(String text, List<LayoutWord> words, {double x = 72, double y = 100, double w = 100, double h = 10, double fs = 10}) =>
    LayoutLine(pageIndex: 0, text: text, bounds: LayoutRect(left: x, top: y, width: w, height: h), fontSize: fs, words: words);

/// Trang 2 cột: trái x 72..(72+lw), phải x rx..(rx+rw); 31 dòng trái, 32 dòng phải, cách 14 pt từ y=100.
LayoutPage _twoCol({
  bool title = false,
  bool footer = false,
  bool leftPresent = true,
  bool rightPresent = true,
  double lw = 200,
  double rx = 320,
  double rw = 200,
  bool leftShort = false,
  bool rightShort = false,
}) => mkPage([
  if (title) mkLine('Title text that runs across both of the columns', 72, 60, width: 448),
  if (leftPresent)
    for (var i = 0; i < 31; i++)
      leftShort ? mkLine('$i', 72, 100.0 + 14 * i, width: 5) : mkLine('Left column text line $i', 72, 100.0 + 14 * i, width: lw),
  if (rightPresent)
    for (var i = 0; i < 32; i++)
      rightShort ? mkLine('$i', 500, 100.0 + 14 * i, width: 5) : mkLine('Right column words $i', rx, 100.0 + 14 * i, width: rw),
  if (footer) mkLine('Footer text that runs across both of the columns', 72, 700, width: 448),
]);

List<Seg> _segs(LayoutPage p) => [for (final l in p.lines) ...segmentLine(l, _o)];

LayoutPage _table3x3({double y0 = 140, String prefix = ''}) => mkPage([
  for (var r = 0; r < 3; r++)
    mkRow([('${prefix}A${r + 1}', 72), ('B${r + 1}', 200), ('C${r + 1}', 330)], y0 + 14 * r),
]);

List<String> _texts(Flow f) => [
  for (final it in f.items)
    switch (it) {
      RowItem r => r.row.text,
      TableItem t => 'T${t.cells.length}x${t.columnCount}',
    },
];

void main() {
  group('U1 Seg.text', () {
    test('U1-P1 dòng nguyên ⇒ chữ của dòng', () {
      final s = segmentLine(mkLine('ab cd', 72, 100), _o);
      expect(s, hasLength(1));
      expect(s.single.isWholeLine, isTrue);
      expect(s.single.text, 'ab cd');
    });
    test('U1-P2 dòng bị tách ô ⇒ chữ của từng đoạn', () {
      final s = segmentLine(mkRow([('Name', 72), ('Age', 300)], 100), _o);
      expect(s.map((e) => e.isWholeLine), [false, false]);
      expect(s.map((e) => e.text), ['Name', 'Age']);
    });
    test('U1-P4 dòng nguyên nhưng text rỗng ⇒ ghép từ words', () {
      final s = segmentLine(_line('   ', [_w('ab', 72), _w('cd', 85)]), _o);
      expect(s.single.text, 'ab cd');
    });
  });

  group('U2 _fontSizeOf', () {
    test('U2-P1 fontSize 12 ⇒ 12', () {
      expect(segmentLine(_line('x', const [], fs: 12), _o).single.fontSize, 12);
    });
    test('U2-P2 fontSize 0, cao 9 ⇒ 9', () {
      expect(segmentLine(_line('x', const [], fs: 0, h: 9), _o).single.fontSize, 9);
    });
    test('U2-P3 fontSize 0, cao 0 ⇒ 10', () {
      expect(segmentLine(_line('x', const [], fs: 0, h: 0), _o).single.fontSize, 10);
    });
  });

  group('U3 joinWords', () {
    test('U3-P1 1 từ', () => expect(joinWords([_w('ab', 0)]), 'ab'));
    test('U3-P2 bỏ từ trắng', () => expect(joinWords([_w('ab', 0), _w('  ', 12), _w('cd', 14)]), 'ab cd'));
    test('U3-P3 2 từ Latin ⇒ 1 dấu cách', () => expect(joinWords([_w('ab', 0), _w('cd', 14)]), 'ab cd'));
    test('U3-P4 fontSize 0 ⇒ dùng chiều cao (CJK khe 5 < 0,25×30)', () {
      expect(joinWords([_w('中', 0, fs: 0, h: 30), _w('文', 15, fs: 0, h: 30)]), '中文');
    });
  });

  group('U4 segmentLine', () {
    test('U4-P1 các từ sát nhau ⇒ 1 đoạn', () => expect(segmentLine(mkLine('ab cd', 72, 100), _o), hasLength(1)));
    test('U4-P2 không có words, có chữ ⇒ 1 đoạn theo bounds', () {
      final s = segmentLine(_line('Hello', const [], x: 50, w: 40), _o).single;
      expect((s.left, s.right, s.words.isEmpty, s.bold, s.text), (50, 90, true, false, 'Hello'));
    });
    test('U4-P3 không words, chữ trắng ⇒ rỗng', () => expect(segmentLine(_line('  ', const []), _o), isEmpty));
    test('U4-P4 1 từ ⇒ 1 đoạn', () => expect(segmentLine(_line('ab', [_w('ab', 72)]), _o), hasLength(1)));
    test('U4-P5 khe 30 > 1×fs ⇒ 2 đoạn', () {
      final s = segmentLine(_line('ab cd', [_w('ab', 72), _w('cd', 112)]), _o);
      expect(s.map((e) => e.text), ['ab', 'cd']);
    });
  });

  group('U5 Row._buildText', () {
    test('U5-P1 1 dòng nguyên ⇒ chữ dòng', () {
      expect(Row(segmentLine(mkLine('ab cd', 72, 100), _o), 0).text, 'ab cd');
    });
    test('U5-P2 đoạn của 2 dòng khác nhau ⇒ nối bằng dấu cách', () {
      final segs = [...segmentLine(mkLine('Name', 72, 100), _o), ...segmentLine(mkLine('Age', 300, 100), _o)];
      expect(Row(segs, 0).text, 'Name Age');
    });
    test('U5-P3 chỉ 1 trong 2 đoạn của dòng ⇒ chữ đoạn đó', () {
      final segs = segmentLine(mkRow([('Name', 72), ('Age', 300)], 100), _o);
      expect(Row([segs.first], 0).text, 'Name');
    });
  });

  group('U6 Row.styledRuns', () {
    test('U6-P1 cùng kiểu chữ ⇒ 1 run', () {
      expect(Row(segmentLine(mkLine('ab cd', 72, 100), _o), 0).styledRuns, [('ab cd', false)]);
    });
    test('U6-P2 không có words ⇒ 1 run', () {
      expect(Row(segmentLine(_line('Hello', const []), _o), 0).styledRuns, [('Hello', false)]);
    });
    test('U6-P3 thường + đậm ⇒ 2 run, dấu cách theo run trước', () {
      final r = Row(segmentLine(_line('Hello World', [_w('Hello', 72, w: 25), _w('World', 100, w: 25, bold: true)]), _o), 0);
      expect(r.styledRuns, [('Hello ', false), ('World', true)]);
    });
    test('U6-P5 fontSize 0 ⇒ khe so với chiều cao (CJK, không cách)', () {
      final r = Row(
        segmentLine(_line('中文', [_w('中', 72, fs: 0, h: 30), _w('文', 87, fs: 0, h: 30, bold: true)], h: 30), _o),
        0,
      );
      expect(r.styledRuns, [('中', false), ('文', true)]);
    });
    test('U6-P7 hai từ thường liền nhau rồi đậm', () {
      final r = Row(segmentLine(_line('A B C', [_w('A', 72), _w('B', 85), _w('C', 98, bold: true)]), _o), 0);
      expect(r.styledRuns, [('A B ', false), ('C', true)]);
    });
  });

  group('U7 _analyzePage (qua analyzePages)', () {
    List<Flow> flows(List<LayoutPage> p, [RebuildOptions o = _o]) => analyzePages(p, o).first.flows;
    test('U7-P1 trang 1 cột ⇒ 1 flow', () {
      final page = mkPage([for (var i = 0; i < 5; i++) mkLine('Body line $i of text', 72, 100.0 + 12 * i, width: 451)]);
      expect(flows([page]), hasLength(1));
    });
    test('U7-P2 header lặp 3 trang ⇒ bị loại khỏi flow', () {
      final pages = [
        for (var p = 0; p < 3; p++)
          mkPage([mkLine('Report header ${p + 1}', 72, 20, page: p), mkLine('Body $p', 72, 400, page: p)], index: p),
      ];
      final all = analyzePages(pages, _o).expand((a) => a.flows).expand(_texts).toList();
      expect(all.where((t) => t.startsWith('Report')), isEmpty);
      expect(all, containsAll(['Body 0', 'Body 1', 'Body 2']));
    });
    test('U7-P3 trang rỗng ⇒ không flow', () => expect(flows([mkPage([])]), isEmpty));
    test('U7-P4 tắt detectColumns ⇒ 1 flow', () {
      expect(flows([_twoCol()], const RebuildOptions(detectColumns: false)), hasLength(1));
    });
    test('U7-P5/P8 2 cột ⇒ 2 flow trái, phải', () {
      final f = flows([_twoCol()]);
      expect(f, hasLength(2));
      expect((f[0].colLeft, f[1].colLeft), (72, 320));
    });
    test('U7-P6/P9 có tiêu đề trên ⇒ 3 flow, flow đầu là tiêu đề', () {
      final f = flows([_twoCol(title: true)]);
      expect(f, hasLength(3));
      expect(_texts(f.first).single, startsWith('Title'));
    });
    test('U7-P7/P10 có chân dưới ⇒ 3 flow, flow cuối là chân', () {
      final f = flows([_twoCol(footer: true)]);
      expect(f, hasLength(3));
      expect(_texts(f.last).single, startsWith('Footer'));
    });
  });

  group('U8 _flowItems', () {
    test('U8-P1 văn xuôi ⇒ toàn RowItem', () {
      final page = mkPage([for (var i = 0; i < 3; i++) mkLine('Prose line $i', 72, 100.0 + 12 * i)]);
      expect(analyzePages([page], _o).single.flows.single.items.every((i) => i is RowItem), isTrue);
    });
    test('U8-P2 tắt detectTables ⇒ bảng thành RowItem', () {
      final items = analyzePages([_table3x3()], const RebuildOptions(detectTables: false)).single.flows.single.items;
      expect(items, hasLength(3));
      expect(items.every((i) => i is RowItem), isTrue);
    });
    test('U8-P4/P5 dòng rồi bảng ⇒ [RowItem, TableItem]', () {
      final page = mkPage([mkLine('Intro line', 72, 100), ..._table3x3().lines]);
      final items = analyzePages([page], _o).single.flows.single.items;
      expect(items.map((i) => i.runtimeType), [RowItem, TableItem]);
    });
  });

  group('U9 findRunningLines', () {
    List<LayoutPage> pages(LayoutLine Function(int p) extra) => [
      for (var p = 0; p < 3; p++)
        mkPage([
          mkLine('Report 2026 page ${p + 1}', 72, 20, page: p),
          mkLine('Body text $p', 72, 400, page: p),
          extra(p),
        ], index: p),
    ];
    test('U9-P1/P4/P7 header lặp ⇒ có trong kết quả, thân bài không', () {
      final ps = pages((p) => mkLine('Body more $p', 72, 500, page: p));
      final r = findRunningLines(ps, _o);
      expect(r, containsAll([for (final p in ps) p.lines[0]]));
      expect(r.any((l) => l.text.startsWith('Body')), isFalse);
    });
    test('U9-P2 1 trang ⇒ rỗng', () {
      expect(findRunningLines([mkPage([mkLine('Report', 72, 20)])], _o), isEmpty);
    });
    test('U9-P3 0 trang, minPages 0 ⇒ rỗng', () {
      expect(findRunningLines(const [], const RebuildOptions(headerFooterMinPages: 0)), isEmpty);
    });
    test('U9-P5 chân trang lặp ⇒ có trong kết quả', () {
      final ps = pages((p) => mkLine('Confidential - ${p + 1}', 72, 800, page: p));
      expect(findRunningLines(ps, _o), containsAll([for (final p in ps) p.lines[2]]));
    });
    test('U9-P6 dòng trắng trong vùng lề ⇒ không có', () {
      final ps = pages((p) => mkLine('   ', 72, 30, page: p, splitWords: false));
      expect(findRunningLines(ps, _o).any((l) => l.text.trim().isEmpty), isFalse);
    });
    test('U9-P8 chỉ 1 trang có ⇒ không có', () {
      final ps = pages((p) => mkLine(p == 0 ? 'Only once' : 'Other $p words', 72, 40, page: p));
      expect(findRunningLines(ps, _o).any((l) => l.text == 'Only once'), isFalse);
    });
    test('U9-P9 cùng chữ nhưng khác độ cao ⇒ không có', () {
      final ps = pages((p) => mkLine('Chapter', 72, 30.0 + 40 * p, page: p));
      expect(findRunningLines(ps, _o).any((l) => l.text == 'Chapter'), isFalse);
    });
  });

  group('U10 findGutter / U11 _validColumns', () {
    Gutter? g(LayoutPage p, [RebuildOptions o = _o]) => findGutter(_segs(p), p, o);
    test('U10-P1/P5/P6/P7, U11-P1 2 cột ⇒ khe giữa 272..320, cao hết nội dung', () {
      final r = g(_twoCol());
      expect(r, isNotNull);
      expect(r!.x, inExclusiveRange(272, 320));
      expect((r.y0, r.y1), (100, 544));
    });
    test('U10-P2 < 6 đoạn ⇒ null', () {
      final p = mkPage([for (var i = 0; i < 5; i++) mkLine('Line $i', 72, 100.0 + 100 * i)]);
      expect(g(p), isNull);
    });
    test('U10-P3 nội dung thấp < 50% trang ⇒ null', () {
      final p = mkPage([
        for (var i = 0; i < 4; i++) mkLine('Left $i', 72, 100.0 + 14 * i, width: 200),
        for (var i = 0; i < 4; i++) mkLine('Right $i', 320, 100.0 + 14 * i, width: 200),
      ]);
      expect(g(p), isNull);
    });
    test('U10-P4 dải tìm rỗng (from > to) ⇒ null', () {
      expect(g(_twoCol(), const RebuildOptions(columnSearchFrom: 0.8, columnSearchTo: 0.2)), isNull);
    });
    test('U10-P8/P9, U11-P3 chỉ có cột trái hẹp ⇒ null', () {
      expect(g(_twoCol(lw: 78, rightPresent: false)), isNull);
    });
    test('U11-P2 chỉ có cột phải ⇒ null', () => expect(g(_twoCol(leftPresent: false)), isNull));
    test('U11-P4 bên trái không phải văn xuôi ⇒ null', () => expect(g(_twoCol(leftShort: true)), isNull));
    test('U11-P5 bên phải không phải văn xuôi ⇒ null', () => expect(g(_twoCol(rightShort: true)), isNull));
  });

  group('U12 groupRows', () {
    List<Row> rows(List<LayoutLine> ls) => groupRows([for (final l in ls) ...segmentLine(l, _o)], 0, _o);
    test('U12-P1 1 đoạn ⇒ 1 hàng', () => expect(rows([mkLine('a', 72, 100)]), hasLength(1)));
    test('U12-P2 2 đoạn cùng y ⇒ 1 hàng, xếp theo left', () {
      final r = rows([mkLine('right', 300, 100), mkLine('left', 72, 100)]);
      expect(r, hasLength(1));
      expect(r.single.segs.map((s) => s.text), ['left', 'right']);
    });
    test('U12-P3 2 đoạn khác y ⇒ 2 hàng', () => expect(rows([mkLine('a', 72, 100), mkLine('b', 72, 120)]), hasLength(2)));
    test('U12-P4 5 đoạn khác y ⇒ 5 hàng theo thứ tự từ trên xuống', () {
      final r = rows([for (var i = 4; i >= 0; i--) mkLine('r$i', 72, 100.0 + 20 * i)]);
      expect(r.map((e) => e.text), ['r0', 'r1', 'r2', 'r3', 'r4']);
    });
  });

  group('U13 _findTables / U14 _analyzeRun (qua detectSheets)', () {
    SheetGrid sheet(LayoutPage p, [RebuildOptions o = _o]) => detectSheets([p], options: o).single;
    test('U13-P1/P3, U14-P1/P2/P3/P6 bảng 3×3 ⇒ đúng ô', () {
      final s = sheet(_table3x3());
      expect(s.tableRanges.single.rowCount, 3);
      expect(s.rows, [
        ['A1', 'B1', 'C1'],
        ['A2', 'B2', 'C2'],
        ['A3', 'B3', 'C3'],
      ]);
    });
    test('U13-P2 dòng văn xuôi trước bảng ⇒ bảng từ hàng 1', () {
      final s = sheet(mkPage([mkLine('Intro', 72, 100), ..._table3x3().lines]));
      expect(s.tableRanges.single.firstRow, 1);
    });
    test('U13-P4 dòng văn xuôi ngay sau bảng ⇒ cắt bảng 3 hàng', () {
      final s = sheet(mkPage([..._table3x3().lines, mkLine('After the table', 72, 182)]));
      expect((s.tableRanges.single.firstRow, s.tableRanges.single.rowCount), (0, 3));
      expect(s.rows.last, ['After the table']);
    });
    test('U13-P5 hai hàng cùng top (khác chiều cao) ⇒ không chung một bảng', () {
      final tall = LayoutLine(
        pageIndex: 0,
        text: 'x y',
        bounds: const LayoutRect(left: 72, top: 100, width: 138, height: 30),
        fontSize: 10,
        words: [_w('x', 72, h: 30), _w('y', 200, h: 30)],
      );
      final p = mkPage([
        mkRow([('a', 72), ('b', 200)], 100),
        tall,
        mkRow([('c', 72), ('d', 200)], 134),
        mkRow([('e', 72), ('f', 200)], 148),
        mkRow([('g', 72), ('h', 200)], 162),
      ]);
      final s = sheet(p);
      expect(s.tableRanges, hasLength(1));
      expect(s.tableRanges.single.firstRow, greaterThanOrEqualTo(1));
    });
    test('U13-P6 khe dọc lớn ⇒ 2 hàng đầu không thành bảng', () {
      final p = mkPage([
        mkRow([('a', 72), ('b', 200)], 100),
        mkRow([('c', 72), ('d', 200)], 114),
        mkRow([('e', 72), ('f', 200)], 300),
        mkRow([('g', 72), ('h', 200)], 314),
        mkRow([('i', 72), ('j', 200)], 328),
      ]);
      final t = sheet(p).tableRanges.single;
      expect((t.firstRow, t.rowCount), (2, 3));
    });
    test('U13-P7 chỉ 2 hàng nhiều ô ⇒ không bảng', () {
      final p = mkPage([mkRow([('a', 72), ('b', 200)], 100), mkRow([('c', 72), ('d', 200)], 114)]);
      expect(sheet(p).tableRanges, isEmpty);
    });
    test('U13-P8, U14-P9 list có tab sau số ⇒ không bảng', () {
      final p = mkPage([
        for (var i = 0; i < 3; i++) mkRow([('${i + 1}.', 72), ('Item text $i', 110)], 100.0 + 14 * i),
      ]);
      expect(sheet(p).tableRanges, isEmpty);
    });
    test('U14-P4 cột 2 lệch mỗi hàng ⇒ < 2 cột neo ⇒ không bảng', () {
      final p = mkPage([
        mkRow([('a', 72), ('b', 200)], 100),
        mkRow([('c', 72), ('d', 300)], 114),
        mkRow([('e', 72), ('f', 400)], 128),
      ]);
      expect(sheet(p).tableRanges, isEmpty);
    });
    test('U14-P5 tableMinColumns 1 ⇒ bảng 1 cột, ô gộp chữ', () {
      final p = mkPage([
        mkRow([('a', 72), ('b', 200)], 100),
        mkRow([('c', 72), ('d', 300)], 114),
        mkRow([('e', 72), ('f', 400)], 128),
      ]);
      final s = sheet(p, const RebuildOptions(tableMinColumns: 1));
      expect(s.tableRanges.single.columnCount, 1);
      expect(s.rows, [
        ['a b'],
        ['c d'],
        ['e f'],
      ]);
    });
    test('U14-P7 chữ lạc giữa 2 cột ⇒ gộp vào ô gần nhất', () {
      final p = mkPage([
        mkRow([('A1', 72), ('x', 95), ('B1', 200), ('C1', 330)], 140),
        mkRow([('A2', 72), ('B2', 200), ('C2', 330)], 154),
        mkRow([('A3', 72), ('B3', 200), ('C3', 330)], 168),
      ]);
      expect(sheet(p).rows.first, ['A1 x', 'B1', 'C1']);
    });
    test('U14-P8 bảng 2 cột thường ⇒ là bảng', () {
      final p = mkPage([
        for (var i = 0; i < 3; i++) mkRow([('Name$i', 72), ('Value$i', 200)], 100.0 + 14 * i),
      ]);
      expect(sheet(p).tableRanges.single.columnCount, 2);
    });
  });

  group('U15 TableItem.columnCount', () {
    test('U15-P1 bảng 3 cột ⇒ 3', () {
      final t = analyzePages([_table3x3()], _o).single.flows.single.items.single as TableItem;
      expect(t.columnCount, 3);
    });
    test('U15-P2 cells rỗng ⇒ 0', () => expect(TableItem(const [], const []).columnCount, 0));
  });
}
