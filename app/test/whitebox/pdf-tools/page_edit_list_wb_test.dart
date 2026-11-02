// Kiểm thử hộp trắng (A03) cho lib/features/pdf_tools/logic/page_edit_list.dart.
// Thiết kế: test-output/whitebox/pdf-tools/page_edit_list/buoc-5-du-lieu-thu.md — expected chép từ Bước 5.
// Nhánh đã đi được khẳng định qua identical(...) (nhánh "trả về chính nó") hoặc bản mới.
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/pdf_tools/logic/page_edit_list.dart';

List<int> order(PageEditList l) => [for (final e in l.pages) e.sourceIndex];
List<int> rotations(PageEditList l) => [for (final e in l.pages) e.rotation];

void main() {
  group('U1 PageEntry.rotated', () {
    test('U1.1 cộng dồn, âm, quay vòng về 0..270', () {
      const a = PageEntry(uid: 0, sourceIndex: 0, rotation: 270);
      const b = PageEntry(uid: 0, sourceIndex: 0);
      const c = PageEntry(uid: 0, sourceIndex: 0, rotation: 90);
      expect(a.rotated(180).rotation, 90);
      expect(b.rotated(-90).rotation, 270);
      expect(c.rotated(270).rotation, 0);
    });
  });

  group('U2 fromCount', () {
    test('U2.1 F1S: 3 trang, chưa sửa, chưa chọn', () {
      final l = PageEditList.fromCount(3);
      expect(order(l), [0, 1, 2]);
      expect([for (final e in l.pages) e.uid], [0, 1, 2]);
      expect(rotations(l), [0, 0, 0]);
      expect(l.selected, isEmpty);
      expect(l.isModified, isFalse);
    });
    test('U2.2 F1Đ: pageCount 0 ⇒ ArgumentError', () {
      final r = (() {
        try {
          return PageEditList.fromCount(0);
        } catch (e) {
          return e;
        }
      })();
      expect(r, isA<ArgumentError>());
    });
  });

  test('U3.1 length: 4, sau xoá 2 trang còn 2', () {
    final l = PageEditList.fromCount(4);
    expect(l.length, 4);
    final d = l.toggle(1).toggle(2).deleteSelected();
    expect(d.length, 2);
  });

  test('U4.1 hasSelection', () {
    expect(PageEditList.fromCount(2).hasSelection, isFalse);
    expect(PageEditList.fromCount(2).toggle(0).hasSelection, isTrue);
  });

  test('U5.1 allSelected', () {
    expect(PageEditList.fromCount(2).toggle(0).allSelected, isFalse);
    expect(PageEditList.fromCount(2).selectAll().allSelected, isTrue);
  });

  group('U6 isModified', () {
    test('U6.1 M1S, vòng hết, M2S ⇒ false', () {
      expect(PageEditList.fromCount(3).isModified, isFalse);
    });
    test('U6.2 M1Đ: xoá trang ⇒ true', () {
      final l = PageEditList.fromCount(3).toggle(1).deleteSelected();
      expect(l.length, 2); // đi nhánh M1 (độ dài khác bản gốc)
      expect(l.isModified, isTrue);
    });
    test('U6.3 M3Đ: đổi thứ tự ⇒ true', () {
      final l = PageEditList.fromCount(3).move(0, 1);
      expect(l.length, 3);
      expect(l.isModified, isTrue);
    });
    test('U6.4 M4Đ: xoay ⇒ true', () {
      final l = PageEditList.fromCount(3).toggle(0).rotateSelected(90);
      expect(order(l), [0, 1, 2]); // M3S ở i = 0
      expect(l.isModified, isTrue);
    });
  });

  test('U7.1 isSelected', () {
    final l = PageEditList.fromCount(3).toggle(2);
    expect(l.isSelected(2), isTrue);
    expect(l.isSelected(0), isFalse);
  });

  group('U8 _with', () {
    test('U8.1 W1Đ: xoay giữ nguyên lựa chọn', () {
      final src = PageEditList.fromCount(3).toggle(1);
      final l = src.rotateSelected(90);
      expect(identical(l, src), isFalse);
      expect(l.selected, {1});
    });
    test('U8.2 W1S: chạm chọn dùng tập chọn mới', () {
      expect(PageEditList.fromCount(3).toggle(1).selected, {1});
    });
  });

  group('U9 toggle', () {
    test('U9.1 T1S T2S: chọn trang', () {
      final src = PageEditList.fromCount(3);
      final l = src.toggle(1);
      expect(identical(l, src), isFalse);
      expect(l.selected, {1});
    });
    test('U9.2 T1Đ: uid không tồn tại ⇒ chính nó', () {
      final src = PageEditList.fromCount(3);
      expect(identical(src.toggle(99), src), isTrue);
    });
    test('U9.3 T2Đ: chạm lại ⇒ bỏ chọn', () {
      final src = PageEditList.fromCount(3).toggle(1);
      final l = src.toggle(1);
      expect(identical(l, src), isFalse);
      expect(l.selected, isEmpty);
    });
  });

  test('U10.1 selectAll', () {
    final l = PageEditList.fromCount(3).selectAll();
    expect(l.selected, {0, 1, 2});
    expect(l.allSelected, isTrue);
    expect(PageEditList.fromCount(1).selectAll().selected, {0});
  });

  test('U11.1 clearSelection', () {
    final l = PageEditList.fromCount(3).selectAll().clearSelection();
    expect(l.selected, isEmpty);
    expect(order(l), [0, 1, 2]);
  });

  group('U12 rotateSelected', () {
    test('U12.1 R1S R2S: xoay trang chọn, trái rồi phải', () {
      final src = PageEditList.fromCount(3).toggle(1);
      final l = src.rotateSelected(90);
      expect(identical(l, src), isFalse);
      expect(rotations(l), [0, 90, 0]);
      final back = l.rotateSelected(-90).rotateSelected(-90);
      expect(back.pages[1].rotation, 270);
    });
    test('U12.2 R1Đ: chưa chọn ⇒ chính nó', () {
      final src = PageEditList.fromCount(3);
      expect(identical(src.rotateSelected(90), src), isTrue);
    });
    test('U12.3 R2Đ: 45 độ ⇒ chính nó', () {
      final src = PageEditList.fromCount(3).toggle(1);
      expect(identical(src.rotateSelected(45), src), isTrue);
    });
  });

  group('U13 deleteSelected', () {
    test('U13.1 X1S X2S: xoá trang chọn, bỏ chọn', () {
      final src = PageEditList.fromCount(4).toggle(1).toggle(2);
      final l = src.deleteSelected();
      expect(identical(l, src), isFalse);
      expect(order(l), [0, 3]);
      expect(l.selected, isEmpty);
    });
    test('U13.2 X1Đ: chưa chọn ⇒ chính nó', () {
      final src = PageEditList.fromCount(2);
      expect(identical(src.deleteSelected(), src), isTrue);
    });
    test('U13.3 X2Đ: chọn hết ⇒ chính nó (giữ ít nhất 1 trang)', () {
      final src = PageEditList.fromCount(2).selectAll();
      expect(identical(src.deleteSelected(), src), isTrue);
    });
  });

  group('U14 move', () {
    test('U14.1 hợp lệ: kéo 0 → 2, giữ chọn theo uid', () {
      final src = PageEditList.fromCount(4).toggle(0);
      final l = src.move(0, 2);
      expect(identical(l, src), isFalse);
      expect(order(l), [1, 2, 0, 3]);
      expect(l.isSelected(0), isTrue);
    });
    test('U14.2 V1Đ: from = -1 ⇒ chính nó', () {
      final src = PageEditList.fromCount(4);
      expect(identical(src.move(-1, 0), src), isTrue);
    });
    test('U14.3 V2Đ: from = 4 ⇒ chính nó', () {
      final src = PageEditList.fromCount(4);
      expect(identical(src.move(4, 0), src), isTrue);
    });
    test('U14.4 V3Đ: to = -1 ⇒ chính nó', () {
      final src = PageEditList.fromCount(4);
      expect(identical(src.move(0, -1), src), isTrue);
    });
    test('U14.5 V4Đ: to = 4 ⇒ chính nó', () {
      final src = PageEditList.fromCount(4);
      expect(identical(src.move(0, 4), src), isTrue);
    });
    test('U14.6 V5Đ: from == to ⇒ chính nó', () {
      final src = PageEditList.fromCount(4);
      expect(identical(src.move(1, 1), src), isTrue);
    });
  });

  group('U15 moveSelected', () {
    test('U15.1 dời lên 1 trang chọn', () {
      final src = PageEditList.fromCount(4).toggle(2);
      final l = src.moveSelected(-1);
      expect(identical(l, src), isFalse);
      expect(order(l), [0, 2, 1, 3]);
      expect(l.selected, {2});
    });
    test('U15.2 D1Đ: chưa chọn ⇒ chính nó', () {
      final src = PageEditList.fromCount(3);
      expect(identical(src.moveSelected(-1), src), isTrue);
    });
    test('U15.3 dời ra sau 1 trang chọn', () {
      final src = PageEditList.fromCount(4).toggle(2);
      final l = src.moveSelected(1);
      expect(identical(l, src), isFalse);
      expect(order(l), [0, 1, 3, 2]);
    });
    test('U15.4 D3Đ: delta = 2 ⇒ chính nó', () {
      final src = PageEditList.fromCount(3).toggle(1);
      expect(identical(src.moveSelected(2), src), isTrue);
    });
    test('U15.5 D5S ngay: 1 trang, dời lên ⇒ chính nó', () {
      final src = PageEditList.fromCount(1).toggle(0);
      expect(identical(src.moveSelected(-1), src), isTrue);
    });
    test('U15.6 D7S: khối chọn sát đầu, dời lên ⇒ chính nó', () {
      final src = PageEditList.fromCount(3).toggle(0).toggle(1);
      expect(identical(src.moveSelected(-1), src), isTrue);
    });
    test('U15.7 D8S ngay: 1 trang, dời ra sau ⇒ chính nó', () {
      final src = PageEditList.fromCount(1).toggle(0);
      expect(identical(src.moveSelected(1), src), isTrue);
    });
    test('U15.8 D10S: khối chọn sát cuối, dời ra sau ⇒ chính nó', () {
      final src = PageEditList.fromCount(3).toggle(1).toggle(2);
      expect(identical(src.moveSelected(1), src), isTrue);
    });
    test('U15.9 D9S rồi D9Đ: trang đầu dời ra sau', () {
      final src = PageEditList.fromCount(3).toggle(0);
      final l = src.moveSelected(1);
      expect(identical(l, src), isFalse);
      expect(order(l), [1, 0, 2]);
    });
    test('U15.10 trang chọn kẹt đầu giữ chỗ, trang chọn khác dời lên', () {
      final src = PageEditList.fromCount(3).toggle(0).toggle(2);
      final l = src.moveSelected(-1);
      expect(identical(l, src), isFalse);
      expect(order(l), [0, 2, 1]);
    });
    test('U15.11 D11S: 1 trang chọn ở đầu, dời lên ⇒ chính nó', () {
      final src = PageEditList.fromCount(3).toggle(0);
      expect(identical(src.moveSelected(-1), src), isTrue);
    });
    test('U15.12 khối 2 trang dời ra sau, giữ thứ tự trong khối', () {
      final src = PageEditList.fromCount(5).toggle(2).toggle(3);
      final l = src.moveSelected(1);
      expect(identical(l, src), isFalse);
      expect(order(l), [0, 1, 4, 2, 3]);
    });
  });

  test('U16.1 toOps theo thứ tự mới, kèm góc xoay', () {
    final l = PageEditList.fromCount(4).toggle(3).rotateSelected(90).move(3, 0);
    final ops = l.toOps();
    expect([for (final o in ops) o.sourceIndex], [3, 0, 1, 2]);
    expect([for (final o in ops) o.rotation], [90, 0, 0, 0]);
  });

  test('U17.1 selectedOps 0 / 1 / nhiều phần tử, theo thứ tự hiện tại', () {
    expect(PageEditList.fromCount(3).selectedOps(), isEmpty);
    final one = PageEditList.fromCount(3).toggle(1).selectedOps();
    expect([for (final o in one) o.sourceIndex], [1]);
    final many =
        PageEditList.fromCount(3).move(2, 0).toggle(0).toggle(2).selectedOps();
    expect([for (final o in many) o.sourceIndex], [2, 0]);
  });
}
