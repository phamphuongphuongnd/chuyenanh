import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/content_index/logic/search_text.dart';

void main() {
  group('foldForSearch / normalizeQuery', () {
    test('bỏ dấu tiếng Việt, đ→d, chữ thường', () {
      expect(foldForSearch('Hợp ĐỒNG mua bán'), 'hop dong mua ban');
      expect(foldForSearch('Đường Trường Sơn'), 'duong truong son');
      expect(foldForSearch('Ỷ Ở Ữ ỵ'), 'y o u y');
      expect(foldForSearch('Café Ñandú'), 'cafe nandu');
    });

    test('giữ đúng độ dài (đổi 1:1), khoảng trắng → dấu cách', () {
      const s = 'Báo\ncáo\tquý I 😀';
      final f = foldForSearch(s);
      expect(f.length, s.length);
      expect(f, 'bao cao quy i 😀');
    });

    test('NFD được gộp NFC trước khi bỏ dấu', () {
      // "Hợp" viết rời: o + móc (U+031B) + nặng (U+0323).
      const nfd = 'Hợp đồng';
      expect(normalizeForSearch(nfd), 'hop dong');
    });

    test('từ khoá: gộp khoảng trắng, bỏ hai đầu', () {
      expect(normalizeQuery('  Hợp   ĐỒNG '), 'hop dong');
      expect(normalizeQuery('hop dong'), 'hop dong');
      expect(normalizeQuery('   '), '');
    });
  });

  group('prepareContent', () {
    test('gọn khoảng trắng, giữ xuống dòng, bỏ ký tự điều khiển', () {
      final r = prepareContent('  Dòng 1 \r\n\r\n  Dòng\t\t2​\u0007  ');
      expect(r.content, 'Dòng 1\nDòng 2');
      expect(r.normalized, 'dong 1 dong 2');
      expect(r.normalized.length, r.content.length);
    });

    test('cắt ở maxChars, không tách đôi emoji', () {
      final r = prepareContent('abc😀def', maxChars: 4);
      expect(r.content, 'abc');
      final r2 = prepareContent('a'.padRight(300000, 'b'));
      expect(r2.content.length, maxContentChars);
    });
  });

  group('buildExcerpt', () {
    test('chữ ngắn: cả đoạn, tô đúng chỗ khớp, không có …', () {
      final e = buildExcerpt('Đây là Hợp đồng thuê nhà', 'hop dong');
      expect(e.text, 'Đây là Hợp đồng thuê nhà');
      expect(e.match, 'Hợp đồng');
      expect(e.before, 'Đây là ');
      expect(e.after, ' thuê nhà');
    });

    test('chữ dài: ~80 ký tự quanh từ khoá, bám ranh giới từ, có …', () {
      final words = List.generate(40, (i) => 'tu$i').join(' ');
      final window = '$words HỢP ĐỒNG $words';
      final e = buildExcerpt(window, 'hop dong');
      expect(e.text.startsWith('…'), isTrue);
      expect(e.text.endsWith('…'), isTrue);
      expect(e.match, 'HỢP ĐỒNG');
      expect(e.text.length, lessThanOrEqualTo(82));
      expect(e.text.length, greaterThan(60));
      // Không cắt giữa từ: sau "…" là đầu một từ "tuN".
      expect(RegExp(r'^…tu\d+ ').hasMatch(e.text), isTrue, reason: e.text);
      expect(RegExp(r' tu\d+…$').hasMatch(e.text), isTrue, reason: e.text);
    });

    test('window không phải đầu/cuối nội dung → thêm … dù đủ ngắn', () {
      final e = buildExcerpt(
        'thuê hợp đồng nhà',
        'hop dong',
        atStart: false,
        atEnd: false,
      );
      expect(e.text, '…thuê hợp đồng nhà…');
      expect(e.match, 'hợp đồng');
    });

    test('xuống dòng hiện thành dấu cách', () {
      final e = buildExcerpt('dòng một\nhợp đồng\ndòng ba', 'hop dong');
      expect(e.text, 'dòng một hợp đồng dòng ba');
    });

    test('không khớp: lấy đầu đoạn, không tô', () {
      final e = buildExcerpt('abc def', 'xyz');
      expect(e.hasMatch, isFalse);
      expect(e.text, 'abc def');
      expect(e.before, 'abc def');
    });
  });
}
