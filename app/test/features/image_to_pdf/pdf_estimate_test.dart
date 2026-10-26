import 'package:flutter_test/flutter_test.dart';
import 'package:image_ops/image_ops.dart' as ops;
import 'package:pdf_office/features/image_to_pdf/models/image_item.dart';
import 'package:pdf_office/features/image_to_pdf/models/pdf_estimate.dart';

ImageItem _item(int w, int h, [ops.ImageEdit edit = const ops.ImageEdit()]) =>
    ImageItem(
      id: 1,
      originalPath: '/a.jpg',
      originalWidth: w,
      originalHeight: h,
      edit: edit,
    );

void main() {
  group('estimatePdfBytes', () {
    test('rỗng chỉ còn phần khung', () {
      expect(estimatePdfBytes(const [], 85), lessThan(5000));
    });

    test('nhiều ảnh → lớn hơn; chất lượng cao → lớn hơn', () {
      final one = estimatePdfBytes([_item(2000, 1500)], 85);
      final two = estimatePdfBytes([_item(2000, 1500), _item(2000, 1500)], 85);
      expect(two, greaterThan(one));
      expect(
        estimatePdfBytes([_item(2000, 1500)], 95),
        greaterThan(estimatePdfBytes([_item(2000, 1500)], 40)),
      );
    });

    test('ảnh quá lớn tính theo kích thước đã thu về 3000px', () {
      final big = estimatePdfBytes([_item(12000, 9000)], 85);
      final capped = estimatePdfBytes([_item(3000, 2250)], 85);
      expect(big, capped);
    });

    test('cắt nhỏ thì ước tính nhỏ hơn', () {
      final full = estimatePdfBytes([_item(2000, 1500)], 85);
      final cropped = estimatePdfBytes([
        _item(
          2000,
          1500,
          const ops.ImageEdit(
            crop: ops.NormRect(left: 0, top: 0, width: 0.5, height: 0.5),
          ),
        ),
      ], 85);
      expect(cropped, lessThan(full));
    });
  });

  test('defaultPdfName', () {
    expect(
      defaultPdfName(DateTime(2026, 10, 6, 9, 5, 3)),
      'Images_20261006_090503',
    );
  });

  group('combineProgress', () {
    test('chỉ có engine', () {
      expect(
        combineProgress(
          bakeCount: 0,
          bakeDone: 0,
          pageCount: 4,
          engineProgress: 0.5,
        ),
        0.5,
      );
    });

    test('hai giai đoạn: nướng 2 ảnh rồi ghép 2 trang', () {
      expect(
        combineProgress(
          bakeCount: 2,
          bakeDone: 1,
          pageCount: 2,
          engineProgress: 0,
        ),
        0.25,
      );
      expect(
        combineProgress(
          bakeCount: 2,
          bakeDone: 2,
          pageCount: 2,
          engineProgress: 1,
        ),
        1,
      );
    });

    test('không có việc gì → 1; giá trị ngoài khoảng được kẹp', () {
      expect(
        combineProgress(
          bakeCount: 0,
          bakeDone: 0,
          pageCount: 0,
          engineProgress: 0,
        ),
        1,
      );
      expect(
        combineProgress(
          bakeCount: 0,
          bakeDone: 0,
          pageCount: 1,
          engineProgress: 5,
        ),
        1,
      );
    });
  });
}
