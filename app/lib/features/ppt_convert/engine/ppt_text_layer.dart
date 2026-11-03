// Lớp chữ vô hình cho "PowerPoint → PDF": mỗi slide vẫn là một trang ảnh, nhưng chữ thật của
// slide được vẽ thêm lên trang với độ trong suốt 0 (cách của `searchable_pdf.dart`) để chọn /
// tìm / sao chép được. Chỉ gần đúng vị trí, cỡ và chỗ xuống dòng: PowerPoint thật dùng font
// khác font Noto nên bề rộng chữ có lệch chút.
//
// Hai bước: (1) [collectTextBoxes] đọc model slide (thuần, chạy ở luồng chính), (2)
// [drawSlideTextLayer] đo + ngắt dòng + vẽ bằng Syncfusion (chạy trong isolate dựng PDF).
// Font Noto theo hệ chữ, chuỗi NFC (lmm-wiki/concepts/xuat-chu-ra-pdf.md); thiếu font thì rơi về
// font chuẩn + `drawableText` (không ném ArgumentError).
import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:pptx_reader/pptx_reader.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../../convert/engine/font_set.dart';
import '../../convert/text/line_wrap.dart';
import '../../convert/text/script_runs.dart';
import '../../convert/text/vietnamese_nfc.dart';
import '../../office_pptx/pptx_layout.dart';
import '../../pdf_tools/engine/pdf_ops.dart' show drawableText;

/// Một đoạn chữ cùng định dạng trong đoạn văn (đã NFC).
class PptTextRun {
  const PptTextRun(this.text, this.sizePt, {this.bold = false, this.italic = false});
  final String text;
  final double sizePt;
  final bool bold;
  final bool italic;
}

class PptTextPara {
  const PptTextPara({
    required this.runs,
    required this.lineHeightPt,
    this.align = PptxAlign.left,
    this.leftPt = 0,
    this.firstLineIndentPt = 0,
    this.spaceBeforePt = 0,
    this.spaceAfterPt = 0,
  });

  final List<PptTextRun> runs;

  /// Chiều cao một dòng (pt).
  final double lineHeightPt;
  final PptxAlign align;
  final double leftPt;
  final double firstLineIndentPt;
  final double spaceBeforePt;
  final double spaceAfterPt;
}

/// Một khung chữ của slide (pt, gốc trên-trái slide) với các đoạn văn trong đó.
class PptTextBox {
  const PptTextBox({
    required this.rect,
    required this.paragraphs,
    this.insetLeft = 7.2,
    this.insetTop = 3.6,
    this.insetRight = 7.2,
    this.insetBottom = 3.6,
    this.anchor = PptxAnchor.top,
    this.wrap = true,
  });

  final Rect rect;
  final List<PptTextPara> paragraphs;
  final double insetLeft;
  final double insetTop;
  final double insetRight;
  final double insetBottom;
  final PptxAnchor anchor;
  final bool wrap;
}

/// Mọi khung chữ của [slide] (hình, nhóm, bảng) theo thứ tự z. Hộp không có chữ bị bỏ.
List<PptTextBox> collectTextBoxes(PptxSlide slide) {
  final out = <PptTextBox>[];
  for (final s in slide.shapes) {
    _collectShape(s, out);
  }
  return out;
}

void _collectShape(PptxShape s, List<PptTextBox> out) {
  switch (s) {
    case PptxGroupShape():
      for (final c in s.children) {
        _collectShape(c, out);
      }
    case PptxTableShape():
      final origin = rectOfFrame(s.frame);
      for (final cell in layoutTable(s)) {
        final b = _box(
          cell.cell.paragraphs,
          cell.rect.shift(origin.topLeft),
          cell.cell.insets,
          cell.cell.verticalAnchor,
          true,
        );
        if (b != null) out.add(b);
      }
    case PptxTextShape():
      if (s.unsupportedKind != null) return;
      var rect = rectOfFrame(s.frame);
      // Xoay ~90° / 270°: khung chữ đổi chiều quanh tâm (không xoay chữ).
      final rot = ((s.rotationDeg % 180) + 180) % 180;
      if (rot > 45 && rot < 135) {
        rect = Rect.fromCenter(
          center: rect.center,
          width: rect.height,
          height: rect.width,
        );
      }
      final b = _box(s.paragraphs, rect, s.insets, s.verticalAnchor, s.wrap);
      if (b != null) out.add(b);
    case PptxPictureShape():
      break;
  }
}

