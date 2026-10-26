import 'package:flutter/foundation.dart';
import 'package:image_ops/image_ops.dart' as ops;

import 'image_item.dart';
import 'ordered_selection.dart';

/// Phiên sửa danh sách ảnh trước khi xuất PDF: thứ tự, xoay, bộ lọc, cắt, xoá, thêm.
/// Logic thuần (không phụ thuộc UI) — có unit test.
class EditSession extends ChangeNotifier {
  EditSession([List<ImageItem> items = const []]) : _items = [...items] {
    _nextId = _items.fold<int>(0, (m, e) => e.id >= m ? e.id + 1 : m);
  }

  final List<ImageItem> _items;
  int _nextId = 0;
  int _current = 0;
  ({int index, ImageItem item})? _lastRemoved;

  List<ImageItem> get items => List.unmodifiable(_items);
  int get length => _items.length;
  bool get isEmpty => _items.isEmpty;

  /// Chỉ số ảnh đang xem (luôn hợp lệ khi không rỗng).
  int get currentIndex => _items.isEmpty ? 0 : _current;
  ImageItem? get current => _items.isEmpty ? null : _items[_current];

  /// Ảnh vừa xoá gần nhất (để hoàn tác).
  bool get canUndoRemove => _lastRemoved != null;

  /// Cấp id mới cho ảnh sắp thêm.
  int nextId() => _nextId++;

  /// Số ảnh còn thêm được.
  int get remainingCapacity => maxImagesPerPdf - _items.length;

  /// Thêm ảnh vào cuối; quá [maxImagesPerPdf] thì bỏ phần dư. Trả về số ảnh đã thêm.
  /// Ảnh thêm xong trở thành ảnh đang xem.
  int addAll(List<ImageItem> items) {
    final room = remainingCapacity;
    if (room <= 0 || items.isEmpty) return 0;
    final accepted = items.take(room).toList();
    final firstNew = _items.length;
    _items.addAll(accepted);
    _current = firstNew;
    notifyListeners();
    return accepted.length;
  }

  void select(int index) {
    if (index < 0 || index >= _items.length || index == _current) return;
    _current = index;
    notifyListeners();
  }

  /// Đổi chỗ như `ReorderableListView.onReorderItem`: [newIndex] là vị trí cuối cùng của
  /// ảnh sau khi di chuyển (đã trừ phần tử cũ). Ảnh đang xem đi theo vị trí mới của nó.
  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _items.length) return;
    final target = newIndex.clamp(0, _items.length - 1);
    if (target == oldIndex) return;
    final currentId = _items[_current].id;
    final moved = _items.removeAt(oldIndex);
    _items.insert(target, moved);
    _current = _items.indexWhere((e) => e.id == currentId);
    notifyListeners();
  }

  /// Xoá ảnh ở [index]; nhớ lại để [undoRemove].
  void removeAt(int index) {
    if (index < 0 || index >= _items.length) return;
    final removed = _items.removeAt(index);
    _lastRemoved = (index: index, item: removed);
    if (_items.isEmpty) {
      _current = 0;
    } else if (index < _current) {
      _current -= 1;
    } else if (_current >= _items.length) {
      _current = _items.length - 1;
    }
    notifyListeners();
  }

  void removeCurrent() => removeAt(_current);

  /// Hoàn tác lần xoá gần nhất (đặt lại đúng vị trí cũ, chọn lại ảnh đó).
  void undoRemove() {
    final last = _lastRemoved;
    if (last == null) return;
    _lastRemoved = null;
    final at = last.index.clamp(0, _items.length);
    _items.insert(at, last.item);
    _current = at;
    notifyListeners();
  }

  void _replaceCurrent(ImageItem Function(ImageItem) f) {
    if (_items.isEmpty) return;
    _items[_current] = f(_items[_current]);
    notifyListeners();
  }

  /// Xoay ảnh đang xem 90° theo chiều kim đồng hồ.
  void rotateCurrent() => _replaceCurrent(
    (e) => e.copyWith(
      edit: e.edit.copyWith(rotationQuarterTurns: e.edit.quarterTurns + 1),
    ),
  );

  void setFilterCurrent(ops.ImageFilter filter) =>
      _replaceCurrent((e) => e.copyWith(edit: e.edit.copyWith(filter: filter)));

  /// Sau khi cắt bằng công cụ ngoài: nguồn mới là [path] (đã cắt), xoay về 0 vì
  /// việc xoay đã được "nướng" vào file trước khi cắt; giữ bộ lọc.
  void applyCroppedCurrent({
    required String path,
    required int width,
    required int height,
  }) => _replaceCurrent(
    (e) => e.copyWith(
      path: path,
      width: width,
      height: height,
      edit: e.edit.copyWith(rotationQuarterTurns: 0),
    ),
  );

  void resetCurrent() => _replaceCurrent((e) => e.reset());
}
