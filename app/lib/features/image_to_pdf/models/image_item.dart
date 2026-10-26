import 'dart:math' as math;

import 'package:image_ops/image_ops.dart' as ops;

/// Cạnh dài tối đa của ảnh nhúng vào PDF (khớp engine).
const int embeddedLongSide = 3000;

/// Kích thước (px) của ảnh sau khi áp [edit]: xoay → cắt → thu nhỏ (không phóng to).
/// [width] × [height] là kích thước ảnh gốc đã áp EXIF.
(int, int) editedSize(
  int width,
  int height,
  ops.ImageEdit edit, {
  int maxLongSide = embeddedLongSide,
}) {
  var w = width.toDouble();
  var h = height.toDouble();
  if (edit.quarterTurns.isOdd) {
    final t = w;
    w = h;
    h = t;
  }
  final crop = edit.crop;
  if (crop != null) {
    w *= crop.width.clamp(0.0, 1.0);
    h *= crop.height.clamp(0.0, 1.0);
  }
  final limit = edit.maxLongSide == null
      ? maxLongSide
      : math.min(edit.maxLongSide!, maxLongSide);
  final longSide = math.max(w, h);
  if (longSide > limit) {
    final k = limit / longSide;
    w *= k;
    h *= k;
  }
  return (math.max(1, w.round()), math.max(1, h.round()));
}

/// Khoá ổn định cho cache xem trước: cùng file + cùng chỉnh sửa → cùng khoá.
String editKey(String path, ops.ImageEdit edit, int maxSide) {
  final c = edit.crop;
  final crop = c == null ? '-' : '${c.left},${c.top},${c.width},${c.height}';
  return '$path|${edit.quarterTurns}|$crop|${edit.filter.name}|'
      '${edit.brightness}|${edit.contrast}|$maxSide';
}

/// Một ảnh trong phiên sửa. Bất biến — đổi bằng [copyWith].
class ImageItem {
  /// Ảnh mới chọn (chưa chỉnh sửa): nguồn hiện tại = file gốc.
  ImageItem({
    required this.id,
    required this.originalPath,
    required this.originalWidth,
    required this.originalHeight,
    String? path,
    int? width,
    int? height,
    this.edit = const ops.ImageEdit(),
  }) : path = path ?? originalPath,
       width = width ?? originalWidth,
       height = height ?? originalHeight;

  /// Khoá duy nhất trong phiên (dùng cho kéo thả / cache).
  final int id;

  /// File gốc người dùng chọn — dùng để "Đặt lại".
  final String originalPath;
  final int originalWidth;
  final int originalHeight;

  /// File nguồn hiện tại (khác [originalPath] sau khi cắt).
  final String path;

  /// Kích thước (px) của [path] sau EXIF.
  final int width;
  final int height;

  /// Xoay / bộ lọc áp lên [path].
  final ops.ImageEdit edit;

  bool get isEdited => path != originalPath || edit != const ops.ImageEdit();

  /// Kích thước ảnh sau chỉnh sửa (px).
  (int, int) get outputSize => editedSize(width, height, edit);

  ImageItem copyWith({
    String? path,
    int? width,
    int? height,
    ops.ImageEdit? edit,
  }) => ImageItem(
    id: id,
    originalPath: originalPath,
    originalWidth: originalWidth,
    originalHeight: originalHeight,
    path: path ?? this.path,
    width: width ?? this.width,
    height: height ?? this.height,
    edit: edit ?? this.edit,
  );

  /// Về trạng thái ban đầu (file gốc, không chỉnh sửa).
  ImageItem reset() => ImageItem(
    id: id,
    originalPath: originalPath,
    originalWidth: originalWidth,
    originalHeight: originalHeight,
  );
}
