// Xử lý ảnh chữ ký (PNG nền trong suốt) — thuần Dart, không phụ thuộc Flutter widget.
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../core/errors/app_error.dart';

/// Cắt phần trong suốt thừa quanh nét ký, chừa [padding] px mỗi cạnh.
///
/// Trả về `null` nếu ảnh không có nét nào (toàn trong suốt) — nghĩa là người dùng chưa ký.
/// Ném [CorruptFile] nếu không đọc được PNG.
Uint8List? trimSignaturePng(Uint8List png, {int padding = 4}) {
  final image = img.decodePng(png);
  if (image == null) throw const CorruptFile('signature png');
  var minX = image.width;
  var minY = image.height;
  var maxX = -1;
  var maxY = -1;
  for (final p in image) {
    if (p.a > 8) {
      if (p.x < minX) minX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.x > maxX) maxX = p.x;
      if (p.y > maxY) maxY = p.y;
    }
  }
  if (maxX < 0) return null;
  final x = (minX - padding).clamp(0, image.width - 1);
  final y = (minY - padding).clamp(0, image.height - 1);
  final right = (maxX + padding).clamp(0, image.width - 1);
  final bottom = (maxY + padding).clamp(0, image.height - 1);
  final cropped = img.copyCrop(
    image,
    x: x,
    y: y,
    width: right - x + 1,
    height: bottom - y + 1,
  );
  return Uint8List.fromList(img.encodePng(cropped));
}

/// Tỷ lệ rộng/cao của ảnh PNG. Ném [CorruptFile] nếu hỏng.
double pngAspectRatio(Uint8List png) {
  final image = img.decodePng(png);
  if (image == null || image.height == 0) {
    throw const CorruptFile('signature png');
  }
  return image.width / image.height;
}
