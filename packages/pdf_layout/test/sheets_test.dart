import 'package:pdf_layout/pdf_layout.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('3x4 table with an empty cell plus lines outside the table', () {
    final page = mkPage([
      mkLine('Inventory report', marginL, 80),
      mkRow([('Item', 72), ('Stock', 200), ('Note', 330), ('Owner', 460)], 120),
      mkRow([('Bolt', 72), ('120', 200), ('ok', 330), ('An', 460)], 134),
      mkRow([('Nut', 72), ('80', 200), ('Binh', 460)], 148),
      mkLine('Generated automatically.', marginL, 200),
    ]);
    final sheets = detectSheets([page]);
    expect(sheets, hasLength(1));
    final s = sheets.single;
    expect(s.name, 'Page 1');
    expect(s.rows, [
      ['Inventory report'],
      ['Item', 'Stock', 'Note', 'Owner'],
      ['Bolt', '120', 'ok', 'An'],
      ['Nut', '80', '', 'Binh'],
      ['Generated automatically.'],
    ]);
    expect(s.tableRanges, hasLength(1));
    final r = s.tableRanges.single;
    expect((r.firstRow, r.rowCount, r.columnCount), (1, 3, 4));
    expect(r.lastRow, 3);
  });

  test('cells extracted as separate lines are grouped into rows', () {
    final lines = <LayoutLine>[];
    final data = [
      ['Code', 'City', 'Total'],
      ['A1', 'Hà Nội', '10'],
      ['B2', 'Đà Nẵng', '20'],
      ['C3', 'Huế', '30'],
    ];
    for (var r = 0; r < data.length; r++) {
      for (var c = 0; c < 3; c++) {
        // Slightly jittered tops to exercise the row tolerance.
        lines.add(mkLine(data[r][c], 72.0 + c * 150, 100.0 + r * 15 + c * 0.8));
      }
    }
    final s = detectSheets([mkPage(lines)]).single;
    expect(s.rows, data);
    expect(s.tableRanges.single.columnCount, 3);
  });

  test('a word between two columns goes to the nearest column', () {
    final page = mkPage([
      mkRow([('Key', 72), ('Value', 300)], 100),
      mkRow([('alpha', 72), ('one', 300)], 114),
      mkRow([('beta', 72), ('two', 280)], 128), // drifted left, still col 2
      mkRow([('gamma', 72), ('three', 300)], 142),
    ]);
    final s = detectSheets([mkPage(page.lines)]).single;
    expect(s.rows[2], ['beta', 'two']);
    expect(s.tableRanges.single.rowCount, 4);
  });

  test('plain prose is not a table and each line is one cell', () {
    final page = mkPage([
      mkLine('Just a paragraph of text that', marginL, 100, width: fullWidth),
      mkLine('wraps over a couple of lines', marginL, 112, width: fullWidth),
      mkLine('and stops.', marginL, 124),
    ]);
    final s = detectSheets([page]).single;
    expect(s.tableRanges, isEmpty);
    expect(s.rows, [
      ['Just a paragraph of text that'],
      ['wraps over a couple of lines'],
      ['and stops.'],
    ]);
  });

  test('one sheet per page, empty page gives empty sheet', () {
    final sheets = detectSheets([
      mkPage([mkLine('Hello', marginL, 100)]),
      const LayoutPage(index: 1, width: pageW, height: pageH, lines: []),
    ]);
    expect(sheets.map((s) => s.name).toList(), ['Page 1', 'Page 2']);
    expect(sheets[1].rows, isEmpty);
  });
}
