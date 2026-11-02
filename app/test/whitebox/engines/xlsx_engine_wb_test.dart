// Kiểm thử hộp trắng A11 — lib/engines/office/xlsx_engine.dart.
// Mã bộ = mã ở test-output/whitebox/engines/xlsx_engine/buoc-5-du-lieu-thu.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/engines/office/xlsx_engine.dart';

void main() {
  // Vùng gộp B2:E4 (0-based: hàng 1..3, cột 1..4), gồm cả hai đầu.
  const m = XlsxMergedRange(1, 1, 3, 4);

  group('U1 XlsxMergedRange.contains', () {
    test('XC-1 ô bên trong và hai góc ⇒ true (D1..D4 Đ)', () {
      expect(m.contains(2, 2), isTrue);
      expect(m.contains(1, 1), isTrue);
      expect(m.contains(3, 4), isTrue);
    });
    test('XC-2 hàng trên vùng ⇒ false (D1 S)', () {
      expect(m.contains(0, 2), isFalse);
    });
    test('XC-3 hàng dưới vùng ⇒ false (D2 S)', () {
      expect(m.contains(4, 2), isFalse);
    });
    test('XC-4 cột trái vùng ⇒ false (D3 S)', () {
      expect(m.contains(2, 0), isFalse);
    });
    test('XC-5 cột phải vùng ⇒ false (D4 S)', () {
      expect(m.contains(2, 5), isFalse);
    });
  });
}
