import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/engines/pdf/pdf_render_engine.dart';
import 'package:pdf_office/engines/pdf/pdfx_render_engine.dart';

void main() {
  group('computeRenderSize (DPI → pixel)', () {
    test('A4 ở 72 dpi = số point', () {
      final s = computeRenderSize(const PdfPageSize(595.28, 841.89), 72);
      expect((s.width, s.height), (595, 842));
    });

    test('A4 ở 150 và 300 dpi', () {
      expect(
        computeRenderSize(const PdfPageSize(595.28, 841.89), 150).width,
        1240,
      );
      final s = computeRenderSize(const PdfPageSize(595.28, 841.89), 300);
      expect((s.width, s.height), (2480, 3508));
    });

    test('trang ngang giữ tỉ lệ', () {
      final s = computeRenderSize(const PdfPageSize(842, 595), 144);
      expect((s.width, s.height), (1684, 1190));
    });

    test('quá nhiều điểm ảnh → thu nhỏ giữ tỉ lệ, không vượt giới hạn', () {
      final s = computeRenderSize(
        const PdfPageSize(5000, 7000),
        600,
        maxPixels: 16000000,
      );
      expect(s.width * s.height, lessThanOrEqualTo(16000000));
      expect(s.width / s.height, closeTo(5000 / 7000, 0.01));
    });

    test('DPI <= 0 hoặc trang 0 kích thước không trả về 0 pixel', () {
      final s = computeRenderSize(const PdfPageSize(0, 0), 150);
      expect(s.width, greaterThanOrEqualTo(1));
      expect(s.height, greaterThanOrEqualTo(1));
      expect(
        computeRenderSize(const PdfPageSize(100, 100), 0).width,
        greaterThanOrEqualTo(1),
      );
    });
  });

  group('computeThumbnailSize', () {
    test('cạnh dài = maxSide', () {
      final s = computeThumbnailSize(const PdfPageSize(600, 800), 300);
      expect((s.width, s.height), (225, 300));
      final l = computeThumbnailSize(const PdfPageSize(800, 600), 300);
      expect((l.width, l.height), (300, 225));
    });
  });
}
