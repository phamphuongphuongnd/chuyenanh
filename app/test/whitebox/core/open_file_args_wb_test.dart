// Kiểm thử hộp trắng (A10, chủ đề core) — lib/core/navigation/open_file_args.dart.
// Bộ dữ liệu + kết quả mong đợi: test-output/whitebox/core/open_file_args/buoc-5-du-lieu-thu.md
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/navigation/open_file_args.dart';

void main() {
  group('U1 OpenFileArgs ==', () {
    // Dựng lúc chạy (không const) để == thật sự được gọi, không trùng thể hiện.
    OpenFileArgs a(String path, {String? pw, int? page}) =>
        OpenFileArgs(path, password: pw, initialPage: page);

    test('1.1 cùng path, password, initialPage ⇒ bằng nhau, cùng hashCode', () {
      final x = a('/d/a.pdf', pw: 'pw', page: 2);
      final y = a('/d/a.pdf', pw: 'pw', page: 2);
      expect(identical(x, y), isFalse);
      expect(x == y, isTrue);
      expect(x.hashCode, y.hashCode);
    });

    test('1.2 so với đối tượng khác kiểu ⇒ khác', () {
      // ignore: unrelated_type_equality_checks
      expect(a('/d/a.pdf') == '/d/a.pdf', isFalse);
    });

    test('1.3 khác path ⇒ khác', () {
      expect(a('/d/a.pdf', pw: 'pw', page: 2) == a('/d/b.pdf', pw: 'pw', page: 2), isFalse);
    });

    test('1.4 khác password ⇒ khác', () {
      expect(a('/d/a.pdf', pw: 'pw', page: 2) == a('/d/a.pdf', pw: 'x', page: 2), isFalse);
    });

    test('1.5 khác initialPage ⇒ khác', () {
      expect(a('/d/a.pdf', pw: 'pw', page: 2) == a('/d/a.pdf', pw: 'pw', page: 3), isFalse);
    });
  });
}
