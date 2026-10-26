// Mô hình thuần cho lớp phủ chữ ký trên trang: vị trí lưu theo TỶ LỆ trang (0..1) nên không phụ
// thuộc kích thước hiển thị / zoom. Đổi sang toạ độ PDF bằng [normToPdfRect].
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'signature_math.dart';

/// Chiều rộng tối thiểu của chữ ký (tỷ lệ chiều rộng trang) để còn bấm/kéo được.
const double kMinSignatureWidthFraction = 0.06;

/// Chiều rộng mặc định khi vừa đặt (tỷ lệ chiều rộng trang).
const double kDefaultSignatureWidthFraction = 0.32;

/// Một chữ ký đã đặt lên trang. [norm] là khung theo tỷ lệ trang (gốc trên-trái, 0..1).
class PlacedSignature {
  const PlacedSignature({
    required this.id,
    required this.pageIndex,
    required this.pngBytes,
    required this.aspect,
    required this.norm,
  });

  final int id;
  final int pageIndex;
  final Uint8List pngBytes;

  /// Rộng / cao của ảnh chữ ký (> 0).
  final double aspect;
  final Rect norm;

  PlacedSignature copyWith({Rect? norm}) => PlacedSignature(
    id: id,
    pageIndex: pageIndex,
    pngBytes: pngBytes,
    aspect: aspect,
    norm: norm ?? this.norm,
  );
}

/// Khung ban đầu: giữa trang, rộng [widthFraction] chiều rộng trang, đúng tỷ lệ ảnh.
/// Nếu quá cao thì thu nhỏ cho vừa trang.
Rect initialNormRect(
  double aspect,
  Size pageSize, {
  double widthFraction = kDefaultSignatureWidthFraction,
}) {
  assert(aspect > 0);
  var w = widthFraction.clamp(kMinSignatureWidthFraction, 1.0);
  var h = w * pageSize.width / aspect / pageSize.height;
  if (h > 0.5) {
    h = 0.5;
    w = h * aspect * pageSize.height / pageSize.width;
  }
  return Rect.fromLTWH((1 - w) / 2, (1 - h) / 2, w, h);
}

/// Dời khung theo [delta] (tỷ lệ trang), giữ trong trang.
Rect moveNormRect(Rect r, Offset delta) {
  final left = (r.left + delta.dx).clamp(0.0, 1.0 - r.width);
  final top = (r.top + delta.dy).clamp(0.0, 1.0 - r.height);
  return Rect.fromLTWH(left, top, r.width, r.height);
}

/// Đổi cỡ giữ nguyên tỷ lệ ảnh, neo ở góc trên-trái; không vượt mép trang, không nhỏ hơn
/// [kMinSignatureWidthFraction].
Rect resizeNormRect(
  Rect r,
  double newWidth,
  Size pageSize,
  double aspect,
) {
  assert(aspect > 0);
  // Chiều cao (tỷ lệ) ứng với chiều rộng w (tỷ lệ).
  double heightFor(double w) => w * pageSize.width / aspect / pageSize.height;
  final maxW = math.min(
    1.0 - r.left,
    (1.0 - r.top) * aspect * pageSize.height / pageSize.width,
  );
  final minW = math.min(kMinSignatureWidthFraction, maxW);
  final w = math.max(minW, math.min(newWidth, maxW));
  return Rect.fromLTWH(r.left, r.top, w, heightFor(w));
}

/// Khung theo tỷ lệ trang → khung PDF (point, gốc trên-trái, hệ "nhìn thấy") cho `applySignatures`.
Rect normToPdfRect(Rect norm, Size pageSize) =>
    viewRectToPdfRect(norm, const Size(1, 1), pageSize);

/// Khung PDF → tỷ lệ trang (ngược của [normToPdfRect]).
Rect pdfRectToNorm(Rect pdf, Size pageSize) =>
    viewRectToPdfRect(pdf, pageSize, const Size(1, 1));
