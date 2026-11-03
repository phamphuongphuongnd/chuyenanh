// Lớp chữ vô hình cho nén PDF mức Vừa / Mạnh: trang đã thành ảnh JPEG nhưng chữ gốc vẫn
// chọn / tìm / sao chép được. Chữ + toạ độ lấy từ chính PDF gốc (không OCR), vẽ độ trong suốt 0
// (cách của scanner/export/searchable_pdf.dart), font Noto theo hệ chữ, chuỗi NFC
// (lmm-wiki/concepts/xuat-chu-ra-pdf.md). Thiếu font → bỏ cả lớp chữ, PDF ảnh giữ nguyên.
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../../convert/engine/font_set.dart';
import '../../convert/engine/pdf_extract.dart' show layoutLineFromTextLine;
import '../../convert/text/line_wrap.dart' show StyledSpan;
import '../../convert/text/script_runs.dart';
import '../../convert/text/vietnamese_nfc.dart';
import 'isolate_job.dart';
import 'pdf_ops.dart' show openPdfFile;

/// Một dòng chữ gốc: `[text, left, top, width, height]` (point, gốc trên-trái) — dạng sendable.
typedef TextLineData = List<Object>;

/// Job (isolate): trích chữ từng trang của PDF gốc. Trả `List<List<TextLineData>>` theo thứ tự
/// trang; trang xoay (rotation ≠ 0) hoặc không có chữ → danh sách rỗng.
Future<Object?> compressExtractTextJob(
  Map<String, Object?> args,
  JobPort port,
) async {
  final input = args['input'] as String;
  final password = args['password'] as String?;
  final doc = await openPdfFile(input, password: password);
  try {
    final extractor = sf.PdfTextExtractor(doc);
    final n = doc.pages.count;
    final pages = <List<TextLineData>>[];
    for (var i = 0; i < n; i++) {
      final lines = <TextLineData>[];
      if (doc.pages[i].rotation == sf.PdfPageRotateAngle.rotateAngle0) {
        for (final t in extractor.extractTextLines(startPageIndex: i, endPageIndex: i)) {
          if (t.text.trim().isEmpty) continue;
          final l = layoutLineFromTextLine(t);
          final text = composeVietnamese(l.text.replaceAll(RegExp(r'[\r\n]+'), ' ').trim());
          final b = l.bounds;
          if (text.isEmpty || b.width <= 0 || b.height <= 0) continue;
          lines.add(<Object>[text, b.left, b.top, b.width, b.height]);
        }
      }
      pages.add(lines);
      port.progress((i + 1) / n);
    }
    return pages;
  } finally {
    doc.dispose();
  }
}

/// Các hệ chữ cần font để vẽ [pages].
Set<ScriptFace> scriptsInPages(List<List<TextLineData>> pages) {
  final all = StringBuffer();
  for (final lines in pages) {
    for (final l in lines) {
      all.write(l[0] as String);
    }
  }
  return all.isEmpty ? <ScriptFace>{} : scriptsIn(all.toString());
}

/// Có dòng chữ nào không.
bool hasAnyTextLine(List<List<TextLineData>> pages) =>
    pages.any((p) => p.isNotEmpty);

/// Vẽ [lines] (chữ vô hình) lên [g]. Trả số dòng đã vẽ.
int drawInvisibleLines(
  sf.PdfGraphics g,
  PdfFontSet fonts,
  List<TextLineData> lines,
) {
  if (lines.isEmpty) return 0;
  var drawn = 0;
  g.save();
  g.setTransparency(0);
  for (final l in lines) {
    if (_drawLine(
      g,
      fonts,
      l[0] as String,
      (l[1] as num).toDouble(),
      (l[2] as num).toDouble(),
      (l[3] as num).toDouble(),
      (l[4] as num).toDouble(),
    )) {
      drawn++;
    }
  }
  g.restore();
  return drawn;
}

bool _drawLine(
  sf.PdfGraphics g,
  PdfFontSet fonts,
  String text,
  double left,
  double top,
  double width,
  double height,
) {
  final runs = splitScriptRuns(text);
  final base = height * 0.8;
  double measure(double size) {
    var w = 0.0;
    for (final r in runs) {
      final s = StyledSpan('', size: size);
      w += fonts.width(r.face, s, r.text) +
          _trailingSpaces(r.text) * fonts.spaceWidth(r.face, s);
    }
    return w;
  }

  final w0 = measure(base);
  if (w0 <= 0) return false;
  // Cỡ chữ để bề rộng chữ khớp hộp gốc (giới hạn để dòng ngắn không phình to).
  final size = (base * width / w0).clamp(base * 0.4, base * 2.0).toDouble();
  var x = left;
  final y = top + (height - size) / 2;
  for (final r in runs) {
    final style = StyledSpan('', size: size);
    final font = fonts.fontFor(r.face, style);
    g.drawString(
      fonts.safeText(r.face, style, r.text),
      font,
      brush: sf.PdfBrushes.black,
      bounds: Rect.fromLTWH(x, y, 0, 0),
    );
    x += fonts.width(r.face, style, r.text) +
        _trailingSpaces(r.text) * fonts.spaceWidth(r.face, style);
  }
  return true;
}

int _trailingSpaces(String s) {
  var n = 0;
  for (var i = s.length - 1; i >= 0 && s[i] == ' '; i--) {
    n++;
  }
  return n;
}

/// `true` nếu [fontBytes] đủ font cho [needed]; thiếu thì log và trả `false`.
bool fontsCover(Set<ScriptFace> needed, Map<FontSlot, Uint8List> fontBytes) {
  for (final f in needed) {
    if (!fontBytes.containsKey(FontSlot.forFace(f))) {
      debugPrint('compress: thiếu font ${FontSlot.forFace(f).assetPath}, bỏ lớp chữ');
      return false;
    }
  }
  return true;
}
