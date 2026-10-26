import 'package:image_ops/image_ops.dart' as ops;

import 'image_item.dart';

/// Dung lượng PDF ước tính (byte): mỗi ảnh nén JPEG ở [quality] + phần khung trang.
/// Chỉ là ước lượng thô (ảnh scan tài liệu thường nhỏ hơn).
int estimatePdfBytes(Iterable<ImageItem> items, int quality) {
  const perPageOverhead = 1200;
  const docOverhead = 1500;
  var total = docOverhead;
  for (final item in items) {
    final (w, h) = item.outputSize;
    total += ops.estimateJpegBytes(w, h, quality) + perPageOverhead;
  }
  return total;
}

/// Tên file gợi ý (không đuôi): `Images_20261026_134500`.
String defaultPdfName(DateTime now) {
  String two(int v) => v.toString().padLeft(2, '0');
  return 'Images_${now.year}${two(now.month)}${two(now.day)}_'
      '${two(now.hour)}${two(now.minute)}${two(now.second)}';
}

/// Tiến độ gộp hai giai đoạn: xử lý ảnh đã chỉnh sửa ([bakeCount] bước) rồi engine
/// ghép [pageCount] trang. [bakeDone] là số ảnh đã xử lý, [engineProgress] 0..1.
double combineProgress({
  required int bakeCount,
  required int bakeDone,
  required int pageCount,
  required double engineProgress,
}) {
  final total = bakeCount + pageCount;
  if (total <= 0) return 1;
  final done = bakeDone + engineProgress.clamp(0.0, 1.0) * pageCount;
  return (done / total).clamp(0.0, 1.0);
}
