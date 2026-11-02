// Kiểm thử hộp trắng (A06) — models/pdf_estimate.dart. Mã bộ = buoc-5-du-lieu-thu.md của pdf_estimate.
import 'package:flutter_test/flutter_test.dart';
import 'package:image_ops/image_ops.dart' as ops;
import 'package:pdf_office/features/image_to_pdf/models/image_item.dart';
import 'package:pdf_office/features/image_to_pdf/models/pdf_estimate.dart';

ImageItem _item(int w, int h) =>
    ImageItem(id: 1, originalPath: '/a.jpg', originalWidth: w, originalHeight: h);

void main() {
  group('U1 estimatePdfBytes', () {
    test('1-1 không ảnh (vòng lặp 0 lần) ⇒ chỉ phần khung, > 0', () {
      expect(estimatePdfBytes(const [], 85), greaterThan(0));
    });
    test('1-2 một ảnh ⇒ khung + JPEG ước tính + khung trang', () {
      final f0 = estimatePdfBytes(const [], 85);
      final f1 = estimatePdfBytes([_item(2000, 1500)], 85);
      expect(f1 - f0, greaterThan(ops.estimateJpegBytes(2000, 1500, 85)));
    });
    test('1-3 hai ảnh giống nhau ⇒ mỗi trang cộng thêm đúng một lượng', () {
      final f0 = estimatePdfBytes(const [], 85);
      final f1 = estimatePdfBytes([_item(2000, 1500)], 85);
      final f2 = estimatePdfBytes([_item(2000, 1500), _item(2000, 1500)], 85);
      expect(f2 - f1, f1 - f0);
    });
  });

  group('U2 combineProgress', () {
    test('2-1 không có việc gì (tổng = 0) ⇒ 1', () {
      expect(
        combineProgress(bakeCount: 0, bakeDone: 0, pageCount: 0, engineProgress: 0),
        1,
      );
    });
    test('2-2 nướng 2 ảnh xong 1 + engine 50% của 2 trang ⇒ (1 + 1) / 4 = 0.5', () {
      expect(
        combineProgress(bakeCount: 2, bakeDone: 1, pageCount: 2, engineProgress: 0.5),
        0.5,
      );
    });
  });
}
