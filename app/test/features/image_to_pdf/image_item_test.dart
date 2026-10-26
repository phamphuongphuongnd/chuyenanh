import 'package:flutter_test/flutter_test.dart';
import 'package:image_ops/image_ops.dart' as ops;
import 'package:pdf_office/features/image_to_pdf/models/image_item.dart';

void main() {
  group('editedSize', () {
    test('không chỉnh sửa → giữ nguyên', () {
      expect(editedSize(1000, 500, const ops.ImageEdit()), (1000, 500));
    });

    test('xoay lẻ lượt thì đổi chiều', () {
      const e = ops.ImageEdit(rotationQuarterTurns: 1);
      expect(editedSize(1000, 500, e), (500, 1000));
      expect(
        editedSize(1000, 500, const ops.ImageEdit(rotationQuarterTurns: 2)),
        (1000, 500),
      );
      expect(
        editedSize(1000, 500, const ops.ImageEdit(rotationQuarterTurns: 5)),
        (500, 1000),
      );
    });

    test('cắt theo tỉ lệ sau khi xoay', () {
      const e = ops.ImageEdit(
        rotationQuarterTurns: 1,
        crop: ops.NormRect(left: 0, top: 0, width: 0.5, height: 0.25),
      );
      // sau xoay: 500x1000 → cắt 250x250
      expect(editedSize(1000, 500, e), (250, 250));
    });

    test('thu nhỏ về cạnh dài tối đa, không phóng to', () {
      expect(editedSize(6000, 3000, const ops.ImageEdit()), (3000, 1500));
      expect(editedSize(2000, 1000, const ops.ImageEdit()), (2000, 1000));
      expect(
        editedSize(2000, 1000, const ops.ImageEdit(maxLongSide: 1000)),
        (1000, 500),
      );
    });

    test('luôn ít nhất 1px', () {
      const e = ops.ImageEdit(
        crop: ops.NormRect(left: 0, top: 0, width: 0.0001, height: 0.0001),
      );
      expect(editedSize(100, 100, e), (1, 1));
    });
  });

  group('ImageItem', () {
    test('mới tạo: chưa chỉnh sửa, nguồn = gốc', () {
      final it = ImageItem(
        id: 1,
        originalPath: '/a.jpg',
        originalWidth: 400,
        originalHeight: 300,
      );
      expect(it.path, '/a.jpg');
      expect(it.isEdited, isFalse);
      expect(it.outputSize, (400, 300));
    });

    test('xoay / đổi nguồn → isEdited; reset về gốc', () {
      final it = ImageItem(
        id: 1,
        originalPath: '/a.jpg',
        originalWidth: 400,
        originalHeight: 300,
      );
      final rotated = it.copyWith(
        edit: const ops.ImageEdit(rotationQuarterTurns: 1),
      );
      expect(rotated.isEdited, isTrue);
      expect(rotated.outputSize, (300, 400));
      final cropped = it.copyWith(path: '/c.jpg', width: 100, height: 100);
      expect(cropped.isEdited, isTrue);
      final back = cropped.reset();
      expect(back.path, '/a.jpg');
      expect(back.outputSize, (400, 300));
      expect(back.isEdited, isFalse);
    });
  });

  test('editKey khác nhau khi chỉnh sửa khác nhau', () {
    const a = ops.ImageEdit();
    final b = a.copyWith(filter: ops.ImageFilter.grayscale);
    expect(editKey('/x', a, 100), isNot(editKey('/x', b, 100)));
    expect(editKey('/x', a, 100), isNot(editKey('/x', a, 200)));
    expect(editKey('/x', a, 100), editKey('/x', const ops.ImageEdit(), 100));
  });
}
