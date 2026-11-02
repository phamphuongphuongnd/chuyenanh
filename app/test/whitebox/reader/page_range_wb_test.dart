// Kiểm thử hộp trắng (A09 · reader) — page_range.dart.
// Bộ dữ liệu + expected chép từ test-output/whitebox/reader/page_range/buoc-5-du-lieu-thu.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/reader/logic/page_range.dart';

List<int>? _ok(String s, int n) {
  final r = parsePageRange(s, n);
  return r is PageRangeOk ? r.pages : null;
}

PageRangeIssue? _bad(String s, int n) {
  final r = parsePageRange(s, n);
  return r is PageRangeInvalid ? r.issue : null;
}

void main() {
  group('parsePageRange', () {
    test('PR-1 "2-4" / 10 ⇒ [1,2,3]', () => expect(_ok('2-4', 10), [1, 2, 3]));
    test('PR-2 rỗng / chỉ khoảng trắng ⇒ empty', () {
      expect(_bad('', 10), PageRangeIssue.empty);
      expect(_bad('   ', 10), PageRangeIssue.empty);
    });
    test('PR-3 "2-4,6" / 10 ⇒ [1,2,3,5]', () => expect(_ok('2-4,6', 10), [1, 2, 3, 5]));
    test('PR-4 "1,,2" ⇒ syntax', () => expect(_bad('1,,2', 10), PageRangeIssue.syntax));
    test('PR-5 "1-2-3" ⇒ syntax', () => expect(_bad('1-2-3', 10), PageRangeIssue.syntax));
    test('PR-6 "a-3" ⇒ syntax', () => expect(_bad('a-3', 10), PageRangeIssue.syntax));
    test('PR-7 "3" / 10 ⇒ [2]', () => expect(_ok('3', 10), [2]));
    test('PR-8 "8-" / 10 ⇒ [7,8,9]', () => expect(_ok('8-', 10), [7, 8, 9]));
    test('PR-9 "2-x" ⇒ syntax', () => expect(_bad('2-x', 10), PageRangeIssue.syntax));
    test('PR-10 "0-3" / 10 ⇒ outOfRange', () => expect(_bad('0-3', 10), PageRangeIssue.outOfRange));
    test('PR-11 "3-0" / 10 ⇒ Invalid (outOfRange hoặc reversed)', () {
      final r = parsePageRange('3-0', 10);
      expect(r, isA<PageRangeInvalid>());
      expect([PageRangeIssue.outOfRange, PageRangeIssue.reversed], contains((r as PageRangeInvalid).issue));
    });
    test('PR-12 "12-15" / 10 ⇒ outOfRange', () => expect(_bad('12-15', 10), PageRangeIssue.outOfRange));
    test('PR-13 "9-12" / 10 ⇒ outOfRange', () => expect(_bad('9-12', 10), PageRangeIssue.outOfRange));
    test('PR-14 "5-3" / 10 ⇒ reversed', () => expect(_bad('5-3', 10), PageRangeIssue.reversed));
    test('PR-15 "2-3" / 10 ⇒ [1,2]', () => expect(_ok('2-3', 10), [1, 2]));
  });

  group('_parseInt (qua parsePageRange)', () {
    test('PI-1 "5" ⇒ [4]', () => expect(_ok('5', 10), [4]));
    test('PI-2 "-3" (vế trái rỗng) ⇒ syntax', () => expect(_bad('-3', 10), PageRangeIssue.syntax));
    test('PI-3 "abc", "1.5" ⇒ syntax', () {
      expect(_bad('abc', 10), PageRangeIssue.syntax);
      expect(_bad('1.5', 10), PageRangeIssue.syntax);
    });
    test('PI-4 "1234567890" (10 chữ số) ⇒ outOfRange, không tràn', () {
      expect(_bad('1234567890', 10), PageRangeIssue.outOfRange);
    });
  });

  group('parseJumpPage', () {
    test('PJ-1 "5" / 20 ⇒ 5; " 20 " ⇒ 20', () {
      expect(parseJumpPage('5', 20), 5);
      expect(parseJumpPage(' 20 ', 20), 20);
    });
    test('PJ-2 không phải số / rỗng / âm / 10 chữ số ⇒ null', () {
      expect(parseJumpPage('x', 20), isNull);
      expect(parseJumpPage('', 20), isNull);
      expect(parseJumpPage('-1', 20), isNull);
      expect(parseJumpPage('1234567890', 20), isNull);
    });
    test('PJ-3 "0" ⇒ null', () => expect(parseJumpPage('0', 20), isNull));
    test('PJ-4 "21" / 20 ⇒ null', () => expect(parseJumpPage('21', 20), isNull));
  });

  group('formatPageRanges + flush', () {
    test('FR-1 [0,1,2] ⇒ "1-3" (flush nhánh S)', () => expect(formatPageRanges([0, 1, 2]), '1-3'));
    test('FR-2 [] ⇒ ""', () => expect(formatPageRanges([]), ''));
    test('FR-3 [4] ⇒ "5" (flush nhánh Đ)', () => expect(formatPageRanges([4]), '5'));
    test('FR-4 [0,2] ⇒ "1, 3"; [4,0,1,2] ⇒ "1-3, 5"', () {
      expect(formatPageRanges([0, 2]), '1, 3');
      expect(formatPageRanges([4, 0, 1, 2]), '1-3, 5');
    });
  });
}
