// Kiểm thử hộp trắng A08 — logic/docx_table_grid.dart. Mã bộ theo
// test-output/whitebox/office-viewer/docx_table_grid/buoc-5-du-lieu-thu.md. Expected chép từ Bước 5.
import 'package:flutter_test/flutter_test.dart';
import 'package:office_reader/office_reader.dart' as rd;
import 'package:pdf_office/features/office_viewer/logic/docx_table_grid.dart';

rd.DocxTableCell _c({int span = 1, int rowSpan = 1, bool cont = false}) =>
    rd.DocxTableCell(blocks: const [], gridSpan: span, rowSpan: rowSpan, vMergeContinue: cont);

rd.DocxTable _t(List<List<rd.DocxTableCell>> rows, {List<int> widths = const [1000]}) =>
    rd.DocxTable(
      columnWidthsTwips: widths,
      rows: [for (final r in rows) rd.DocxTableRow(cells: r)],
    );

List<(int, int, int, int)> _cells(TableGrid g) =>
    [for (final c in g.cells) (c.row, c.col, c.rowSpan, c.colSpan)];

void main() {
  group('U1 buildTableGrid', () {
    test('U1-P1 1 hàng 1 ô ⇒ (0,0) 1×1', () {
      final g = buildTableGrid(_t([[_c()]]));
      expect(_cells(g), [(0, 0, 1, 1)]);
      expect(g.rowCount, 1);
      expect(g.colCount, 1);
    });
    test('U1-P2 không hàng ⇒ rỗng, colCount = số cột khai báo', () {
      final g = buildTableGrid(_t(const [], widths: const [1000, 1000]));
      expect(g.cells, isEmpty);
      expect(g.rowCount, 0);
      expect(g.colCount, 2);
    });
    test('U1-P3 hàng không ô ⇒ không đặt ô', () {
      final g = buildTableGrid(_t([[]], widths: const [1000, 1000]));
      expect(g.cells, isEmpty);
      expect(g.rowCount, 1);
      expect(g.colCount, 2);
    });
    test('U1-P4 gridSpan 0 ⇒ phủ 1 cột', () {
      expect(_cells(buildTableGrid(_t([[_c(span: 0)]]))), [(0, 0, 1, 1)]);
    });
    test('U1-P5 ô vMergeContinue chỉ chiếm chỗ, không đặt', () {
      final g = buildTableGrid(_t([
        [_c(rowSpan: 2)],
        [_c(cont: true)],
      ]));
      expect(_cells(g), [(0, 0, 2, 1)]);
    });
    test('U1-P6 rowSpan 0 ⇒ 1 hàng', () {
      expect(_cells(buildTableGrid(_t([[_c(rowSpan: 0)]]))), [(0, 0, 1, 1)]);
    });
    test('U1-P7 rowSpan 5 trong bảng 1 hàng ⇒ cắt còn 1', () {
      expect(_cells(buildTableGrid(_t([[_c(rowSpan: 5)]]))), [(0, 0, 1, 1)]);
    });
    test('U1-P8 ô phủ 2 cột, bảng khai 1 cột ⇒ colCount 2', () {
      final g = buildTableGrid(_t([[_c(span: 2)]]));
      expect(_cells(g), [(0, 0, 1, 2)]);
      expect(g.colCount, 2);
    });
  });

  group('U2 tableColumnWidths', () {
    rd.DocxTable t(List<int> w) => rd.DocxTable(columnWidthsTwips: w, rows: const []);
    test('U2-P1 2000 twips, hệ số 1 ⇒ 100', () {
      expect(tableColumnWidths(t(const [2000]), 1, 1), [100]);
    });
    test('U2-P2 độ rộng 0 ⇒ dự phòng 80', () {
      expect(tableColumnWidths(t(const [0]), 1, 1), [80]);
    });
    test('U2-P3 thiếu số liệu ⇒ dự phòng × hệ số', () {
      expect(tableColumnWidths(t(const []), 2, 2), [160, 160]);
    });
  });
}
