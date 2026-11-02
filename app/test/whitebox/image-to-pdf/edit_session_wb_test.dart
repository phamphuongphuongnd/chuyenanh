// Kiểm thử hộp trắng (A06) — models/edit_session.dart. Mã bộ = mã ở
// test-output/whitebox/image-to-pdf/edit_session/buoc-5-du-lieu-thu.md. Expected chép từ Bước 5.
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

/// Đếm số lần notifyListeners để biết nhánh có "đổi trạng thái" hay "return sớm".
int Function() _listen(EditSession s) {
  var n = 0;
  s.addListener(() => n++);
  return () => n;
}

void main() {
  group('U1 currentIndex', () {
    test('1-1 phiên rỗng ⇒ 0', () {
      expect(EditSession().currentIndex, 0);
    });
    test('1-2 có ảnh, đang xem ảnh 2 ⇒ 2', () {
      final s = _session(3)..select(2);
      expect(s.currentIndex, 2);
    });
  });

  group('U2 current', () {
    test('2-1 phiên rỗng ⇒ null', () {
      expect(EditSession().current, isNull);
    });
    test('2-2 có ảnh ⇒ ảnh đang xem', () {
      final s = _session(3)..select(1);
      expect(s.current!.id, 1);
    });
  });

  group('U3 addAll', () {
    test('3-1 còn chỗ, có ảnh ⇒ thêm cuối, trả số đã thêm, xem ảnh mới đầu tiên', () {
      final s = _session(2);
      final n = _listen(s);
      final r = s.addAll([_item(10), _item(11)]);
      expect(n(), 1, reason: 'đi nhánh thêm (có notify)');
      expect(r, 2);
      expect(_ids(s), [0, 1, 10, 11]);
      expect(s.currentIndex, 2);
    });
    test('3-2 đã đủ 100 ảnh ⇒ trả 0, không đổi', () {
      final s = _session(maxImagesPerPdf);
      final n = _listen(s);
      final r = s.addAll([_item(500)]);
      expect(n(), 0, reason: 'return sớm ở room <= 0');
      expect(r, 0);
      expect(s.length, maxImagesPerPdf);
    });
    test('3-3 danh sách thêm rỗng ⇒ trả 0, ảnh đang xem giữ nguyên', () {
      final s = _session(3)..select(1);
      final n = _listen(s);
      final r = s.addAll(const []);
      expect(n(), 0, reason: 'return sớm ở items.isEmpty');
      expect(r, 0);
      expect(s.currentIndex, 1);
      expect(s.length, 3);
    });
  });

  group('U4 select', () {
    test('4-1 chỉ số hợp lệ khác ảnh đang xem ⇒ chuyển, notify', () {
      final s = _session(3);
      final n = _listen(s);
      s.select(2);
      expect(n(), 1);
      expect(s.currentIndex, 2);
    });
    test('4-2 chỉ số âm ⇒ bỏ qua', () {
      final s = _session(3);
      final n = _listen(s);
      s.select(-1);
      expect(n(), 0);
      expect(s.currentIndex, 0);
    });
    test('4-3 chỉ số = length ⇒ bỏ qua', () {
      final s = _session(3);
      final n = _listen(s);
      s.select(3);
      expect(n(), 0);
      expect(s.currentIndex, 0);
    });
    test('4-4 chọn lại đúng ảnh đang xem ⇒ không notify', () {
      final s = _session(3)..select(1);
      final n = _listen(s);
      s.select(1);
      expect(n(), 0);
      expect(s.currentIndex, 1);
    });
  });

  group('U5 reorder', () {
    test('5-1 kéo ảnh 0 tới vị trí 2 ⇒ [1,2,0], ảnh đang xem đi theo', () {
      final s = _session(3);
      final n = _listen(s);
      s.reorder(0, 2);
      expect(n(), 1);
      expect(_ids(s), [1, 2, 0]);
      expect(s.current!.id, 0);
      expect(s.currentIndex, 2);
    });
    test('5-2 oldIndex âm ⇒ không đổi', () {
      final s = _session(3);
      final n = _listen(s);
      s.reorder(-1, 1);
      expect(n(), 0);
      expect(_ids(s), [0, 1, 2]);
    });
    test('5-3 oldIndex = length ⇒ không đổi', () {
      final s = _session(3);
      final n = _listen(s);
      s.reorder(3, 0);
      expect(n(), 0);
      expect(_ids(s), [0, 1, 2]);
    });
    test('5-4 newIndex vượt cuối, ảnh đã ở cuối ⇒ không đổi', () {
      final s = _session(3);
      final n = _listen(s);
      s.reorder(2, 10);
      expect(n(), 0);
      expect(_ids(s), [0, 1, 2]);
    });
  });

  group('U6 removeAt', () {
    test('6-1 xoá ảnh sau ảnh đang xem ⇒ ảnh đang xem giữ nguyên, nhớ để hoàn tác', () {
      final s = _session(4);
      final n = _listen(s);
      s.removeAt(2);
      expect(n(), 1);
      expect(_ids(s), [0, 1, 3]);
      expect(s.current!.id, 0);
      expect(s.canUndoRemove, isTrue);
    });
    test('6-2 chỉ số âm ⇒ không xoá, không có gì để hoàn tác', () {
      final s = _session(3);
      final n = _listen(s);
      s.removeAt(-1);
      expect(n(), 0);
      expect(s.length, 3);
      expect(s.canUndoRemove, isFalse);
    });
    test('6-3 chỉ số = length ⇒ không xoá', () {
      final s = _session(3);
      final n = _listen(s);
      s.removeAt(3);
      expect(n(), 0);
      expect(s.length, 3);
      expect(s.canUndoRemove, isFalse);
    });
    test('6-4 xoá ảnh duy nhất ⇒ phiên rỗng, current null', () {
      final s = _session(1);
      s.removeAt(0);
      expect(s.isEmpty, isTrue);
      expect(s.current, isNull);
      expect(s.currentIndex, 0);
      expect(s.canUndoRemove, isTrue);
    });
    test('6-5 xoá ảnh trước ảnh đang xem ⇒ vẫn xem đúng ảnh đó', () {
      final s = _session(4)..select(2);
      s.removeAt(0);
      expect(s.current!.id, 2);
      expect(s.currentIndex, 1);
    });
    test('6-6 xoá ảnh đang xem ở cuối ⇒ chuyển về ảnh cuối mới', () {
      final s = _session(3)..select(2);
      s.removeAt(2);
      expect(s.currentIndex, 1);
      expect(s.current!.id, 1);
    });
  });

  group('U7 undoRemove', () {
    test('7-1 chưa xoá gì ⇒ không làm gì', () {
      final s = _session(3);
      final n = _listen(s);
      s.undoRemove();
      expect(n(), 0);
      expect(_ids(s), [0, 1, 2]);
    });
    test('7-2 sau khi xoá ⇒ đặt lại đúng vị trí cũ, chọn lại ảnh đó, hết hoàn tác', () {
      final s = _session(4);
      s.removeAt(1);
      final n = _listen(s);
      s.undoRemove();
      expect(n(), 1);
      expect(_ids(s), [0, 1, 2, 3]);
      expect(s.currentIndex, 1);
      expect(s.canUndoRemove, isFalse);
    });
    test('7-3 xoá 1 ảnh khi đủ 100, thêm lại 1, rồi Hoàn tác ⇒ không vượt 100 ảnh', () {
      final s = _session(maxImagesPerPdf);
      s.removeAt(0);
      expect(s.addAll([_item(900)]), 1);
      expect(s.length, maxImagesPerPdf);
      final n = _listen(s);
      s.undoRemove();
      expect(n(), 1, reason: 'đã đi nhánh last != null');
      expect(s.length, lessThanOrEqualTo(maxImagesPerPdf));
    });
  });

  group('U8 _replaceCurrent (qua rotate/filter/crop/reset)', () {
    test('8-1 phiên rỗng ⇒ xoay/lọc/cắt/đặt lại không ném, không notify', () {
      final s = EditSession();
      final n = _listen(s);
      s.rotateCurrent();
      s.setFilterCurrent(ops.ImageFilter.grayscale);
      s.applyCroppedCurrent(path: '/c.jpg', width: 1, height: 1);
      s.resetCurrent();
      expect(n(), 0);
      expect(s.isEmpty, isTrue);
    });
    test('8-2 xoay ⇒ chỉ ảnh đang xem +90°', () {
      final s = _session(2)..select(1);
      final n = _listen(s);
      s.rotateCurrent();
      expect(n(), 1);
      expect(s.items[1].edit.quarterTurns, 1);
      expect(s.items[0].edit.quarterTurns, 0);
    });
    test('8-3 bộ lọc ⇒ chỉ ảnh đang xem', () {
      final s = _session(2);
      s.setFilterCurrent(ops.ImageFilter.blackWhite);
      expect(s.items[0].edit.filter, ops.ImageFilter.blackWhite);
      expect(s.items[1].edit.filter, ops.ImageFilter.original);
    });
    test('8-4 cắt xong ⇒ đổi nguồn + kích thước, xoay về 0, giữ bộ lọc', () {
      final s = _session(1)
        ..rotateCurrent()
        ..setFilterCurrent(ops.ImageFilter.grayscale);
      s.applyCroppedCurrent(path: '/c.jpg', width: 120, height: 80);
      final it = s.current!;
      expect(it.path, '/c.jpg');
      expect((it.width, it.height), (120, 80));
      expect(it.edit.quarterTurns, 0);
      expect(it.edit.filter, ops.ImageFilter.grayscale);
      expect(it.originalPath, '/img0.jpg');
    });
    test('8-5 đặt lại ⇒ về file gốc, không còn chỉnh sửa', () {
      final s = _session(1)
        ..rotateCurrent()
        ..applyCroppedCurrent(path: '/c.jpg', width: 10, height: 10);
      s.resetCurrent();
      expect(s.current!.path, '/img0.jpg');
      expect(s.current!.isEdited, isFalse);
    });
  });
}