const double _defaultSizePt = 18;

PptTextBox? _box(
  List<PptxParagraph> paragraphs,
  Rect rect,
  PptxInsets insets,
  PptxAnchor anchor,
  bool wrap,
) {
  if (!paragraphs.any((p) => p.text.trim().isNotEmpty)) return null;
  if (!(rect.width > 0 && rect.height > 0)) return null;
  final paras = <PptTextPara>[];
  for (final p in paragraphs) {
    final runs = <PptTextRun>[];
    for (final r in p.runs) {
      final t = composeVietnamese(r.isLineBreak ? '\n' : r.text);
      if (t.isEmpty) continue;
      runs.add(
        PptTextRun(
          t,
          _size(r.fontSizePt),
          bold: r.bold,
          italic: r.italic,
        ),
      );
    }
    final size = runs.isEmpty
        ? _size(p.endFontSizePt)
        : runs.map((r) => r.sizePt).reduce(math.max);
    final hasBullet = p.numbered || (p.bulletChar ?? '').isNotEmpty;
    final left = emuToPt(p.marginLeftEmu);
    paras.add(
      PptTextPara(
        runs: runs,
        lineHeightPt: size * lineHeightFactor(p, size),
        align: p.align,
        leftPt: left,
        // Dòng đầu có bullet thì chữ bắt đầu ở lề trái (bullet nằm ở phần thụt âm).
        firstLineIndentPt: hasBullet ? 0 : emuToPt(p.indentEmu),
        spaceBeforePt: p.spaceBeforePt ?? 0,
        spaceAfterPt: p.spaceAfterPt ?? 0,
      ),
    );
  }
  return PptTextBox(
    rect: rect,
    paragraphs: paras,
    insetLeft: emuToPt(insets.left),
    insetTop: emuToPt(insets.top),
    insetRight: emuToPt(insets.right),
    insetBottom: emuToPt(insets.bottom),
    anchor: anchor,
    wrap: wrap,
  );
}

double _size(double? v) => (v != null && v.isFinite && v > 0) ? v : _defaultSizePt;

/// Các hệ chữ cần font cho [boxes] (để chỉ nạp font CJK nặng khi có chữ đó). Rỗng khi không có chữ.
Set<ScriptFace> scriptsInBoxes(Iterable<List<PptTextBox>> boxes) {
  final all = StringBuffer();
  for (final page in boxes) {
    for (final b in page) {
      for (final p in b.paragraphs) {
        for (final r in p.runs) {
          all.write(r.text);
        }
      }
    }
  }
  return all.isEmpty ? <ScriptFace>{} : scriptsIn(all.toString());
}

/// Một đoạn chữ đã đặt trên trang (pt, gốc trên-trái): [x], [lineTop] là góc trên-trái ô dòng.
class PlacedTextRun {
  const PlacedTextRun(
    this.text,
    this.face,
    this.style,
    this.x,
    this.lineTop,
    this.lineHeight,
  );
  final String text;
  final ScriptFace face;
  final StyledSpan style;
  final double x;
  final double lineTop;
  final double lineHeight;
}

