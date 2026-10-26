import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/pdf_tools/logic/page_edit_list.dart';

List<int> order(PageEditList l) => [for (final e in l.pages) e.sourceIndex];

void main() {
  test('fromCount: n trang, chưa sửa, chưa chọn', () {
    final l = PageEditList.fromCount(4);
    expect(order(l), [0, 1, 2, 3]);
    expect(l.isModified, isFalse);
    expect(l.hasSelection, isFalse);
    expect(() => PageEditList.fromCount(0), throwsArgumentError);
  });

  test('toggle / selectAll / clearSelection', () {
    var l = PageEditList.fromCount(3).toggle(1);
    expect(l.selected, {1});
    l = l.toggle(1);
    expect(l.hasSelection, isFalse);
    l = l.selectAll();
    expect(l.allSelected, isTrue);
    expect(l.clearSelection().hasSelection, isFalse);
    expect(identical(l.toggle(99), l), isTrue);
  });

  test('move: kéo thả đổi thứ tự, giữ uid để chọn không lệch', () {
    var l = PageEditList.fromCount(4).toggle(0);
    l = l.move(0, 2);
    expect(order(l), [1, 2, 0, 3]);
    expect(l.isSelected(0), isTrue);
    expect(l.isModified, isTrue);
    expect(identical(l.move(5, 0), l), isTrue);
    expect(identical(l.move(1, 1), l), isTrue);
  });

  test('moveSelected: dịch lên / xuống, dừng ở biên', () {
    var l = PageEditList.fromCount(4).toggle(2);
    l = l.moveSelected(-1);
    expect(order(l), [0, 2, 1, 3]);
    l = l.moveSelected(-1).moveSelected(-1);
    expect(order(l), [2, 0, 1, 3]);
    l = l.moveSelected(1);
    expect(order(l), [0, 2, 1, 3]);
    // hai trang liền nhau cùng dịch, không đảo thứ tự giữa chúng
    final m = PageEditList.fromCount(5).toggle(2).toggle(3).moveSelected(-1);
    expect(order(m), [0, 2, 3, 1, 4]);
    // đã ở sát đầu
    final top = PageEditList.fromCount(3).toggle(0);
    expect(identical(top.moveSelected(-1), top), isTrue);
  });

  test('rotateSelected: cộng dồn, quay vòng 0..270, âm cũng được', () {
    var l = PageEditList.fromCount(2).toggle(1);
    l = l.rotateSelected(90).rotateSelected(90).rotateSelected(90);
    expect(l.pages[1].rotation, 270);
    expect(l.pages[0].rotation, 0);
    l = l.rotateSelected(90);
    expect(l.pages[1].rotation, 0);
    l = l.rotateSelected(-90);
    expect(l.pages[1].rotation, 270);
    expect(identical(l.rotateSelected(45), l), isTrue);
    expect(l.isModified, isTrue);
  });

  test('deleteSelected: xoá trang chọn, không cho xoá hết', () {
    var l = PageEditList.fromCount(4).toggle(1).toggle(2).deleteSelected();
    expect(order(l), [0, 3]);
    expect(l.hasSelection, isFalse);
    final all = PageEditList.fromCount(2).selectAll();
    expect(identical(all.deleteSelected(), all), isTrue);
    final none = PageEditList.fromCount(2);
    expect(identical(none.deleteSelected(), none), isTrue);
    l = l.toggle(3).deleteSelected();
    expect(order(l), [0]);
  });

  test('toOps / selectedOps theo thứ tự mới, kèm góc xoay', () {
    var l = PageEditList.fromCount(4);
    l = l.toggle(3).rotateSelected(90).move(3, 0).clearSelection().toggle(1);
    final ops = l.toOps();
    expect([for (final o in ops) o.sourceIndex], [3, 0, 1, 2]);
    expect([for (final o in ops) o.rotation], [90, 0, 0, 0]);
    final sel = l.selectedOps();
    expect(sel.length, 1);
    expect(sel.single.sourceIndex, 1);
  });

  test('isModified: về lại ban đầu thì false', () {
    final l = PageEditList.fromCount(3).toggle(0).move(0, 1).move(1, 0);
    expect(l.isModified, isFalse);
  });
}
