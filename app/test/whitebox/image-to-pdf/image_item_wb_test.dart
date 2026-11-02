// Kiểm thử hộp trắng (A06) — models/image_item.dart. Mã bộ = buoc-5-du-lieu-thu.md của image_item.
import 'package:flutter_test/flutter_test.dart';
import 'package:image_ops/image_ops.dart' as ops;
import 'package:pdf_office/features/image_to_pdf/models/image_item.dart';

ImageItem _base({String? path, int? width, int? height, ops.ImageEdit? edit}) =>
    ImageItem(
      id: 7,
      originalPath: '/o.jpg',
      originalWidth: 400,
      originalHeight: 300,
      path: path,
      width: width,
      height: height,
      edit: edit ?? const ops.ImageEdit(),
    );

void main() {
  group('U1 editedSize', () {
    test('1-1 không xoay, không cắt, không giới hạn riêng, nhỏ hơn 3000 ⇒ giữ nguyên', () {
      expect(editedSize(1000, 500, const ops.ImageEdit()), (1000, 500));
    });
    test('1-2 xoay 1 lượt ⇒ đổi chiều', () {
      expect(
        editedSize(1000, 500, const ops.ImageEdit(rotationQuarterTurns: 1)),
        (500, 1000),
      );
    });
    test('1-3 cắt 50% × 50% ⇒ 500 × 250', () {
      const e = ops.ImageEdit(
        crop: ops.NormRect(left: 0, top: 0, width: 0.5, height: 0.5),
      );
      expect(editedSize(1000, 500, e), (500, 250));
    });
    test('1-4 edit.maxLongSide = 2000 (lớn hơn ảnh) ⇒ không phóng to', () {
      expect(
        editedSize(1000, 500, const ops.ImageEdit(maxLongSide: 2000)),
        (1000, 500),
      );
    });
    test('1-5 ảnh 6000 × 3000 ⇒ thu về cạnh dài 3000', () {
      expect(editedSize(6000, 3000, const ops.ImageEdit()), (3000, 1500));
    });
  });

  group('U2 editKey', () {
    test('2-1 không cắt: cùng file + cùng chỉnh sửa ⇒ cùng khoá; khác cỡ ⇒ khác khoá', () {
      const e = ops.ImageEdit();
      expect(editKey('/a', e, 100), editKey('/a', const ops.ImageEdit(), 100));
      expect(editKey('/a', e, 100), isNot(editKey('/a', e, 200)));
    });
    test('2-2 có cắt ⇒ khác khoá không cắt và khác khoá vùng cắt khác', () {
      const none = ops.ImageEdit();
      const c1 = ops.ImageEdit(
        crop: ops.NormRect(left: 0.1, top: 0.2, width: 0.5, height: 0.5),
      );
      const c2 = ops.ImageEdit(
        crop: ops.NormRect(left: 0.1, top: 0.2, width: 0.4, height: 0.5),
      );
      expect(editKey('/a', c1, 100), isNot(editKey('/a', none, 100)));
      expect(editKey('/a', c1, 100), isNot(editKey('/a', c2, 100)));
      expect(editKey('/a', c1, 100), editKey('/a', c1, 100));
    });
  });

  group('U3 ImageItem()', () {
    test('3-1 không truyền path/width/height ⇒ lấy theo file gốc', () {
      final it = _base();
      expect(it.path, '/o.jpg');
      expect((it.width, it.height), (400, 300));
    });
    test('3-2 có path ⇒ path mới, kích thước vẫn theo gốc', () {
      final it = _base(path: '/c.jpg');
      expect(it.path, '/c.jpg');
      expect((it.width, it.height), (400, 300));
    });
    test('3-3 có width ⇒ width mới', () {
      final it = _base(width: 50);
      expect((it.path, it.width, it.height), ('/o.jpg', 50, 300));
    });
    test('3-4 có height ⇒ height mới', () {
      final it = _base(height: 60);
      expect((it.path, it.width, it.height), ('/o.jpg', 400, 60));
    });
  });

  group('U4 isEdited', () {
    test('4-1 nguồn = gốc, không chỉnh sửa ⇒ false', () {
      expect(_base().isEdited, isFalse);
    });
    test('4-2 đã đổi nguồn (cắt) ⇒ true', () {
      expect(_base(path: '/c.jpg').isEdited, isTrue);
    });
    test('4-3 nguồn = gốc, đã xoay ⇒ true', () {
      expect(
        _base(edit: const ops.ImageEdit(rotationQuarterTurns: 1)).isEdited,
        isTrue,
      );
    });
  });

  group('U5 copyWith', () {
    final src = _base(
      path: '/p.jpg',
      width: 10,
      height: 20,
      edit: const ops.ImageEdit(rotationQuarterTurns: 1),
    );
    test('5-1 không truyền gì ⇒ giữ mọi giá trị, giữ id + gốc', () {
      final c = src.copyWith();
      expect((c.id, c.originalPath, c.originalWidth, c.originalHeight), (7, '/o.jpg', 400, 300));
      expect((c.path, c.width, c.height), ('/p.jpg', 10, 20));
      expect(c.edit, const ops.ImageEdit(rotationQuarterTurns: 1));
    });
    test('5-2 đổi path', () {
      final c = src.copyWith(path: '/q.jpg');
      expect((c.path, c.width, c.height), ('/q.jpg', 10, 20));
    });
    test('5-3 đổi width', () {
      expect(src.copyWith(width: 11).width, 11);
      expect(src.copyWith(width: 11).height, 20);
    });
    test('5-4 đổi height', () {
      expect(src.copyWith(height: 21).height, 21);
      expect(src.copyWith(height: 21).width, 10);
    });
    test('5-5 đổi edit', () {
      final c = src.copyWith(edit: const ops.ImageEdit(filter: ops.ImageFilter.grayscale));
      expect(c.edit.filter, ops.ImageFilter.grayscale);
      expect(c.path, '/p.jpg');
    });
  });
}
