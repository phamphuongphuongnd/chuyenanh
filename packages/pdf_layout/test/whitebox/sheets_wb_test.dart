// Kiểm thử hộp trắng (A18) — lib/src/sheets.dart. Mong đợi chép từ buoc-5-du-lieu-thu.md.
import 'package:pdf_layout/pdf_layout.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  test('U1-P1 TableItem ⇒ vùng bảng bắt đầu sau dòng tiêu đề', () {
    final page = mkPage([
      mkLine('Title line', marginL, 100),
      for (var r = 0; r < 3; r++)
        mkRow([
          ('A${r + 1}', 72),
          ('B${r + 1}', 200),
          ('C${r + 1}', 330),
        ], 140.0 + 14 * r),
    ]);
    final sheets = detectSheets([page]);
    expect(sheets, hasLength(1));
    final s = sheets.single;
    // nhánh RowItem trước, rồi TableItem
    expect(s.rows.first, ['Title line']);
    expect(s.tableRanges, hasLength(1));
    final t = s.tableRanges.single;
    expect((t.firstRow, t.rowCount, t.columnCount, t.lastRow), (1, 3, 3, 3));
    expect(s.rows[1], ['A1', 'B1', 'C1']);
  });

  test('U1-P2 RowItem ⇒ 1 ô cột A, không vùng bảng, tên Page 5', () {
    final page = mkPage([mkLine('Just one line', marginL, 100)], index: 4);
    final s = detectSheets([page]).single;
    expect(s.tableRanges, isEmpty);
    expect(s.rows, [
      ['Just one line'],
    ]);
    expect(s.name, 'Page 5');
  });
}
