// Kiểm thử hộp trắng (A02) — lib/features/pdf_tools/engine/page_ranges.dart
// Mã bộ & kết quả mong đợi chép từ test-output/whitebox/pdf-tools/page_ranges/buoc-5-du-lieu-thu.md
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/engines/pdf/pdf_tools_engine.dart';
import 'package:pdf_office/features/pdf_tools/engine/page_ranges.dart';

/// Khoảng giả bỏ qua `assert` của [PageRange] (giống bản release không có assert).
class _FakeRange implements PageRange {
  const _FakeRange(this.start, this.end);
  @override
  final int start;
  @override
  final int end;
  @override
  String toString() => '$start-$end';
}

/// Bắt kết quả hoặc lỗi để khẳng định nhánh trước rồi mới khẳng định kết quả.
Object? run(Object? Function() f) {
  try {
    return f();
  } catch (e) {
    return e;
  }
}

void main() {
  group('U1 parsePageRanges', () {
    test('PR-1 "2-3" (5 trang) ⇒ [2-3]', () {
      final r = run(() => parsePageRanges('2-3', 5));
      expect(r, isA<List<PageRange>>());
      expect(r, [const PageRange(2, 3)]);
    });
    test('PR-2 chỉ có dấu phân cách ⇒ FormatException (rỗng)', () {
      final r = run(() => parsePageRanges(' , ; ', 5));
      expect(r, isA<FormatException>());
      expect((r! as FormatException).message, 'empty'); // nhánh D1 Đ
    });
    test('PR-3 "2-3, 4-5" ⇒ [2-3, 4-5]', () {
      expect(run(() => parsePageRanges('2-3, 4-5', 5)), [
        const PageRange(2, 3),
        const PageRange(4, 5),
      ]);
    });
    test('PR-4 "4" ⇒ [4-4]', () {
      expect(run(() => parsePageRanges('4', 5)), [const PageRange(4, 4)]);
    });
    test('PR-5 "a" ⇒ FormatException sai cú pháp', () {
      final r = run(() => parsePageRanges('a', 5));
      expect(r, isA<FormatException>());
      expect((r! as FormatException).message, contains('invalid range'));
    });
    test('PR-6 "0-2" ⇒ FormatException (trang < 1)', () {
      final r = run(() => parsePageRanges('0-2', 5));
      expect(r, isA<FormatException>());
      expect((r! as FormatException).message, contains('invalid range'));
    });
    test('PR-7 "3-1" ⇒ FormatException (đầu sau cuối)', () {
      final r = run(() => parsePageRanges('3-1', 5));
      expect(r, isA<FormatException>());
      expect((r! as FormatException).message, contains('invalid range'));
    });
    test('PR-8 "2-9" (5 trang) ⇒ FormatException ngoài 1..5', () {
      final r = run(() => parsePageRanges('2-9', 5));
      expect(r, isA<FormatException>());
      expect((r! as FormatException).message, contains('out of 1..5')); // từ validateRanges
    });
  });

  group('U2 validateRanges', () {
    test('VR-1 [2-4] (5 trang) ⇒ hợp lệ', () {
      expect(run(() => validateRanges(const [PageRange(2, 4)], 5)), isNull);
    });
    test('VR-2 [] ⇒ ArgumentError', () {
      expect(run(() => validateRanges(const [], 5)), isA<ArgumentError>());
    });
    test('VR-3 [1-1, 2-4] ⇒ hợp lệ', () {
      expect(
        run(() => validateRanges(const [PageRange(1, 1), PageRange(2, 4)], 5)),
        isNull,
      );
    });
    test('VR-4 khoảng giả 0-2 ⇒ FormatException', () {
      expect(run(() => validateRanges(const [_FakeRange(0, 2)], 5)), isA<FormatException>());
    });
    test('VR-5 khoảng giả 3-1 ⇒ FormatException', () {
      expect(run(() => validateRanges(const [_FakeRange(3, 1)], 5)), isA<FormatException>());
    });
    test('VR-6 [2-9] (5 trang) ⇒ FormatException', () {
      expect(run(() => validateRanges(const [PageRange(2, 9)], 5)), isA<FormatException>());
    });
  });

  group('U3 planSplit', () {
    test('PS-1 mỗi trang, 3 trang ⇒ [1-1, 2-2, 3-3]', () {
      expect(run(() => planSplit(const SplitEveryPage(), 3)), [
        const PageRange(1, 1),
        const PageRange(2, 2),
        const PageRange(3, 3),
      ]);
    });
    test('PS-2 pageCount 0 ⇒ ArgumentError', () {
      expect(run(() => planSplit(const SplitEveryPage(), 0)), isA<ArgumentError>());
    });
    test('PS-3 mỗi 4 trang, 10 trang ⇒ [1-4, 5-8, 9-10]', () {
      expect(run(() => planSplit(const SplitEveryN(4), 10)), [
        const PageRange(1, 4),
        const PageRange(5, 8),
        const PageRange(9, 10),
      ]);
    });
    test('PS-4 theo khoảng [2-4], 5 trang ⇒ [2-4]', () {
      expect(run(() => planSplit(const SplitByRanges([PageRange(2, 4)]), 5)), [
        const PageRange(2, 4),
      ]);
    });
    test('PS-5 theo khoảng [2-9], 5 trang ⇒ FormatException', () {
      expect(
        run(() => planSplit(const SplitByRanges([PageRange(2, 9)]), 5)),
        isA<FormatException>(),
      );
    });
  });

  group('U4 rangeLabel', () {
    test('RL-1 (1,3) ⇒ "1-3"', () => expect(rangeLabel(const PageRange(1, 3)), '1-3'));
    test('RL-2 (4,4) ⇒ "4"', () => expect(rangeLabel(const PageRange(4, 4)), '4'));
  });

  group('U5 validatePageOps', () {
    test('VP-1 [0] (3 trang) ⇒ hợp lệ', () {
      expect(run(() => validatePageOps(const [PageOp(0)], 3)), isNull);
    });
    test('VP-2 [] ⇒ ArgumentError', () {
      final r = run(() => validatePageOps(const [], 3));
      expect(r, isA<ArgumentError>());
      expect(r, isNot(isA<RangeError>()));
    });
    test('VP-3 [0, 2 xoay 90] ⇒ hợp lệ', () {
      expect(
        run(() => validatePageOps(const [PageOp(0), PageOp(2, rotation: 90)], 3)),
        isNull,
      );
    });
    test('VP-4 [-1] ⇒ RangeError', () {
      expect(run(() => validatePageOps(const [PageOp(-1)], 3)), isA<RangeError>());
    });
    test('VP-5 [3] (3 trang) ⇒ RangeError', () {
      expect(run(() => validatePageOps(const [PageOp(3)], 3)), isA<RangeError>());
    });
    test('VP-6 [0 xoay 45] ⇒ ArgumentError (không phải RangeError)', () {
      final r = run(() => validatePageOps(const [PageOp(0, rotation: 45)], 3));
      expect(r, isA<ArgumentError>());
      expect(r, isNot(isA<RangeError>()));
    });
  });
}
