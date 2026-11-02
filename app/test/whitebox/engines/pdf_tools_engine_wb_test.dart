// Kiểm thử hộp trắng A11 — lib/engines/pdf/pdf_tools_engine.dart.
// Mã bộ = mã ở test-output/whitebox/engines/pdf_tools_engine/buoc-5-du-lieu-thu.md.
// assert chỉ chạy ở debug/test ⇒ các nhánh "ném AssertionError" là mức unit.
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/engines/pdf/pdf_tools_engine.dart';

/// Giá trị lúc chạy (tránh hằng ⇒ lỗi biên dịch của const constructor).
int _rt(int v) => v;

void main() {
  group('U1 PageRange(start, end) assert', () {
    test('PR-1 1..3 hợp lệ ⇒ tạo được (A1 Đ, A2 Đ)', () {
      final r = PageRange(_rt(1), _rt(3));
      expect((r.start, r.end), (1, 3));
      final one = PageRange(_rt(4), _rt(4));
      expect(one.toString(), '4-4');
    });
    test('PR-2 start = 0 ⇒ AssertionError (A1 S)', () {
      expect(() => PageRange(_rt(0), _rt(3)), throwsA(isA<AssertionError>()));
    });
    test('PR-3 end < start ⇒ AssertionError (A2 S)', () {
      expect(() => PageRange(_rt(3), _rt(2)), throwsA(isA<AssertionError>()));
    });
  });

  group('U2 PageRange ==', () {
    test('EQ-1 cùng start, end ⇒ bằng, cùng hashCode (E1..E3 Đ)', () {
      expect(PageRange(_rt(2), _rt(5)) == PageRange(_rt(2), _rt(5)), isTrue);
      expect(
        PageRange(_rt(2), _rt(5)).hashCode,
        PageRange(_rt(2), _rt(5)).hashCode,
      );
    });
    test('EQ-2 khác kiểu ⇒ không bằng (E1 S)', () {
      // ignore: unrelated_type_equality_checks
      expect(PageRange(_rt(2), _rt(5)) == '2-5', isFalse);
    });
    test('EQ-3 khác start ⇒ không bằng (E2 S)', () {
      expect(PageRange(_rt(1), _rt(5)) == PageRange(_rt(2), _rt(5)), isFalse);
    });
    test('EQ-4 cùng start, khác end ⇒ không bằng (E3 S)', () {
      expect(PageRange(_rt(2), _rt(6)) == PageRange(_rt(2), _rt(5)), isFalse);
    });
  });

  group('U3 SplitEveryN assert', () {
    test('SN-1 N = 1 ⇒ tạo được (N1 Đ)', () {
      expect(SplitEveryN(_rt(1)).pagesPerFile, 1);
    });
    test('SN-2 N = 0 ⇒ AssertionError (N1 S)', () {
      expect(() => SplitEveryN(_rt(0)), throwsA(isA<AssertionError>()));
    });
  });

  group('U4 BlankDocSpec assert', () {
    test('BS-1 pageCount 1 và 1000 ⇒ tạo được (B1 Đ, B2 Đ)', () {
      expect(BlankDocSpec(pageCount: _rt(1)).pageCount, 1);
      expect(BlankDocSpec(pageCount: _rt(1000)).pageCount, 1000);
    });
    test('BS-2 pageCount 0 ⇒ AssertionError (B1 S)', () {
      expect(() => BlankDocSpec(pageCount: _rt(0)), throwsA(isA<AssertionError>()));
    });
    test('BS-3 pageCount 1001 ⇒ AssertionError (B2 S)', () {
      expect(
        () => BlankDocSpec(pageCount: _rt(1001)),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
