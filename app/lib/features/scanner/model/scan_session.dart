import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_ops/image_ops.dart' as ops;

import 'scan_page.dart';

/// Danh sách trang của phiên quét hiện tại (mất khi rời màn hình quét).
final scanSessionProvider =
    NotifierProvider.autoDispose<ScanSessionNotifier, List<ScanPage>>(
      ScanSessionNotifier.new,
    );

class ScanSessionNotifier extends Notifier<List<ScanPage>> {
  int _nextId = 0;

  @override
  List<ScanPage> build() => const [];

  /// Thêm các trang mới ở cuối, theo thứ tự [paths].
  void addPaths(
    Iterable<String> paths, {
    ops.ImageFilter filter = ops.ImageFilter.original,
  }) {
    state = [
      ...state,
      for (final p in paths)
        ScanPage(id: 'page${_nextId++}', path: p, filter: filter),
    ];
  }

  void remove(String id) {
    state = [
      for (final p in state)
        if (p.id != id) p,
    ];
  }

  /// Quy ước `ReorderableListView.onReorder`.
  void reorder(int oldIndex, int newIndex) {
    state = reorderPages(state, oldIndex, newIndex);
  }

  /// Chụp lại: thay file ảnh, giữ vị trí + id + bộ lọc, bỏ xoay cũ.
  void replacePath(String id, String newPath) =>
      _update(id, (p) => p.copyWith(path: newPath, quarterTurns: 0));

  void rotate(String id) => _update(id, (p) => p.rotatedRight());

  void setFilter(String id, ops.ImageFilter filter) =>
      _update(id, (p) => p.copyWith(filter: filter));

  void setFilterAll(ops.ImageFilter filter) {
    state = [for (final p in state) p.copyWith(filter: filter)];
  }

  void clear() => state = const [];

  void _update(String id, ScanPage Function(ScanPage) change) {
    state = [for (final p in state) p.id == id ? change(p) : p];
  }
}
