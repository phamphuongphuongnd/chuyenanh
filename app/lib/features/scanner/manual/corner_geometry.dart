import 'package:image_ops/image_ops.dart' as ops;

/// Hình hình học thuần cho màn kéo 4 góc thủ công. Toạ độ chuẩn hoá 0..1,
/// thứ tự góc: trên-trái, trên-phải, dưới-phải, dưới-trái (như `perspectiveWarp`).

/// Khung mặc định khi chưa nhận được viền: lùi vào [inset] mỗi cạnh.
List<ops.NormPoint> defaultCorners({double inset = 0.1}) => [
  ops.NormPoint(inset, inset),
  ops.NormPoint(1 - inset, inset),
  ops.NormPoint(1 - inset, 1 - inset),
  ops.NormPoint(inset, 1 - inset),
];

/// Giữ điểm trong khung ảnh 0..1.
ops.NormPoint clampPoint(ops.NormPoint p) =>
    ops.NormPoint(p.x.clamp(0.0, 1.0), p.y.clamp(0.0, 1.0));

/// Chỉ số góc gần [p] nhất trong bán kính [maxDistance] (đơn vị chuẩn hoá), `null` nếu không có.
int? nearestCornerIndex(
  List<ops.NormPoint> corners,
  ops.NormPoint p, {
  double maxDistance = 0.12,
}) {
  int? best;
  var bestD = maxDistance * maxDistance;
  for (var i = 0; i < corners.length; i++) {
    final dx = corners[i].x - p.x;
    final dy = corners[i].y - p.y;
    final d = dx * dx + dy * dy;
    if (d <= bestD) {
      bestD = d;
      best = i;
    }
  }
  return best;
}

/// Diện tích đa giác (shoelace), luôn dương.
double quadArea(List<ops.NormPoint> q) {
  var s = 0.0;
  for (var i = 0; i < q.length; i++) {
    final a = q[i];
    final b = q[(i + 1) % q.length];
    s += a.x * b.y - b.x * a.y;
  }
  return s.abs() / 2;
}

/// Tứ giác hợp lệ để cắt: lồi, không tự cắt, đủ lớn ([minArea] so với cả ảnh).
bool isValidQuad(List<ops.NormPoint> q, {double minArea = 0.02}) {
  if (q.length != 4) return false;
  var sign = 0;
  for (var i = 0; i < 4; i++) {
    final a = q[i];
    final b = q[(i + 1) % 4];
    final c = q[(i + 2) % 4];
    final cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
    if (cross == 0) return false;
    final s = cross > 0 ? 1 : -1;
    if (sign == 0) {
      sign = s;
    } else if (s != sign) {
      return false;
    }
  }
  return quadArea(q) >= minArea;
}
