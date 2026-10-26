import 'package:image_ops/image_ops.dart' as ops;

/// Một trang đã quét: file ảnh (đã cắt vuông góc) + chỉnh sửa chưa áp (xoay, bộ lọc).
/// Ảnh gốc không bị ghi đè — chỉnh sửa chỉ áp khi xem trước / xuất.
class ScanPage {
  const ScanPage({
    required this.id,
    required this.path,
    this.quarterTurns = 0,
    this.filter = ops.ImageFilter.original,
  });

  final String id;
  final String path;

  /// Xoay thuận chiều kim đồng hồ, 0..3 lần 90°.
  final int quarterTurns;
  final ops.ImageFilter filter;

  bool get isUnedited => quarterTurns == 0 && filter == ops.ImageFilter.original;

  ScanPage copyWith({String? path, int? quarterTurns, ops.ImageFilter? filter}) =>
      ScanPage(
        id: id,
        path: path ?? this.path,
        quarterTurns: quarterTurns == null ? this.quarterTurns : quarterTurns % 4,
        filter: filter ?? this.filter,
      );

  ScanPage rotatedRight() => copyWith(quarterTurns: quarterTurns + 1);

  /// Chỉnh sửa cho `image_ops` ([maxLongSide] giới hạn cạnh dài khi xem trước / xuất).
  ops.ImageEdit toEdit({int? maxLongSide}) => ops.ImageEdit(
    rotationQuarterTurns: quarterTurns,
    filter: filter,
    maxLongSide: maxLongSide,
  );
}

/// Đổi chỗ một trang theo quy ước `ReorderableListView.onReorder`
/// (`newIndex` tính khi phần tử đang kéo CHƯA bị bỏ ra). Trả danh sách mới.
List<ScanPage> reorderPages(List<ScanPage> pages, int oldIndex, int newIndex) {
  RangeError.checkValidIndex(oldIndex, pages, 'oldIndex');
  RangeError.checkValueInInterval(newIndex, 0, pages.length, 'newIndex');
  final out = List<ScanPage>.of(pages);
  final moved = out.removeAt(oldIndex);
  out.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, moved);
  return out;
}
