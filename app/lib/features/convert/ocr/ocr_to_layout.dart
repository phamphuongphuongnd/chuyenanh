// Đổi kết quả OCR (pixel ảnh) thành [LayoutPage] của `pdf_layout` (point PDF). Hàm thuần.
import 'dart:ui' show Rect;

import 'package:pdf_layout/pdf_layout.dart';

import '../../../engines/ocr/ocr_engine.dart';
import '../text/vietnamese_nfc.dart';

/// Tỉ lệ cỡ chữ / chiều cao hộp dòng (hộp OCR gồm cả phần dấu và chân chữ).
const ocrFontSizeRatio = 0.8;

/// Cạnh dài tối đa (px) của ảnh trang đưa vào OCR.
const ocrLongSidePx = 2560;

/// DPI render trang cho OCR: [targetDpi] nhưng không để cạnh dài vượt [ocrLongSidePx].
double ocrRenderDpi(double pageWidthPt, double pageHeightPt, {double targetDpi = 200}) {
  final longPt = pageWidthPt > pageHeightPt ? pageWidthPt : pageHeightPt;
  if (longPt <= 0) return targetDpi;
  final maxDpi = ocrLongSidePx / (longPt / 72);
  return maxDpi < targetDpi ? maxDpi : targetDpi;
}

/// [r] trên trang [pageIndex] rộng [pageWidth] × cao [pageHeight] point.
///
/// Kích thước ảnh lấy từ `r.imageWidth/imageHeight`, thiếu thì dùng [pixelWidth]/[pixelHeight];
/// vẫn thiếu → coi ảnh render ở 200 dpi. Dòng rỗng bị bỏ, sắp từ trên xuống
/// (cùng hàng thì trái sang phải). Chữ chuẩn hoá NFC.
LayoutPage ocrResultToLayoutPage(
  OcrResult r, {
  required int pageIndex,
  required double pageWidth,
  required double pageHeight,
  int? pixelWidth,
  int? pixelHeight,
}) {
  final pw = (r.imageWidth ?? pixelWidth)?.toDouble();
  final ph = (r.imageHeight ?? pixelHeight)?.toDouble();
  final sx = (pw != null && pw > 0) ? pageWidth / pw : 72 / 200;
  final sy = (ph != null && ph > 0) ? pageHeight / ph : 72 / 200;

  final lines = <LayoutLine>[];
  void add(String text, Rect b) {
    final t = composeVietnamese(text.trim());
    if (t.isEmpty || b.width <= 0 || b.height <= 0) return;
    final h = b.height * sy;
    lines.add(LayoutLine(
      pageIndex: pageIndex,
      text: t,
      bounds: LayoutRect(left: b.left * sx, top: b.top * sy, width: b.width * sx, height: h),
      fontSize: h * ocrFontSizeRatio,
    ));
  }

  for (final b in r.blocks) {
    if (b.lines.isEmpty) {
      add(b.text.replaceAll('\n', ' '), b.bounds);
    } else {
      for (final l in b.lines) {
        add(l.text, l.bounds);
      }
    }
  }
  return LayoutPage(
    index: pageIndex,
    width: pageWidth,
    height: pageHeight,
    lines: _readingOrder(lines),
  );
}

/// Sắp theo thứ tự đọc: gom hàng theo tâm dọc (lệch < nửa chiều cao dòng đầu hàng), mỗi hàng trái → phải.
List<LayoutLine> _readingOrder(List<LayoutLine> lines) {
  final byY = [...lines]..sort((a, b) => a.bounds.centerY.compareTo(b.bounds.centerY));
  final out = <LayoutLine>[];
  var i = 0;
  while (i < byY.length) {
    final first = byY[i];
    final row = <LayoutLine>[first];
    var j = i + 1;
    while (j < byY.length &&
        (byY[j].bounds.centerY - first.bounds.centerY).abs() < first.bounds.height / 2) {
      row.add(byY[j]);
      j++;
    }
    row.sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
    out.addAll(row);
    i = j;
  }
  return out;
}
