// Kiểm thử hộp trắng (agent A17) cho lib/src/xlsx/xlsx_model.dart.
// Sinh từ Bước 5 (test-output/whitebox/office-reader/xlsx_model/buoc-5-du-lieu-thu.md).
// Expected chép từ Bước 5 — KHÔNG chỉnh cho khớp code. Tên test bắt đầu bằng mã bộ.
import 'package:office_reader/src/xlsx/xlsx_model.dart';
import 'package:test/test.dart';
Object? _run(Object? Function() f) {
  try {
    return f();
  } catch (e) {
    return e;
  }
}

const rg = XlsxRange(1, 1, 3, 4); // B2:E4 (0-based, gồm cả biên)

void main() {
  group('Đơn vị 1 — XlsxRange.contains', () {
    // Đường: D1Đ D2Đ D3Đ D4Đ → R1
    test('1-1 B2:E4 (1,1,3,4) chứa (3,4) — góc dưới phải', () {
      final res = _run(() => rg.contains(3, 4));
      expect(res, isTrue);
    });
    // Đường: D1S → R2
    test('1-2 chứa (0,2) — hàng trên vùng', () {
      final res = _run(() => rg.contains(0, 2));
      expect(res, isFalse);
    });
    // Đường: D1Đ D2S → R2
    test('1-3 chứa (4,2) — hàng dưới vùng', () {
      final res = _run(() => rg.contains(4, 2));
      expect(res, isFalse);
    });
    // Đường: D1Đ D2Đ D3S → R2
    test('1-4 chứa (1,0) — cột trái vùng (đúng hàng biên trên)', () {
      final res = _run(() => rg.contains(1, 0));
      expect(res, isFalse);
    });
    // Đường: D1Đ D2Đ D3Đ D4S → R2
    test('1-5 chứa (2,5) — cột phải vùng', () {
      final res = _run(() => rg.contains(2, 5));
      expect(res, isFalse);
    });
  });
}
