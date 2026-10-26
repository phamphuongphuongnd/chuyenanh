import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../text/line_wrap.dart';
import '../text/script_runs.dart';
import 'font_set.dart';

enum FlowAlign { left, center, right }

/// Ô của bảng vẽ bằng [PdfFlowWriter.table].
class GridCell {
  const GridCell(
    this.spans, {
    this.colSpan = 1,
    this.covered = false,
    this.fillArgb,
    this.align = FlowAlign.left,
    this.wrap = true,
    this.borderArgb = 0xFF808080,
    this.border = true,
  });

  final List<StyledSpan> spans;
  final int colSpan;

  /// Ô bị gộp che (chỉ vẽ nền/viền, không có chữ).
  final bool covered;
  final int? fillArgb;
  final FlowAlign align;

  /// false = một dòng, cắt phần tràn.
  final bool wrap;
  final int borderArgb;
  final bool border;
}

PdfColor _color(int argb) => PdfColor((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF);

/// Viết PDF theo dòng chảy: đoạn văn (đa font theo hệ chữ), bảng, ảnh, ngắt trang.
/// Chạy đồng bộ, không phụ thuộc Flutter UI → dùng được trong isolate.
class PdfFlowWriter {
  PdfFlowWriter(
    this.fonts, {
    required this.pageWidth,
    required this.pageHeight,
    required this.margin,
    this.baseSize = 12,
  }) {
    _doc = PdfDocument();
    _doc.pageSettings.size = Size(pageWidth, pageHeight);
    _doc.pageSettings.margins.all = 0;
    _newPage();
  }

  final PdfFontSet fonts;
  final double pageWidth;
  final double pageHeight;
  final double margin;
  final double baseSize;

  late final PdfDocument _doc;
  late PdfPage _page;
  double y = 0;
  bool _pageHasContent = false;

  double get contentWidth => pageWidth - 2 * margin;
  double get contentHeight => pageHeight - 2 * margin;
  int get pageCount => _doc.pages.count;

  void _newPage() {
    _page = _doc.pages.add();
    y = margin;
    _pageHasContent = false;
  }

  /// Ngắt trang; không tạo trang trắng thừa nếu trang hiện tại còn trống.
  void pageBreak() {
    if (_pageHasContent) _newPage();
  }

  void _ensureSpace(double h) {
    if (y + h > pageHeight - margin + 0.01 && _pageHasContent) _newPage();
  }

  StyledSpan _fill(StyledSpan s, double size) {
    final base = s.size ?? size;
    return StyledSpan(
      s.text,
      bold: s.bold,
      italic: s.italic,
      underline: s.underline,
      strike: s.strike,
      size: s.rise != 0 ? base * 0.7 : base,
      colorArgb: s.colorArgb,
      highlightArgb: s.highlightArgb,
      rise: s.rise,
    );
  }

  double _lineHeight(WrappedLine line, double size, double spacing) {
    var h = 0.0;
    for (final r in line.runs) {
      final fh = fonts.fontFor(r.face, r.style).height;
      if (fh > h) h = fh;
    }
    if (h == 0) h = fonts.fontFor(ScriptFace.latin, StyledSpan('', size: size)).height;
    return h * spacing;
  }


  void _drawRun(PdfGraphics g, PlacedRun r, double x, double top, double lineH) {
    final font = fonts.fontFor(r.face, r.style);
    final text = fonts.safeText(r.face, r.style, r.text);
    var ty = top + (lineH - font.height) / 2;
    if (r.style.rise > 0) ty -= font.height * 0.25;
    if (r.style.rise < 0) ty += font.height * 0.2;
    if (r.style.highlightArgb != null) {
      g.drawRectangle(
        brush: PdfSolidBrush(_color(r.style.highlightArgb!)),
        bounds: Rect.fromLTWH(x, top, r.width, lineH),
      );
    }
    final brush = PdfSolidBrush(_color(r.style.colorArgb ?? 0xFF000000));
    g.drawString(text, font, brush: brush, bounds: Rect.fromLTWH(x, ty, 0, 0));
    final pen = PdfPen(_color(r.style.colorArgb ?? 0xFF000000), width: 0.6);
    if (r.style.underline) {
      final ly = ty + font.height * 0.92;
      g.drawLine(pen, Offset(x, ly), Offset(x + r.width, ly));
    }
    if (r.style.strike) {
      final ly = ty + font.height * 0.55;
      g.drawLine(pen, Offset(x, ly), Offset(x + r.width, ly));
    }
  }

  double _alignDx(FlowAlign a, double avail, double lineEnd) => switch (a) {
        FlowAlign.left => 0,
        FlowAlign.center => (avail - lineEnd) / 2,
        FlowAlign.right => avail - lineEnd,
      };

  /// Một đoạn văn. [marker] (nhãn danh sách) vẽ bên trái [indentLeft].
  void paragraph(
    List<StyledSpan> spans, {
    double? fontSize,
    FlowAlign align = FlowAlign.left,
    double indentLeft = 0,
    double indentRight = 0,
    double firstLineIndent = 0,
    double spaceBefore = 0,
    double spaceAfter = 0,
    double lineSpacing = 1.0,
    String? marker,
  }) {
    final size = fontSize ?? baseSize;
    final filled = [for (final s in spans) _fill(s, size)];
    final avail = (contentWidth - indentLeft - indentRight).clamp(20.0, double.infinity);
    final tokens = tokenize(filled, fonts, maxWidth: avail);
    final lines = wrapTokens(tokens, maxWidth: avail, firstLineIndent: firstLineIndent);
    if (spaceBefore > 0 && _pageHasContent) y += spaceBefore;
    var first = true;
    for (final line in lines) {
      final h = _lineHeight(line, size, lineSpacing);
      _ensureSpace(h);
      final g = _page.graphics;
      final dx = _alignDx(align, avail, line.width);
      final left = margin + indentLeft + dx;
      if (first && marker != null && marker.isNotEmpty) {
        final st = filled.isEmpty ? StyledSpan('', size: size) : filled.first;
        final mw = fonts.width(ScriptFace.latin, st, marker);
        final run = PlacedRun(text: marker, face: ScriptFace.latin, style: st, x: 0, width: mw);
        _drawRun(g, run, margin + indentLeft + (firstLineIndent < 0 ? firstLineIndent : -mw - 4), y, h);
      }
      for (final r in line.runs) {
        _drawRun(g, r, left + r.x, y, h);
      }
      y += h;
      _pageHasContent = true;
      first = false;
    }
    y += spaceAfter;
  }


  /// Dòng trống cao [h] point.
  void gap(double h) {
    y += h;
  }

  /// Ảnh PNG/JPEG, thu nhỏ vừa chiều rộng/cao trang. Định dạng khác bị bỏ qua (trả false).
  bool image(Uint8List bytes, {double? width, double? height, FlowAlign align = FlowAlign.left}) {
    PdfBitmap bmp;
    try {
      bmp = PdfBitmap(bytes);
    } catch (e) {
      debugPrint('convert: bỏ qua ảnh không đọc được ($e)');
      return false;
    }
    var w = width ?? bmp.width.toDouble();
    var h = height ?? bmp.height.toDouble();
    if (w <= 0 || h <= 0) return false;
    final k = [1.0, contentWidth / w, contentHeight / h].reduce((a, b) => a < b ? a : b);
    w *= k;
    h *= k;
    _ensureSpace(h);
    final x = margin + _alignDx(align, contentWidth, w);
    _page.graphics.drawImage(bmp, Rect.fromLTWH(x, y, w, h));
    y += h + 4;
    _pageHasContent = true;
    return true;
  }

  /// Bảng: [colWidths] (point), mỗi hàng là danh sách ô theo thứ tự cột (ô `colSpan` chiếm nhiều cột).
  /// Hàng không tách qua trang. Trả về số hàng đã vẽ.
  void table({
    required List<double> colWidths,
    required List<List<GridCell>> rows,
    double? fontSize,
    double padding = 3,
    double minRowHeight = 0,
    double left = 0,
  }) {
    final size = fontSize ?? baseSize;
    for (final row in rows) {
      // Bố cục từng ô.
      final laid = <_CellLayout>[];
      var col = 0;
      var rowH = minRowHeight;
      for (final cell in row) {
        final span = cell.colSpan.clamp(1, colWidths.length - col <= 0 ? 1 : colWidths.length - col);
        var w = 0.0;
        for (var c = col; c < col + span && c < colWidths.length; c++) {
          w += colWidths[c];
        }
        final inner = (w - 2 * padding).clamp(4.0, double.infinity);
        final filled = [for (final s in cell.spans) _fill(s, size)];
        final tokens = cell.covered
            ? <LayoutToken>[]
            : tokenize(filled, fonts, maxWidth: cell.wrap ? inner : 100000);
        var lines = cell.covered
            ? <WrappedLine>[]
            : wrapTokens(tokens, maxWidth: cell.wrap ? inner : 100000);
        if (lines.length == 1 && lines.single.runs.isEmpty) lines = [];
        var h = 2 * padding;
        final lineHs = <double>[];
        for (final l in lines) {
          final lh = _lineHeight(l, size, 1.0);
          lineHs.add(lh);
          h += lh;
        }
        if (lines.isEmpty) {
          h = 2 * padding + fonts.fontFor(ScriptFace.latin, StyledSpan('', size: size)).height;
        }
        if (h > rowH) rowH = h;
        laid.add(_CellLayout(cell, col, w, inner, lines, lineHs));
        col += span;
      }
      if (rowH > contentHeight) rowH = contentHeight;
      _ensureSpace(rowH);
      final g = _page.graphics;
      for (final c in laid) {
        var x = margin + left;
        for (var i = 0; i < c.col && i < colWidths.length; i++) {
          x += colWidths[i];
        }
        final rect = Rect.fromLTWH(x, y, c.width, rowH);
        if (c.cell.fillArgb != null) {
          g.drawRectangle(brush: PdfSolidBrush(_color(c.cell.fillArgb!)), bounds: rect);
        }
        if (c.cell.border) {
          g.drawRectangle(pen: PdfPen(_color(c.cell.borderArgb), width: 0.5), bounds: rect);
        }
        if (c.lines.isEmpty) continue;
        g.save();
        g.setClip(bounds: rect);
        var ty = y + padding;
        for (var i = 0; i < c.lines.length; i++) {
          final line = c.lines[i];
          final dx = _alignDx(c.cell.align, c.inner, line.width);
          for (final r in line.runs) {
            _drawRun(g, r, x + padding + dx + r.x, ty, c.lineHs[i]);
          }
          ty += c.lineHs[i];
        }
        g.restore();
      }
      y += rowH;
      _pageHasContent = true;
    }
  }

  /// Hoàn tất, trả về byte PDF.
  Uint8List finish() {
    final bytes = Uint8List.fromList(_doc.saveSync());
    _doc.dispose();
    return bytes;
  }
}

class _CellLayout {
  _CellLayout(this.cell, this.col, this.width, this.inner, this.lines, this.lineHs);
  final GridCell cell;
  final int col;
  final double width;
  final double inner;
  final List<WrappedLine> lines;
  final List<double> lineHs;
}
