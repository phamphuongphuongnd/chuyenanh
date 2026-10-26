import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/reader/logic/page_range.dart';

List<int> ok(String s, int n) {
  final r = parsePageRange(s, n);
  expect(r, isA<PageRangeOk>(), reason: s);
  return (r as PageRangeOk).pages;
}

PageRangeIssue bad(String s, int n) {
  final r = parsePageRange(s, n);
  expect(r, isA<PageRangeInvalid>(), reason: s);
  return (r as PageRangeInvalid).issue;
}

void main() {
  group('parsePageRange', () {
    test('một trang, một khoảng, trộn — trả về 0-based, tăng dần', () {
      expect(ok('3', 10), [2]);
      expect(ok('1-3', 10), [0, 1, 2]);
      expect(ok('1-3,5', 10), [0, 1, 2, 4]);
      expect(ok('5, 1-2', 10), [0, 1, 4]);
    });

    test('bỏ trùng', () {
      expect(ok('1-3,2-4,3', 10), [0, 1, 2, 3]);
    });

    test('khoảng mở "5-" đến hết, cho phép dấu gạch dài và khoảng trắng', () {
      expect(ok('8-', 10), [7, 8, 9]);
      expect(ok(' 2 – 3 ; 9 ', 10), [1, 2, 8]);
    });

    test('rỗng', () {
      expect(bad('', 10), PageRangeIssue.empty);
      expect(bad('  ', 10), PageRangeIssue.empty);
    });

    test('sai cú pháp', () {
      expect(bad('abc', 10), PageRangeIssue.syntax);
      expect(bad('1,,2', 10), PageRangeIssue.syntax);
      expect(bad('1-2-3', 10), PageRangeIssue.syntax);
      expect(bad('-3', 10), PageRangeIssue.syntax);
      expect(bad('1.5', 10), PageRangeIssue.syntax);
    });

    test('ngoài phạm vi', () {
      expect(bad('0', 10), PageRangeIssue.outOfRange);
      expect(bad('11', 10), PageRangeIssue.outOfRange);
      expect(bad('9-12', 10), PageRangeIssue.outOfRange);
    });

    test('khoảng ngược', () {
      expect(bad('5-3', 10), PageRangeIssue.reversed);
    });

    test('số quá lớn không làm tràn', () {
      expect(bad('99999999999999999999', 10), PageRangeIssue.outOfRange);
    });
  });

  group('parseJumpPage', () {
    test('hợp lệ trả về số trang 1-based', () {
      expect(parseJumpPage('5', 20), 5);
      expect(parseJumpPage(' 20 ', 20), 20);
      expect(parseJumpPage('1', 20), 1);
    });
    test('không hợp lệ trả về null', () {
      expect(parseJumpPage('', 20), isNull);
      expect(parseJumpPage('0', 20), isNull);
      expect(parseJumpPage('21', 20), isNull);
      expect(parseJumpPage('x', 20), isNull);
      expect(parseJumpPage('-1', 20), isNull);
    });
  });

  group('formatPageRanges', () {
    test('gộp các trang liên tiếp thành khoảng', () {
      expect(formatPageRanges([0, 1, 2, 4, 6, 7]), '1-3, 5, 7-8');
      expect(formatPageRanges([]), '');
    });
  });
}
