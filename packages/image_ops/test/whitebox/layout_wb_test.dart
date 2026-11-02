// Kiểm thử hộp trắng (A16, Bước 6) cho lib/src/layout.dart.
// Expected chép từ test-output/whitebox/image-ops/layout/buoc-5-du-lieu-thu.md.
import 'package:image_ops/image_ops.dart';
import 'package:test/test.dart';

void main() {
  group('U1 marginPt', () {
    test('LM-1 none ⇒ 0 (D1 Đ)', () => expect(marginPt(MarginPreset.none), 0));
    test('LM-2 small ⇒ 18 (D2 Đ)', () => expect(marginPt(MarginPreset.small), 18));
    test('LM-3 large ⇒ 36 (D2 S)', () => expect(marginPt(MarginPreset.large), 36));
  });

  group('U2 placeImageOnPage', () {
    test('LP-1 4000x3000, A4, landscape, lề small ⇒ trang ngang, ảnh vừa lề, căn giữa', () {
      final p = placeImageOnPage(
          imagePxWidth: 4000,
          imagePxHeight: 3000,
          size: PageSizePreset.a4,
          orientation: PageOrientation.landscape);
      expect(p.pageWidth, 841.89);
      expect(p.pageHeight, 595.28);
      expect(p.imageHeight, closeTo(559.28, 0.01));
      expect(p.imageWidth, closeTo(745.71, 0.01));
      expect(p.imageTop, closeTo(18, 0.01));
      expect(p.imageLeft, closeTo(48.09, 0.01));
    });
    test('LP-2 imagePxWidth 0 ⇒ ArgumentError (D1 Đ)', () {
      expect(() => placeImageOnPage(imagePxWidth: 0, imagePxHeight: 10, size: PageSizePreset.a4),
          throwsArgumentError);
    });
    test('LP-3 imagePxHeight -5 ⇒ ArgumentError (D2 Đ)', () {
      expect(() => placeImageOnPage(imagePxWidth: 10, imagePxHeight: -5, size: PageSizePreset.a4),
          throwsArgumentError);
    });
    test('LP-4 dpiForFit 0 và NaN ⇒ ArgumentError (D3 Đ)', () {
      for (final dpi in [0.0, double.nan, -72.0]) {
        expect(
            () => placeImageOnPage(
                imagePxWidth: 10, imagePxHeight: 10, size: PageSizePreset.a4, dpiForFit: dpi),
            throwsArgumentError,
            reason: 'dpi $dpi');
      }
    });
    test('LP-5 fitImage 300x150, lề large, dpi 72 ⇒ trang 372x222, ảnh tại (36,36)', () {
      final p = placeImageOnPage(
          imagePxWidth: 300,
          imagePxHeight: 150,
          size: PageSizePreset.fitImage,
          orientation: PageOrientation.portrait,
          margin: MarginPreset.large,
          dpiForFit: 72);
      expect([p.pageWidth, p.pageHeight, p.imageLeft, p.imageTop, p.imageWidth, p.imageHeight],
          [372, 222, 36, 36, 300, 150]);
    });
    test('LP-6 portrait với ảnh ngang ⇒ trang dọc (D6 Đ, D7 S, D8 S)', () {
      final p = placeImageOnPage(
          imagePxWidth: 4000,
          imagePxHeight: 3000,
          size: PageSizePreset.a4,
          orientation: PageOrientation.portrait);
      expect(p.pageWidth, 595.28);
      expect(p.pageHeight, 841.89);
      expect(p.imageWidth, closeTo(559.28, 0.01));
    });
    test('LP-7 auto với ảnh dọc 3000x4000 ⇒ trang dọc (D6 S, D7 S)', () {
      final p = placeImageOnPage(imagePxWidth: 3000, imagePxHeight: 4000, size: PageSizePreset.letter);
      expect(p.pageWidth, 612);
      expect(p.pageHeight, 792);
    });
    test('LP-7b auto với ảnh ngang 4000x3000 ⇒ trang ngang (bổ sung)', () {
      final p = placeImageOnPage(imagePxWidth: 4000, imagePxHeight: 3000, size: PageSizePreset.letter);
      expect(p.pageWidth, 792);
      expect(p.pageHeight, 612);
    });
    test('LP-7c ảnh nhỏ 150x75 @150dpi ⇒ giữ cỡ tự nhiên 72x36, không phóng to (bổ sung)', () {
      final p = placeImageOnPage(imagePxWidth: 150, imagePxHeight: 75, size: PageSizePreset.a5);
      expect(p.imageWidth, 72);
      expect(p.imageHeight, 36);
    });
  });

  group('U3 estimateJpegBytes', () {
    test('LJ-1 100x100 q5 ⇒ 863 (D3 Đ, D4 Đ ngay lượt đầu)',
        () => expect(estimateJpegBytes(100, 100, 5), 863));
    test('LJ-2 width 0 ⇒ 0 (D1 Đ)', () => expect(estimateJpegBytes(0, 100, 90), 0));
    test('LJ-3 height 0 ⇒ 0 (D2 Đ)', () => expect(estimateJpegBytes(100, 0, 90), 0));
    test('LJ-4 100x100 q50 ⇒ 1558 (D4 S rồi Đ)', () => expect(estimateJpegBytes(100, 100, 50), 1558));
    test('LJ-4b q150 kẹp về 100 ⇒ 6870; q0 kẹp về 1 ⇒ 808', () {
      expect(estimateJpegBytes(100, 100, 150), 6870);
      expect(estimateJpegBytes(100, 100, 0), 808);
    });
  });
}
