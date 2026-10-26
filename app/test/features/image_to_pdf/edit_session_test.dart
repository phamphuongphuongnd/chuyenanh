import 'package:flutter_test/flutter_test.dart';
import 'package:image_ops/image_ops.dart' as ops;
import 'package:pdf_office/features/image_to_pdf/models/edit_session.dart';
import 'package:pdf_office/features/image_to_pdf/models/image_item.dart';
import 'package:pdf_office/features/image_to_pdf/models/ordered_selection.dart';

ImageItem _item(int id) => ImageItem(
  id: id,
  originalPath: '/img$id.jpg',
  originalWidth: 400,
  originalHeight: 300,
);

EditSession _session(int n) =>
    EditSession([for (var i = 0; i < n; i++) _item(i)]);

List<int> _ids(EditSession s) => s.items.map((e) => e.id).toList();

void main() {
  test('ban đầu xem ảnh đầu tiên', () {
    final s = _session(3);
    expect(s.currentIndex, 0);
    expect(s.current!.id, 0);
  });

  test('addAll thêm cuối và chuyển sang ảnh mới đầu tiên', () {
    final s = _session(2);
    final added = s.addAll([_item(s.nextId()), _item(s.nextId())]);
    expect(added, 2);
    expect(_ids(s), [0, 1, 2, 3]);
    expect(s.currentIndex, 2);
  });

  test('addAll cắt phần vượt giới hạn', () {
    final s = EditSession([
      for (var i = 0; i < maxImagesPerPdf - 1; i++) _item(i),
    ]);
    final added = s.addAll([_item(500), _item(501), _item(502)]);
    expect(added, 1);
    expect(s.length, maxImagesPerPdf);
    expect(s.addAll([_item(600)]), 0);
  });

  group('reorder', () {
    test('kéo ảnh 0 xuống cuối (newIndex = vị trí cuối cùng)', () {
      final s = _session(4);
      s.reorder(0, 3);
      expect(_ids(s), [1, 2, 3, 0]);
    });

    test('kéo ảnh 3 lên đầu', () {
      final s = _session(4);
      s.reorder(3, 0);
      expect(_ids(s), [3, 0, 1, 2]);
    });

    test('đổi chỗ liền kề', () {
      final s = _session(3);
      s.reorder(0, 1);
      expect(_ids(s), [1, 0, 2]);
    });

    test('ảnh đang xem đi theo vị trí mới', () {
      final s = _session(4)..select(1);
      s.reorder(1, 3);
      expect(s.current!.id, 1);
      expect(s.currentIndex, 3);
      s.reorder(0, 1); // ảnh khác di chuyển ngang qua
      expect(s.current!.id, 1);
    });

    test('chỉ số lạ hoặc không đổi chỗ thì không làm gì', () {
      final s = _session(3);
      s.reorder(5, 0);
      s.reorder(1, 1);
      expect(_ids(s), [0, 1, 2]);
    });
  });

  group('remove / undo', () {
    test('xoá ảnh trước ảnh đang xem → chỉ số lùi 1', () {
      final s = _session(4)..select(2);
      s.removeAt(0);
      expect(s.current!.id, 2);
    });

    test('xoá ảnh đang xem ở cuối → lùi về ảnh cuối mới', () {
      final s = _session(3)..select(2);
      s.removeCurrent();
      expect(s.currentIndex, 1);
      expect(s.current!.id, 1);
    });

    test('xoá hết → rỗng', () {
      final s = _session(1);
      s.removeCurrent();
      expect(s.isEmpty, isTrue);
      expect(s.current, isNull);
    });

    test('undoRemove đặt lại đúng vị trí và chọn lại', () {
      final s = _session(4);
      s.removeAt(1);
      expect(s.canUndoRemove, isTrue);
      s.undoRemove();
      expect(_ids(s), [0, 1, 2, 3]);
      expect(s.currentIndex, 1);
      expect(s.canUndoRemove, isFalse);
    });
  });

  group('chỉnh sửa ảnh đang xem', () {
    test('xoay cộng dồn theo chiều kim đồng hồ', () {
      final s = _session(2);
      s.rotateCurrent();
      expect(s.current!.edit.quarterTurns, 1);
      s.rotateCurrent();
      s.rotateCurrent();
      s.rotateCurrent();
      expect(s.current!.edit.quarterTurns, 0);
      expect(s.items[1].edit.quarterTurns, 0, reason: 'ảnh khác không đổi');
    });

    test('bộ lọc chỉ áp cho ảnh đang xem', () {
      final s = _session(3)..select(1);
      s.setFilterCurrent(ops.ImageFilter.blackWhite);
      expect(s.items[1].edit.filter, ops.ImageFilter.blackWhite);
      expect(s.items[0].edit.filter, ops.ImageFilter.original);
    });

    test('cắt xong: đổi nguồn, xoay về 0, giữ bộ lọc', () {
      final s = _session(1);
      s.rotateCurrent();
      s.setFilterCurrent(ops.ImageFilter.grayscale);
      s.applyCroppedCurrent(path: '/c.jpg', width: 120, height: 80);
      final it = s.current!;
      expect(it.path, '/c.jpg');
      expect(it.outputSize, (120, 80));
      expect(it.edit.quarterTurns, 0);
      expect(it.edit.filter, ops.ImageFilter.grayscale);
      expect(it.originalPath, '/img0.jpg');
    });

    test('resetCurrent trả về ảnh gốc', () {
      final s = _session(1);
      s.rotateCurrent();
      s.applyCroppedCurrent(path: '/c.jpg', width: 10, height: 10);
      s.resetCurrent();
      expect(s.current!.path, '/img0.jpg');
      expect(s.current!.isEdited, isFalse);
    });

    test('phiên rỗng: thao tác không ném lỗi', () {
      final s = EditSession();
      s.rotateCurrent();
      s.resetCurrent();
      s.removeCurrent();
      s.undoRemove();
      expect(s.isEmpty, isTrue);
    });
  });

  test('nextId không trùng id có sẵn', () {
    final s = EditSession([_item(7), _item(3)]);
    expect(s.nextId(), 8);
    expect(s.nextId(), 9);
  });

  test('notifyListeners khi đổi', () {
    final s = _session(2);
    var n = 0;
    s.addListener(() => n++);
    s.rotateCurrent();
    s.select(1);
    s.reorder(0, 1);
    expect(n, 3);
  });
}
