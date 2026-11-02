// Kiểm thử hộp trắng A08 — data/xlsx_mapping.dart. Mã bộ theo
// test-output/whitebox/office-viewer/xlsx_mapping/buoc-5-du-lieu-thu.md. Expected chép từ Bước 5.
import 'package:flutter_test/flutter_test.dart';
import 'package:office_reader/office_reader.dart' as rd;
import 'package:pdf_office/engines/office/xlsx_engine.dart' as eng;
import 'package:pdf_office/features/office_viewer/data/xlsx_mapping.dart';

rd.XlsxCell _cell(
  rd.XlsxCellType type, {
  rd.XlsxHAlign align = rd.XlsxHAlign.general,
}) => rd.XlsxCell(
  display: 'v',
  raw: null,
  type: type,
  style: rd.XlsxStyle(hAlign: align),
);

eng.XlsxSheet _one(
  rd.XlsxCell cell, {
  Map<int, double> widths = const {},
  int maxCol = 1,
}) => mapXlsx(
  rd.XlsxWorkbook(
    sheets: [
      rd.XlsxSheet(
        name: 'S',
        maxRow: 1,
        maxCol: maxCol,
        cells: {(0, 0): cell},
        columnWidthsChars: widths,
      ),
    ],
  ),
).sheets.single;

void main() {
  group('U1 columnWidthPx', () {
    test('U1-P1 10 ký tự ⇒ 75 px', () => expect(columnWidthPx(10), 75));
    test('U1-P2 0 ký tự (cột ẩn) ⇒ 0', () {
      expect(columnWidthPx(0), 0);
      expect(columnWidthPx(-1), 0);
    });
  });

  group('U2 rowHeightPx', () {
    test('U2-P1 15 pt ⇒ 20 px', () => expect(rowHeightPx(15), 20));
    test('U2-P2 0 pt (hàng ẩn) ⇒ 0', () => expect(rowHeightPx(0), 0));
  });

  group('U3 _align', () {
    eng.XlsxHAlign al(rd.XlsxHAlign a) =>
        _one(_cell(rd.XlsxCellType.string, align: a)).cells.single.hAlign;
    test('U3-P1 general ⇒ general', () => expect(al(rd.XlsxHAlign.general), eng.XlsxHAlign.general));
    test('U3-P2 right ⇒ right', () => expect(al(rd.XlsxHAlign.right), eng.XlsxHAlign.right));
    test('U3-P3 center ⇒ center', () => expect(al(rd.XlsxHAlign.center), eng.XlsxHAlign.center));
    test('U3-P4 centerContinuous ⇒ center', () =>
        expect(al(rd.XlsxHAlign.centerContinuous), eng.XlsxHAlign.center));
    test('U3-P5 left ⇒ left', () => expect(al(rd.XlsxHAlign.left), eng.XlsxHAlign.left));
  });

  group('U4 _mapSheet', () {
    test('U4-P1 ô số, cột có độ rộng 10 ⇒ isNumeric, rộng 75', () {
      final s = _one(_cell(rd.XlsxCellType.number), widths: {0: 10});
      expect(s.cells.single.isNumeric, isTrue);
      expect(s.columnWidths, {0: 75});
    });
    test('U4-P2 ô ngày ⇒ isNumeric', () {
      expect(_one(_cell(rd.XlsxCellType.date)).cells.single.isNumeric, isTrue);
    });
    test('U4-P3 ô chuỗi ⇒ không isNumeric', () {
      expect(_one(_cell(rd.XlsxCellType.string)).cells.single.isNumeric, isFalse);
    });
    test('U4-P4 không độ rộng riêng ⇒ mọi cột có độ rộng mặc định', () {
      final s = _one(_cell(rd.XlsxCellType.string), maxCol: 3);
      expect(s.columnWidths.keys.toList(), [0, 1, 2]);
      expect(s.columnWidths[2], closeTo(8.43 * 7 + 5, 1e-9));
    });
  });
}
