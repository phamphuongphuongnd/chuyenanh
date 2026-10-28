import 'package:flutter_test/flutter_test.dart';
import 'package:office_reader/office_reader.dart' as rd;
import 'package:pdf_office/features/office_viewer/logic/xlsx_search.dart';

rd.XlsxCell _c(String t) => rd.XlsxCell(
  display: t,
  raw: t,
  type: rd.XlsxCellType.string,
  style: rd.XlsxStyle.plain,
);

rd.XlsxSheet _sheet(String name, Map<(int, int), rd.XlsxCell> cells) =>
    rd.XlsxSheet(name: name, maxRow: 10, maxCol: 10, cells: cells);

void main() {
  final sheets = [
    _sheet('A', {
      (2, 1): _c('Hello World'),
      (0, 3): _c('hello'),
      (0, 1): _c('nothing'),
      (2, 0): _c('HELLO'),
    }),
    _sheet('B', {(1, 1): _c('say HeLLo')}),
  ];

  test('truy vấn rỗng → không có kết quả', () {
    expect(findXlsxHits(sheets, ''), isEmpty);
  });

  test('không phân biệt hoa thường, thứ tự sheet → hàng → cột', () {
    expect(findXlsxHits(sheets, 'hello'), const [
      XlsxHit(0, 0, 3),
      XlsxHit(0, 2, 0),
      XlsxHit(0, 2, 1),
      XlsxHit(1, 1, 1),
    ]);
  });

  test('không khớp → rỗng', () {
    expect(findXlsxHits(sheets, 'zzz'), isEmpty);
  });

  test('tìm trên chuỗi hiển thị chứ không phải giá trị thô', () {
    final s = _sheet('N', {
      (0, 0): const rd.XlsxCell(
        display: '12,5%',
        raw: 0.125,
        type: rd.XlsxCellType.number,
        style: rd.XlsxStyle.plain,
      ),
    });
    expect(findXlsxHits([s], '12,5%'), const [XlsxHit(0, 0, 0)]);
    expect(findXlsxHits([s], '0.125'), isEmpty);
  });

  test('bỏ qua ô ở hàng ẩn (chiều cao 0)', () {
    final s = rd.XlsxSheet(
      name: 'H',
      maxRow: 5,
      maxCol: 5,
      cells: {(0, 0): _c('abc'), (1, 0): _c('abc'), (2, 1): _c('abc')},
      rowHeightsPt: const {1: 0},
    );
    expect(findXlsxHits([s], 'abc'), const [
      XlsxHit(0, 0, 0),
      XlsxHit(0, 2, 1),
    ]);
  });

  test('bỏ qua ô ở cột ẩn (độ rộng 0)', () {
    final s = rd.XlsxSheet(
      name: 'C',
      maxRow: 5,
      maxCol: 5,
      cells: {(0, 0): _c('abc'), (0, 1): _c('abc'), (1, 2): _c('abc')},
      columnWidthsChars: const {1: 0},
    );
    expect(findXlsxHits([s], 'abc'), const [
      XlsxHit(0, 0, 0),
      XlsxHit(0, 1, 2),
    ]);
  });
}