/// Ngắt dòng + đặt chữ của [box] bằng [measurer]. Hàm thuần (test được bằng đo giả).
List<PlacedTextRun> layoutTextBox(PptTextBox box, TextMeasurer measurer) {
  final availW = math.max(1.0, box.rect.width - box.insetLeft - box.insetRight);
  final availH = box.rect.height - box.insetTop - box.insetBottom;

  // Bước 1: ngắt dòng cả khung để biết tổng chiều cao (cho căn dọc).
  final laid = <(PptTextPara, List<WrappedLine>)>[];
  var total = 0.0;
  for (var i = 0; i < box.paragraphs.length; i++) {
    final p = box.paragraphs[i];
    final spans = [
      for (final r in p.runs)
        StyledSpan(r.text, size: r.sizePt, bold: r.bold, italic: r.italic),
    ];
    final maxW = box.wrap ? math.max(1.0, availW - p.leftPt) : 1e7;
    final tokens = tokenize(spans, measurer, maxWidth: maxW);
    final lines = wrapTokens(tokens, maxWidth: maxW, firstLineIndent: p.firstLineIndentPt);
    laid.add((p, lines));
    total += (i == 0 ? 0 : p.spaceBeforePt) + lines.length * p.lineHeightPt;
    if (i < box.paragraphs.length - 1) total += p.spaceAfterPt;
  }

  var y = box.rect.top + box.insetTop;
  y += switch (box.anchor) {
    PptxAnchor.top => 0,
    PptxAnchor.middle => math.max(0.0, (availH - total) / 2),
    PptxAnchor.bottom => math.max(0.0, availH - total),
  };

  // Bước 2: toạ độ từng đoạn chữ.
  final out = <PlacedTextRun>[];
  for (var i = 0; i < laid.length; i++) {
    final (p, lines) = laid[i];
    if (i > 0) y += p.spaceBeforePt;
    final lineAvail = availW - p.leftPt;
    for (final line in lines) {
      final shift = switch (p.align) {
        PptxAlign.center => (lineAvail - line.width) / 2,
        PptxAlign.right => lineAvail - line.width,
        _ => 0.0,
      };
      final baseX = box.rect.left + box.insetLeft + p.leftPt + math.max(0.0, shift);
      for (final r in line.runs) {
        if (r.text.trim().isEmpty) continue;
        out.add(PlacedTextRun(r.text, r.face, r.style, baseX + r.x, y, p.lineHeightPt));
      }
      y += p.lineHeightPt;
    }
    if (i < laid.length - 1) y += p.spaceAfterPt;
  }
  return out;
}

/// Vẽ chữ vô hình của [boxes] lên [page]. Trả số đoạn chữ đã vẽ. Đồng bộ; gọi trong isolate.
/// Một đoạn lỗi font (ArgumentError) thì bỏ đoạn đó, không làm hỏng cả trang.
int drawSlideTextLayer(sf.PdfPage page, List<PptTextBox> boxes, PdfFontSet fonts) {
  final placed = <PlacedTextRun>[];
  for (final b in boxes) {
    try {
      placed.addAll(layoutTextBox(b, fonts));
    } on ArgumentError {
      continue;
    }
  }
  if (placed.isEmpty) return 0;
  final g = page.graphics;
  var drawn = 0;
  g.save();
  g.setTransparency(0);
  for (final r in placed) {
    try {
      final font = fonts.fontFor(r.face, r.style);
      final text = drawableText(fonts.safeText(r.face, r.style, r.text), font);
      final size = r.style.size ?? 12;
      g.drawString(
        text,
        font,
        brush: sf.PdfBrushes.black,
        bounds: Rect.fromLTWH(r.x, _drawTop(r.lineTop, r.lineHeight, size), 0, 0),
      );
      drawn++;
    } on ArgumentError {
      continue;
    }
  }
  g.restore();
  return drawn;
}

/// Mép trên để `drawString` sao cho đường cơ sở chữ trùng chỗ Flutter đặt khi vẽ slide:
/// Flutter căn khối chữ (cao ≈ 1.17 × cỡ, đường cơ sở ở 0.93) giữa dòng cao [lineHeight];
/// `drawString` tính từ mép trên của ô chữ Noto (đường cơ sở ở 1.069 × cỡ).
double _drawTop(double lineTop, double lineHeight, double size) =>
    lineTop + (lineHeight - 1.17 * size) / 2 + 0.93 * size - 1.069 * size;
