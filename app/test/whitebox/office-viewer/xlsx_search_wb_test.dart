// Kiểm thử hộp trắng A08 — logic/xlsx_search.dart. Mã bộ theo
// test-output/whitebox/office-viewer/xlsx_search/buoc-5-du-lieu-thu.md. Expected chép từ Bước 5.
import 'package:flutter_test/flutter_test.dart';
import 'package:office_reader/office_reader.dart' as rd;
import 'package:pdf_office/features/office_viewer/logic/xlsx_search.dart';

rd.XlsxCell _c(String t) =>
    rd.XlsxCell(display: t, raw: t, type: rd.XlsxCellType.string, style: rd.XlsxStyle.plain);

rd.XlsxSheet _s(
  Map<(int, int), rd.XlsxCell> cells, {
  Map<int, double> heights = const {},
  Map<int, double> widths = const {},
  double defaultRowHeightPt = 15,
}) => rd.XlsxSheet(
  name: 'S',
  maxRow: 10,
  maxCol: 10,
  cells: cells,
  rowHeightsPt: heights,
  columnWidthsChars: widths,
  defaultRowHeightPt: defaultRowHeightPt,
);

void main() {
  group('U1 XlsxHit ==', () {
    const h = XlsxHit(1, 2, 3);
    test('U1-P1 cùng giá trị ⇒ bằng', () => expect(h == const XlsxHit(1, 2, 3), isTrue));
    test('U1-P2 khác kiểu ⇒ khác', () => expect(h == ('h' as Object), isFalse));
    test('U1-P3 khác sheetIndex', () => expect(h == const XlsxHit(9, 2, 3), isFalse));
    test('U1-P4 khác row', () => expect(h == const XlsxHit(1, 9, 3), isFalse));
    test('U1-P5 khác col', () => expect(h == const XlsxHit(1, 2, 9), isFalse));
  });

  group('U2 findXlsxHits', () {
    test('U2-P1 ô "Hello", tìm "hello" ⇒ 1 kết quả', () {
      expect(findXlsxHits([_s({(0, 0): _c('Hello')})], 'hello'), const [XlsxHit(0, 0, 0)]);
    });
    test('U2-P2 truy vấn rỗng ⇒ rỗng', () {
      expect(findXlsxHits([_s({(0, 0): _c('Hello')})], ''), isEmpty);
    });
    test('U2-P3 không sheet ⇒ rỗng', () => expect(findXlsxHits(const [], 'a'), isEmpty));
    test('U2-P4 sheet không ô ⇒ rỗng', () => expect(findXlsxHits([_s(const {})], 'a'), isEmpty));
    test('U2-P5 hàng có chiều cao riêng 30 ⇒ vẫn tìm thấy', () {
      expect(findXlsxHits([_s({(0, 0): _c('abc')}, heights: {0: 30})], 'abc'), const [XlsxHit(0, 0, 0)]);
    });
    test('U2-P6 cột có độ rộng riêng 20 ⇒ vẫn tìm thấy', () {
      expect(findXlsxHits([_s({(0, 0): _c('abc')}, widths: {0: 20})], 'abc'), const [XlsxHit(0, 0, 0)]);
    });
    test('U2-P7 hàng ẩn (cao 0) ⇒ bỏ qua', () {
      expect(findXlsxHits([_s({(0, 0): _c('abc')}, heights: {0: 0})], 'abc'), isEmpty);
    });
    test('U2-P8 cột ẩn (rộng 0) ⇒ bỏ qua', () {
      expect(findXlsxHits([_s({(0, 0): _c('abc')}, widths: {0: 0})], 'abc'), isEmpty);
    });
    test('U2-P9 ô hiển thị rỗng ⇒ không khớp', () {
      expect(findXlsxHits([_s({(0, 0): _c('')})], 'a'), isEmpty);
    });
    test('U2-P10 không chứa truy vấn ⇒ rỗng', () {
      expect(findXlsxHits([_s({(0, 0): _c('xyz')})], 'abc'), isEmpty);
    });
    test('U2-P7b chiều cao mặc định 0 (mọi hàng ẩn) ⇒ bỏ qua', () {
      expect(findXlsxHits([_s({(0, 0): _c('abc')}, defaultRowHeightPt: 0)], 'abc'), isEmpty);
    });
  });

  group('U3 sắp xếp sheet → hàng → cột', () {
    test('U3-P1 khác hàng ⇒ theo hàng', () {
      expect(findXlsxHits([_s({(1, 0): _c('a'), (0, 0): _c('a')})], 'a'),
          const [XlsxHit(0, 0, 0), XlsxHit(0, 1, 0)]);
    });
    test('U3-P2 cùng hàng ⇒ theo cột', () {
      expect(findXlsxHits([_s({(0, 5): _c('a'), (0, 2): _c('a')})], 'a'),
          const [XlsxHit(0, 0, 2), XlsxHit(0, 0, 5)]);
    });
  });
}
