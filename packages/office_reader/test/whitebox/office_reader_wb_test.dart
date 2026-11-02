// Kiểm thử hộp trắng (agent A17) cho lib/office_reader.dart.
// Sinh từ Bước 5 (test-output/whitebox/office-reader/office_reader/buoc-5-du-lieu-thu.md).
// Expected chép từ Bước 5 — KHÔNG chỉnh cho khớp code. Tên test bắt đầu bằng mã bộ.
import 'package:office_reader/office_reader.dart';
import 'package:test/test.dart';
Object? _run(Object? Function() f) {
  try {
    return f();
  } catch (e) {
    return e;
  }
}


void main() {
  group('Đơn vị 1 — bề mặt export (không có rẽ nhánh)', () {
    // Đường:  → R1
    test('1-1 gọi mỗi tên export một lần: columnIndex, parseCellRef, formatNumber, formatText, isDateFormat, excelSerialToDate, OfficeFormatException,', () {
      final res = _run(() => [columnIndex('B'), parseCellRef('A1'), formatNumber(1, '0'), formatText('a', '@'), isDateFormat('d'), excelSerialToDate(1).year, const OfficeFormatException('x').message, readDocx, readXlsx].map((e) => e.toString()).take(7).join(','));
      expect(res, '1,(0, 0),1,a,true,1900,x');
    });
  });
}
