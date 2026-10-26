import 'package:flutter_test/flutter_test.dart';
import 'package:office_reader/office_reader.dart' as rd;
import 'package:pdf_office/features/office_viewer/logic/docx_table_grid.dart';
import 'package:pdf_office/features/office_viewer/logic/xlsx_grid_layout.dart';

rd.XlsxSheet sheet({
  int rows = 20,
  int cols = 10,
  List<rd.XlsxRange> merges = const [],
  int frozenRows = 0,
  int frozenCols = 0,
  Map<int, double> widths = const {},
  Map<int, double> heights = const {},
}) => rd.XlsxSheet(
  name: 'S',
  maxRow: rows,
  maxCol: cols,
  cells: const {},
  merges: merges,
  columnWidthsChars: widths,
  rowHeightsPt: heights,
  frozenRows: frozenRows,
  frozenCols: frozenCols,
);

rd.DocxTableCell dc({int span = 1, int rowSpan = 1, bool cont = false}) =>
    rd.DocxTableCell(
      blocks: const [],
      gridSpan: span,
      rowSpan: rowSpan,
      vMergeContinue: cont,
    );

void main() {
  test('columnLabel', () {
    expect(columnLabel(0), 'A');
    expect(columnLabel(25), 'Z');
    expect(columnLabel(26), 'AA');
    expect(columnLabel(27), 'AB');
    expect(columnLabel(701), 'ZZ');
    expect(columnLabel(702), 'AAA');
  });

  group('XlsxGridLayout', () {
    test('độ rộng cột / cao hàng: mặc định, tường minh, ẩn', () {
      final l = XlsxGridLayout(
        sheet(widths: {1: 20, 2: 0}, heights: {0: 30, 1: 0}),
      );
      expect(l.columnWidth(0), closeTo(8.43 * 7 + 5, 0.001));
      expect(l.columnWidth(1), 145);
      expect(l.columnWidth(2), 0);
      expect(l.rowHeight(0), 40);
      expect(l.rowHeight(1), 0);
      expect(l.rowHeight(2), 20);
    });

    test('ô gộp: mọi ô trong vùng cùng trỏ về ô đầu', () {
      final l = XlsxGridLayout(sheet(merges: const [rd.XlsxRange(1, 1, 2, 3)]));
      const expected = MergeRegion(1, 1, 2, 3);
      for (final (r, c) in [(1, 1), (1, 3), (2, 2), (2, 3)]) {
        expect(l.mergeAt(r, c), expected, reason: '($r,$c)');
      }
      expect(l.mergeAt(0, 1), isNull);
      expect(l.mergeAt(3, 1), isNull);
      expect(l.mergeAt(1, 4), isNull);
    });

    test('ô gộp vắt qua ranh giới freeze bị cắt ở vùng ghim', () {
      final l = XlsxGridLayout(
        sheet(
          frozenRows: 2,
          frozenCols: 1,
          merges: const [rd.XlsxRange(0, 0, 4, 3), rd.XlsxRange(5, 0, 6, 0)],
        ),
      );
      // Vùng 0..4 × 0..3 chỉ giữ phần 0..1 × 0..0 → 2×1.
      expect(l.mergeAt(0, 0), const MergeRegion(0, 0, 2, 1));
      expect(l.mergeAt(1, 0), const MergeRegion(0, 0, 2, 1));
      // Phần còn lại không còn gộp.
      expect(l.mergeAt(0, 1), isNull);
      expect(l.mergeAt(3, 0), isNull);
      // Vùng gộp nằm trọn trong một phía của ranh giới giữ nguyên.
      expect(l.mergeAt(5, 0), const MergeRegion(5, 0, 2, 1));
    });

    test('vùng gộp ngoài vùng ghim giữ nguyên', () {
      final l = XlsxGridLayout(
        sheet(frozenRows: 1, merges: const [rd.XlsxRange(3, 2, 4, 3)]),
      );
      expect(l.mergeAt(4, 3), const MergeRegion(3, 2, 2, 2));
    });

    test('số hàng/cột ghim bị giới hạn', () {
      final l = XlsxGridLayout(sheet(frozenRows: 99, frozenCols: 99));
      expect(l.pinnedRows, 10);
      expect(l.pinnedCols, 5);
    });
  });

  group('buildTableGrid', () {
    test('gridSpan và vMerge', () {
      final table = rd.DocxTable(
        columnWidthsTwips: const [2000, 2000, 2000],
        rows: [
          rd.DocxTableRow(cells: [dc(span: 3)]),
          rd.DocxTableRow(cells: [dc(rowSpan: 2), dc(), dc()]),
          rd.DocxTableRow(cells: [dc(cont: true), dc(span: 2)]),
        ],
      );
      final g = buildTableGrid(table);
      expect(g.rowCount, 3);
      expect(g.colCount, 3);
      expect(g.cells.length, 5);
      expect(
        g.cells.map((c) => (c.row, c.col, c.rowSpan, c.colSpan)).toList(),
        [
          (0, 0, 1, 3),
          (1, 0, 2, 1),
          (1, 1, 1, 1),
          (1, 2, 1, 1),
          (2, 1, 1, 2),
        ],
      );
    });

    test('rowSpan vượt số hàng bị cắt; colCount lấy theo số lớn hơn', () {
      final table = rd.DocxTable(
        columnWidthsTwips: const [1000],
        rows: [
          rd.DocxTableRow(cells: [dc(rowSpan: 5), dc()]),
        ],
      );
      final g = buildTableGrid(table);
      expect(g.colCount, 2);
      expect(g.cells.first.rowSpan, 1);
    });

    test('tableColumnWidths: twips → pt × hệ số, thiếu thì dùng dự phòng', () {
      final table = rd.DocxTable(
        columnWidthsTwips: const [2000],
        rows: const [],
      );
      expect(tableColumnWidths(table, 2, 2, fallback: 50), [200, 100]);
    });
  });
}
