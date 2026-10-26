// Toán thuần cho chữ ký: đổi toạ độ màn hình → toạ độ PDF, có tính cuộn, zoom và
// trang xoay. Không phụ thuộc Flutter widget / Syncfusion nên test được dễ.
//
// Quy ước:
// - "visual" = khung trang như người dùng NHÌN THẤY (đã xoay theo `/Rotate`), gốc trên-trái, đơn vị point.
// - "raw"    = khung trang chưa xoay (đúng như `PdfPage.size` + hệ toạ độ vẽ của Syncfusion cho
//              trang đã nạp), gốc trên-trái, đơn vị point.
// - `/Rotate` của PDF là số độ xoay THUẬN chiều kim đồng hồ khi hiển thị.
import 'dart:math' as math;
import 'dart:ui';

import '../../engines/pdf/pdf_sign_engine.dart';

export '../../engines/pdf/pdf_sign_engine.dart'
    show SignaturePlacement, viewRectToPdfRect;

/// Đưa số độ về 0 / 90 / 180 / 270 (nhận cả số âm, bội của 90).
int normalizeRotation(int degrees) {
  final d = degrees % 360;
  return d < 0 ? d + 360 : d;
}

/// Khung chữ ký trên MÀN HÌNH → khung trong trang, đơn vị point (vẫn là khung "visual").
///
/// [screenRect]: khung chữ ký tính theo hệ toạ độ màn hình (cùng hệ với [pageOnScreen]).
/// [pageOnScreen]: khung của trang trên màn hình — đã gồm **zoom** (kích thước) và **cuộn**
/// (vị trí, có thể âm khi trang cuộn lên trên). [pageSize]: kích thước trang nhìn thấy (point).
/// Kết quả được kẹp trong trang.
Rect screenRectToPageRect(Rect screenRect, Rect pageOnScreen, Size pageSize) {
  final local = screenRect.shift(-pageOnScreen.topLeft);
  final r = viewRectToPdfRect(local, pageOnScreen.size, pageSize);
  return Rect.fromLTRB(
    r.left.clamp(0.0, pageSize.width),
    r.top.clamp(0.0, pageSize.height),
    r.right.clamp(0.0, pageSize.width),
    r.bottom.clamp(0.0, pageSize.height),
  );
}

/// Kích thước trang như người dùng nhìn thấy: trang xoay 90/270 thì hoán đổi rộng/cao.
Size visualPageSize(Size rawSize, int rotation) {
  final r = normalizeRotation(rotation);
  return (r == 90 || r == 270)
      ? Size(rawSize.height, rawSize.width)
      : rawSize;
}

/// Khung "visual" → khung "raw" (khung dùng để vẽ ảnh lên trang chưa xoay).
Rect visualRectToRawRect(Rect visual, Size rawSize, int rotation) {
  final w = rawSize.width;
  final h = rawSize.height;
  Offset map(double vx, double vy) => switch (normalizeRotation(rotation)) {
    90 => Offset(vy, h - vx),
    180 => Offset(w - vx, h - vy),
    270 => Offset(w - vy, vx),
    _ => Offset(vx, vy),
  };
  return Rect.fromPoints(
    map(visual.left, visual.top),
    map(visual.right, visual.bottom),
  );
}

/// Ngược của [visualRectToRawRect].
Rect rawRectToVisualRect(Rect raw, Size rawSize, int rotation) {
  final w = rawSize.width;
  final h = rawSize.height;
  Offset map(double ux, double uy) => switch (normalizeRotation(rotation)) {
    90 => Offset(h - uy, ux),
    180 => Offset(w - ux, h - uy),
    270 => Offset(uy, w - ux),
    _ => Offset(ux, uy),
  };
  return Rect.fromPoints(map(raw.left, raw.top), map(raw.right, raw.bottom));
}

/// Giữ khung trong trang (không để chữ ký tràn ra ngoài), giữ nguyên kích thước nếu vừa.
Rect clampRectInside(Rect rect, Size bounds) {
  final w = math.min(rect.width, bounds.width);
  final h = math.min(rect.height, bounds.height);
  final left = rect.left.clamp(0.0, bounds.width - w);
  final top = rect.top.clamp(0.0, bounds.height - h);
  return Rect.fromLTWH(left, top, w, h);
}
