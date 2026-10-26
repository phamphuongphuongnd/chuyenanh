import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../../../engines/pdf/pdf_tools_engine.dart';

/// [WatermarkSpec] kèm vị trí. [alignX]/[alignY] trong -1..1: (0,0) giữa trang,
/// (-1,-1) góc trên trái, (1,1) góc dưới phải. (Interface gốc chỉ đặt giữa trang.)
class PlacedWatermarkSpec extends WatermarkSpec {
  const PlacedWatermarkSpec.text(
    super.text, {
    super.fontSize,
    super.colorArgb,
    super.opacity,
    super.angle,
    this.alignX = 0,
    this.alignY = 0,
  }) : super.text();

  const PlacedWatermarkSpec.image(
    super.imageBytes, {
    super.imageScale,
    super.opacity,
    super.angle,
    this.alignX = 0,
    this.alignY = 0,
  }) : super.image();

  final double alignX;
  final double alignY;
}

/// Toạ độ tâm watermark trên trang [pageW]×[pageH] (point, gốc trên trái).
///
/// Watermark có kích thước [itemW]×[itemH] trước khi xoay [angleDeg] độ; tâm được dịch theo
/// ([alignX], [alignY]) sao cho khung bao sau khi xoay không tràn khỏi trang (cách mép [pad]).
/// Khung bao lớn hơn trang → ở lại giữa trang theo trục đó.
Offset watermarkCenter({
  required double pageW,
  required double pageH,
  required double itemW,
  required double itemH,
  required double angleDeg,
  double alignX = 0,
  double alignY = 0,
  double pad = 12,
}) {
  final rad = angleDeg * math.pi / 180;
  final c = math.cos(rad).abs();
  final s = math.sin(rad).abs();
  final halfW = (itemW * c + itemH * s) / 2;
  final halfH = (itemW * s + itemH * c) / 2;
  final roomX = math.max(0.0, pageW / 2 - halfW - pad);
  final roomY = math.max(0.0, pageH / 2 - halfH - pad);
  return Offset(
    pageW / 2 + alignX.clamp(-1.0, 1.0) * roomX,
    pageH / 2 + alignY.clamp(-1.0, 1.0) * roomY,
  );
}
