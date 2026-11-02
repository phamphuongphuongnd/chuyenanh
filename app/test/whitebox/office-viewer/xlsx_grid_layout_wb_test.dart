// Kiểm thử hộp trắng A08 — logic/xlsx_grid_layout.dart. Mã bộ theo
// test-output/whitebox/office-viewer/xlsx_grid_layout/buoc-5-du-lieu-thu.md. Expected chép từ Bước 5.
import 'package:flutter_test/flutter_test.dart';
import 'package:office_reader/office_reader.dart' as rd;
import 'package:pdf_office/features/office_viewer/logic/xlsx_grid_layout.dart';

XlsxGridLayout _l({
  List<rd.XlsxRange> merges = const [],
  int rows = 20,
  int cols = 10,
  int frozenRows = 0,
  int frozenCols = 0,
  Map<int, double> widths = const {},
  Map<int, double> heights = const {},
}) => XlsxGridLayout(
  rd.XlsxSheet(
    name: 'S',
    maxRow: rows,
    maxCol: cols,
    cells: const {},
    merges: merges,
    columnWidthsChars: widths,
    rowHeightsPt: heights,
    frozenRows: frozenRows,
    frozenCols: frozenCols,
  ),
);

void main() {
  group('U1 MergeRegion ==', () {
    const m = MergeRegion(1, 2, 3, 4);
    test('U1-P1 cùng giá trị ⇒ bằng', () => expect(m == const MergeRegion(1, 2, 3, 4), isTrue));
    test('U1-P2 khác kiểu ⇒ khác', () => expect(m == ('m' as Object), isFalse));
    test('U1-P3 khác firstRow', () => expect(m == const MergeRegion(9, 2, 3, 4), isFalse));
    test('U1-P4 khác firstCol', () => expect(m == const MergeRegion(1, 9, 3, 4), isFalse));
    test('U1-P5 khác rowSpan', () => expect(m == const MergeRegion(1, 2, 9, 4), isFalse));
    test('U1-P6 khác colSpan', () => expect(m == const MergeRegion(1, 2, 3, 9), isFalse));
  });

  group('U2 columnLabel', () {
    test('U2-P1 0→A, 25→Z, 26→AA, 701→ZZ', () {
      expect(columnLabel(0), 'A');
      expect(columnLabel(25), 'Z');
      expect(columnLabel(26), 'AA');
      expect(columnLabel(701), 'ZZ');
    });
    test('U2-P2 col −1 (vòng 0 lần) ⇒ chuỗi rỗng', () => expect(columnLabel(-1), ''));
  });

  group('U3 constructor', () {
    test('U3-P1 1 vùng gộp ⇒ ô trong vùng trỏ về vùng', () {
      expect(_l(merges: const [rd.XlsxRange(1, 1, 2, 3)]).mergeAt(2, 2), const MergeRegion(1, 1, 2, 3));
    });
    test('U3-P2 không vùng gộp ⇒ null', () => expect(_l().mergeAt(0, 0), isNull));
    test('U3-P3 vùng gộp nằm ngoài maxRow ⇒ không ghi hàng nào ⇒ null', () {
      expect(_l(merges: const [rd.XlsxRange(25, 0, 26, 1)]).mergeAt(25, 0), isNull);
    });
    test('U3-P4 2 vùng cùng hàng ⇒ vùng thứ 2 vẫn tra được', () {
      final l = _l(merges: const [rd.XlsxRange(0, 0, 0, 1), rd.XlsxRange(0, 3, 0, 4)]);
      expect(l.mergeAt(0, 4), const MergeRegion(0, 3, 1, 2));
    });
  });

  group('U4 columnWidth / U5 rowHeight', () {
    test('U4-P1 độ rộng riêng 20 ⇒ 145', () => expect(_l(widths: {1: 20}).columnWidth(1), 145));
    test('U4-P2 không riêng ⇒ mặc định 8.43×7+5', () {
      expect(_l().columnWidth(0), closeTo(8.43 * 7 + 5, 1e-9));
    });
    test('U5-P1 cao riêng 30 pt ⇒ 40', () => expect(_l(heights: {0: 30}).rowHeight(0), 40));
    test('U5-P2 không riêng ⇒ 15 pt ⇒ 20', () => expect(_l().rowHeight(0), 20));
  });

  group('U6 mergeAt', () {
    test('U6-P1 ô trong vùng, không ghim ⇒ vùng đủ', () {
      expect(_l(merges: const [rd.XlsxRange(1, 1, 2, 3)]).mergeAt(1, 2), const MergeRegion(1, 1, 2, 3));
    });
    test('U6-P2 hàng không có vùng ⇒ null', () {
      expect(_l(merges: const [rd.XlsxRange(1, 1, 2, 3)]).mergeAt(0, 0), isNull);
    });
    test('U6-P3 cột trước vùng ⇒ null', () {
      expect(_l(merges: const [rd.XlsxRange(1, 1, 2, 3)]).mergeAt(1, 0), isNull);
    });
    test('U6-P4 cột sau vùng ⇒ null', () {
      expect(_l(merges: const [rd.XlsxRange(1, 1, 2, 3)]).mergeAt(1, 4), isNull);
    });
    test('U6-P5 vùng nằm trọn trong hàng ghim ⇒ giữ nguyên', () {
      expect(_l(frozenRows: 2, merges: const [rd.XlsxRange(0, 0, 1, 3)]).mergeAt(0, 0),
          const MergeRegion(0, 0, 2, 4));
    });
    test('U6-P6 vùng vắt qua ranh giới hàng ghim ⇒ cắt ở hàng ghim', () {
      expect(_l(frozenRows: 2, merges: const [rd.XlsxRange(0, 1, 4, 3)]).mergeAt(0, 1),
          const MergeRegion(0, 1, 2, 3));
    });
    test('U6-P7 vùng nằm trọn trong cột ghim ⇒ giữ nguyên', () {
      expect(_l(frozenCols: 3, merges: const [rd.XlsxRange(1, 0, 2, 1)]).mergeAt(1, 0),
          const MergeRegion(1, 0, 2, 2));
    });
    test('U6-P8 vùng vắt qua ranh giới cột ghim ⇒ cắt ở cột ghim', () {
      expect(_l(frozenCols: 1, merges: const [rd.XlsxRange(1, 0, 2, 3)]).mergeAt(1, 0),
          const MergeRegion(1, 0, 2, 1));
    });
    test('U6-P9 ô ở phần hàng bị cắt ⇒ null', () {
      expect(_l(frozenRows: 2, merges: const [rd.XlsxRange(0, 1, 4, 3)]).mergeAt(3, 1), isNull);
    });
    test('U6-P10 ô ở phần cột bị cắt ⇒ null', () {
      expect(_l(frozenCols: 1, merges: const [rd.XlsxRange(1, 0, 2, 3)]).mergeAt(1, 2), isNull);
    });
    test('U6-P11 vùng 1 hàng × 3 cột ⇒ vẫn là vùng gộp', () {
      expect(_l(merges: const [rd.XlsxRange(1, 1, 1, 3)]).mergeAt(1, 2), const MergeRegion(1, 1, 1, 3));
    });
    test('U6-P12 sau cắt chỉ còn 1×1 ⇒ null', () {
      expect(
        _l(frozenRows: 1, frozenCols: 1, merges: const [rd.XlsxRange(0, 0, 2, 2)]).mergeAt(0, 0),
        isNull,
      );
    });
    test('U6-P13 vùng đầu không chứa cột, vùng sau chứa ⇒ vùng sau', () {
      final l = _l(merges: const [rd.XlsxRange(0, 0, 0, 1), rd.XlsxRange(0, 3, 0, 4)]);
      expect(l.mergeAt(0, 3), const MergeRegion(0, 3, 1, 2));
    });
    test('U6-P1b vùng vượt maxRow ⇒ kẹp theo maxRow', () {
      expect(_l(merges: const [rd.XlsxRange(18, 0, 25, 1)]).mergeAt(19, 0), const MergeRegion(18, 0, 2, 2));
    });
  });
}
