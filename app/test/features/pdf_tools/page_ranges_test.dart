import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/engines/pdf/pdf_tools_engine.dart';
import 'package:pdf_office/features/pdf_tools/engine/page_ranges.dart';

void main() {
  group('parsePageRanges', () {
    test('khoảng, trang lẻ, khoảng trắng', () {
      expect(parsePageRanges('1-3, 5 ;7 - 9', 10), [
        const PageRange(1, 3),
        const PageRange(5, 5),
        const PageRange(7, 9),
      ]);
    });
    test('sai cú pháp / ngoài phạm vi → FormatException', () {
      for (final bad in ['', 'a', '3-1', '0-2', '1-11', '1--2', '2,,x']) {
        expect(
          () => parsePageRanges(bad, 10),
          throwsA(isA<FormatException>()),
          reason: bad,
        );
      }
    });
  });

  group('planSplit', () {
    test('mỗi trang một file', () {
      expect(planSplit(const SplitEveryPage(), 3), [
        const PageRange(1, 1),
        const PageRange(2, 2),
        const PageRange(3, 3),
      ]);
    });
    test('mỗi N trang, phần dư ở file cuối', () {
      expect(planSplit(const SplitEveryN(4), 10), [
        const PageRange(1, 4),
        const PageRange(5, 8),
        const PageRange(9, 10),
      ]);
      expect(planSplit(const SplitEveryN(20), 5), [const PageRange(1, 5)]);
    });
    test('theo khoảng: kiểm phạm vi', () {
      expect(planSplit(const SplitByRanges([PageRange(2, 4)]), 5), [
        const PageRange(2, 4),
      ]);
      expect(
        () => planSplit(const SplitByRanges([PageRange(2, 9)]), 5),
        throwsA(isA<FormatException>()),
      );
      expect(() => planSplit(const SplitByRanges([]), 5), throwsArgumentError);
    });
  });

  test('rangeLabel', () {
    expect(rangeLabel(const PageRange(1, 3)), '1-3');
    expect(rangeLabel(const PageRange(4, 4)), '4');
  });

  test('validatePageOps', () {
    validatePageOps(const [PageOp(0), PageOp(2, rotation: 90)], 3);
    expect(() => validatePageOps(const [], 3), throwsArgumentError);
    expect(() => validatePageOps(const [PageOp(3)], 3), throwsRangeError);
    expect(() => validatePageOps(const [PageOp(-1)], 3), throwsRangeError);
    expect(
      () => validatePageOps(const [PageOp(0, rotation: 45)], 3),
      throwsArgumentError,
    );
  });
}
