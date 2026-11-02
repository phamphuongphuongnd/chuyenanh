// Kiểm thử hộp trắng A07 — scanner/model/scan_page.dart (Bước 6).
import 'package:flutter_test/flutter_test.dart';
import 'package:image_ops/image_ops.dart' show ImageFilter;
import 'package:pdf_office/features/scanner/model/scan_page.dart';

List<ScanPage> _three() => const [
      ScanPage(id: 'a', path: 'a.jpg'),
      ScanPage(id: 'b', path: 'b.jpg'),
      ScanPage(id: 'c', path: 'c.jpg'),
    ];

void main() {
  group('U1 isUnedited', () {
    test('U1-B1 không xoay, bộ lọc gốc ⇒ true', () {
      expect(const ScanPage(id: 'a', path: 'a').isUnedited, isTrue);
    });
    test('U1-B2 có xoay ⇒ false', () {
      expect(const ScanPage(id: 'a', path: 'a', quarterTurns: 2).isUnedited, isFalse);
    });
    test('U1-B3 không xoay, có bộ lọc ⇒ false', () {
      expect(const ScanPage(id: 'a', path: 'a', filter: ImageFilter.blackWhite).isUnedited, isFalse);
    });
  });

  group('U2 copyWith', () {
    const base = ScanPage(id: 'x', path: 'old.jpg', quarterTurns: 1, filter: ImageFilter.grayscale);
    test('U2-B1 đổi cả ba ⇒ giá trị mới, xoay chuẩn hoá 0..3, giữ id', () {
      final p = base.copyWith(path: 'new.jpg', quarterTurns: 5, filter: ImageFilter.enhance);
      expect(p.id, 'x');
      expect(p.path, 'new.jpg');
      expect(p.quarterTurns, 1);
      expect(p.filter, ImageFilter.enhance);
    });
    test('U2-B2 path null ⇒ giữ path cũ', () {
      expect(base.copyWith(quarterTurns: 2, filter: ImageFilter.enhance).path, 'old.jpg');
    });
    test('U2-B3 quarterTurns null ⇒ giữ xoay cũ', () {
      expect(base.copyWith(path: 'n', filter: ImageFilter.enhance).quarterTurns, 1);
    });
    test('U2-B4 filter null ⇒ giữ bộ lọc cũ', () {
      expect(base.copyWith(path: 'n', quarterTurns: 0).filter, ImageFilter.grayscale);
    });
  });

  group('U3 reorderPages', () {
    test('U3-B1 kéo xuống (0 → 2) ⇒ chèn tại newIndex − 1', () {
      expect(reorderPages(_three(), 0, 2).map((p) => p.id), ['b', 'a', 'c']);
    });
    test('U3-B2 oldIndex sai ⇒ RangeError', () {
      expect(() => reorderPages(_three(), -1, 0), throwsRangeError);
    });
    test('U3-B3 newIndex sai ⇒ RangeError', () {
      expect(() => reorderPages(_three(), 0, 4), throwsRangeError);
    });
    test('U3-B4 kéo lên (2 → 0) ⇒ chèn tại newIndex, không sửa danh sách gốc', () {
      final src = _three();
      expect(reorderPages(src, 2, 0).map((p) => p.id), ['c', 'a', 'b']);
      expect(src.map((p) => p.id), ['a', 'b', 'c']);
    });
  });
}
