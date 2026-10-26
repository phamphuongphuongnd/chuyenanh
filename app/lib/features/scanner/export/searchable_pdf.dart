// Lớp chữ vô hình (OCR) phủ lên PDF ảnh quét để tìm kiếm / chọn / sao chép được (T9).
//
// Syncfusion không có chế độ vẽ chữ "render mode 3", nên dùng độ trong suốt 0 (chữ vẫn nằm trong
// content stream, trình đọc PDF vẫn tìm và chọn được). Font Noto theo hệ chữ, chuỗi NFC
// (xem lmm-wiki/concepts/xuat-chu-ra-pdf.md). Thiếu font → bỏ cả lớp chữ, PDF ảnh giữ nguyên.
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../../../engines/ocr/ocr_engine.dart';
import '../../convert/engine/font_set.dart';
import '../../convert/text/line_wrap.dart' show StyledSpan;
import '../../convert/text/script_runs.dart';
import '../../convert/text/vietnamese_nfc.dart';

/// Một dòng chữ đã đặt lên trang (point PDF, gốc trên-trái).
class PlacedLine {
  const PlacedLine(this.text, this.left, this.top, this.width, this.height);
  final String text;
  final double left;
  final double top;
  final double width;
  final double height;
}

/// Đặt các dòng OCR lên trang [pageW]×[pageH] point. Ảnh trang được giả định đặt GIỮA trang,
/// giữ tỉ lệ, không lề (đúng với `ImageToPdfOptions` mặc định của máy quét). Hàm thuần.
/// Kết quả không có kích thước ảnh → danh sách rỗng.
List<PlacedLine> placeOcrLines(OcrResult r, double pageW, double pageH) {
  final iw = r.imageWidth?.toDouble();
  final ih = r.imageHeight?.toDouble();
  if (iw == null || ih == null || iw <= 0 || ih <= 0 || pageW <= 0 || pageH <= 0) {
    return const [];
  }
  final sx = pageW / iw;
  final sy = pageH / ih;
  final s = sx < sy ? sx : sy;
  final ox = (pageW - iw * s) / 2;
  final oy = (pageH - ih * s) / 2;

  final out = <PlacedLine>[];
  void add(String text, double l, double t, double w, double h) {
    final n = composeVietnamese(text.replaceAll(RegExp(r'[\r\n]+'), ' ').trim());
    if (n.isEmpty || w <= 0 || h <= 0) return;
    out.add(PlacedLine(n, ox + l * s, oy + t * s, w * s, h * s));
  }

  for (final b in r.blocks) {
    if (b.lines.isEmpty) {
      add(b.text, b.bounds.left, b.bounds.top, b.bounds.width, b.bounds.height);
    } else {
      for (final l in b.lines) {
        add(l.text, l.bounds.left, l.bounds.top, l.bounds.width, l.bounds.height);
      }
    }
  }
  return out;
}

/// Các hệ chữ cần font trong [results].
Set<ScriptFace> scriptsInResults(List<OcrResult> results) {
  final all = StringBuffer();
  for (final r in results) {
    for (final b in r.blocks) {
      all.write(b.text);
    }
  }
  return all.isEmpty ? <ScriptFace>{} : scriptsIn(composeVietnamese(all.toString()));
}

/// Vẽ lớp chữ vô hình lên [pdf] (đồng bộ; gọi trong isolate). [results] theo đúng thứ tự trang.
/// Trả về byte PDF mới, hoặc `null` khi không có gì để vẽ / số trang không khớp / thiếu font.
Uint8List? drawInvisibleTextLayer(
  Uint8List pdf,
  List<OcrResult> results,
  Map<FontSlot, Uint8List> fontBytes,
) {
  final needed = scriptsInResults(results);
  if (needed.isEmpty) return null;
  for (final f in needed) {
    if (!fontBytes.containsKey(FontSlot.forFace(f))) {
      debugPrint('searchable_pdf: thiếu font ${FontSlot.forFace(f).assetPath}, bỏ lớp chữ');
      return null;
    }
  }
  final fonts = PdfFontSet(fontBytes);
  final doc = sf.PdfDocument(inputBytes: pdf);
  try {
    if (doc.pages.count != results.length) {
      debugPrint('searchable_pdf: số trang PDF ${doc.pages.count} != ${results.length}, bỏ lớp chữ');
      return null;
    }
    var drawn = 0;
    for (var i = 0; i < results.length; i++) {
      final page = doc.pages[i];
      final size = page.size;
      final lines = placeOcrLines(results[i], size.width, size.height);
      if (lines.isEmpty) continue;
      final g = page.graphics;
      g.save();
      g.setTransparency(0);
      for (final line in lines) {
        _drawLine(g, fonts, line);
        drawn++;
      }
      g.restore();
    }
    if (drawn == 0) return null;
    return Uint8List.fromList(doc.saveSync());
  } finally {
    doc.dispose();
  }
}

void _drawLine(sf.PdfGraphics g, PdfFontSet fonts, PlacedLine line) {
  final runs = splitScriptRuns(line.text);
  final base = line.height * 0.8;
  double measure(double size) {
    var w = 0.0;
    for (final r in runs) {
      w += fonts.width(r.face, StyledSpan('', size: size), r.text) + _trailingSpaces(r.text) * fonts.spaceWidth(r.face, StyledSpan('', size: size));
    }
    return w;
  }

  final w0 = measure(base);
  if (w0 <= 0) return;
  // Chọn cỡ chữ để bề rộng chữ khớp bề rộng hộp (giới hạn để dòng 1 ký tự không phình to).
  final size = (base * line.width / w0).clamp(base * 0.4, base * 2.0).toDouble();
  var x = line.left;
  final y = line.top + (line.height - size) / 2;
  for (final r in runs) {
    final style = StyledSpan('', size: size);
    final font = fonts.fontFor(r.face, style);
    final text = fonts.safeText(r.face, style, r.text);
    g.drawString(text, font, brush: sf.PdfBrushes.black, bounds: Rect.fromLTWH(x, y, 0, 0));
    x += fonts.width(r.face, style, r.text) + _trailingSpaces(r.text) * fonts.spaceWidth(r.face, style);
  }
}

// `measureString` cắt dấu cách cuối đoạn → cộng bù (xem xuat-chu-ra-pdf.md).
int _trailingSpaces(String s) {
  var n = 0;
  for (var i = s.length - 1; i >= 0 && s[i] == ' '; i--) {
    n++;
  }
  return n;
}

/// Thêm lớp chữ vô hình vào PDF [pdf]. Mọi lỗi → `null` (PDF gốc vẫn dùng được), không ném.
Future<Uint8List?> addInvisibleTextLayer(
  Uint8List pdf,
  List<OcrResult> results,
  FontSource fontSource,
) async {
  try {
    final needed = scriptsInResults(results);
    if (needed.isEmpty) return null;
    final fontBytes = await loadFontBytes(fontSource, needed, needBold: false);
    return await Isolate.run(() => drawInvisibleTextLayer(pdf, results, fontBytes));
  } catch (e) {
    debugPrint('searchable_pdf: lỗi tạo lớp chữ ($e), giữ PDF ảnh');
    return null;
  }
}
