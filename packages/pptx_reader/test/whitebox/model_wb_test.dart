// Kiểm thử hộp trắng A19 — lib/src/model.dart (mã bộ M*, xem
// test-output/whitebox/pptx-reader/model/buoc-5-du-lieu-thu.md).
import 'package:pptx_reader/src/model.dart';
import 'package:test/test.dart';

void main() {
  group('M1 PptxRect ==', () {
    const a = PptxRect(1, 2, 3, 4);
    test('M1.1 cùng 4 giá trị ⇒ bằng, hashCode bằng', () {
      expect(a == const PptxRect(1, 2, 3, 4), isTrue);
      expect(a.hashCode, const PptxRect(1, 2, 3, 4).hashCode);
    });
    test('M1.2 khác kiểu ⇒ không bằng', () {
      // ignore: unrelated_type_equality_checks
      expect(a == 'PptxRect(1, 2, 3, 4)', isFalse);
    });
    test('M1.3 khác x ⇒ không bằng', () => expect(a == const PptxRect(9, 2, 3, 4), isFalse));
    test('M1.4 khác y ⇒ không bằng', () => expect(a == const PptxRect(1, 9, 3, 4), isFalse));
    test('M1.5 khác cx ⇒ không bằng', () => expect(a == const PptxRect(1, 2, 9, 4), isFalse));
    test('M1.6 khác cy ⇒ không bằng', () => expect(a == const PptxRect(1, 2, 3, 9), isFalse));
  });
}
