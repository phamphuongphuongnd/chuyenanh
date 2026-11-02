// Kiểm thử hộp trắng (A10, chủ đề core) — lib/core/utils/page_size.dart.
// Bộ dữ liệu + kết quả mong đợi: test-output/whitebox/core/page_size/buoc-5-du-lieu-thu.md
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/utils/page_size.dart';

void main() {
  group('U1 portraitPoints', () {
    test('1.1 letter ⇒ (612, 792)', () {
      expect(PageSizeOption.letter.portraitPoints, (612.0, 792.0));
    });
    test('1.2 a4 ⇒ (595.28, 841.89)', () {
      expect(PageSizeOption.a4.portraitPoints, (595.28, 841.89));
    });
    test('1.3 fit ⇒ như A4', () {
      expect(PageSizeOption.fit.portraitPoints, (595.28, 841.89));
    });
  });

  group('U2 fromName', () {
    test('2.1 tên có ("letter") ⇒ letter', () {
      expect(PageSizeOption.fromName('letter'), PageSizeOption.letter);
      expect(PageSizeOption.fromName('fit'), PageSizeOption.fit);
    });
    test('2.2 tên lạ / null ⇒ a4 (mặc định)', () {
      expect(PageSizeOption.fromName('xyz'), PageSizeOption.a4);
      expect(PageSizeOption.fromName(null), PageSizeOption.a4);
    });
  });
}
