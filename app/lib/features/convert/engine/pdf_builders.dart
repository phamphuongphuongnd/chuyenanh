// Dựng PDF từ chữ / DOCX / XLSX. Mọi hàm đồng bộ, chỉ nhận dữ liệu thuần → chạy được trong isolate.

import 'package:flutter/foundation.dart';
import 'package:office_reader/office_reader.dart' as office;

import '../../../engines/convert/convert_engine.dart';
import '../text/line_wrap.dart';
import '../text/script_runs.dart';
import '../text/vietnamese_nfc.dart';
import 'flow_writer.dart';
import 'font_set.dart';

typedef Report = void Function(double progress);

/// Kích thước trang (point) theo tuỳ chọn.
(double, double) pageDimensions(ToPdfOptions o) {
  final (w, h) = o.pageSize.portraitPoints;
  return o.landscape ? (h, w) : (w, h);
}

PdfFlowWriter _writer(PdfFontSet fonts, ToPdfOptions o) {
  final (w, h) = pageDimensions(o);
  final margin = o.marginPoints.clamp(0.0, (w < h ? w : h) / 3);
  return PdfFlowWriter(fonts, pageWidth: w, pageHeight: h, margin: margin, baseSize: o.fontSize);
}

class PdfBuildResult {
  const PdfBuildResult(this.bytes, this.pageCount);
  final Uint8List bytes;
  final int pageCount;
}

// ---------------------------------------------------------------- Chữ thuần

PdfBuildResult buildTextPdf(
  String text,
  ToPdfOptions options,
  PdfFontSet fonts, {
  Report? report,
}) {
  final w = _writer(fonts, options);
  final lines = normalizeForPdf(text).split('\n');
  for (var i = 0; i < lines.length; i++) {
    w.paragraph([StyledSpan(lines[i])]);
    if (i % 100 == 0) report?.call(i / lines.length);
  }
  final pages = w.pageCount;
  report?.call(1);
  return PdfBuildResult(w.finish(), pages);
}

// -------------------------------------------------------------------- DOCX

String docxPlainText(office.DocxDocument doc) {
  final b = StringBuffer();
  void walk(List<office.DocxBlock> blocks) {
    for (final blk in blocks) {
      switch (blk) {
        case office.DocxParagraph p:
          b.writeln(p.plainText);
        case office.DocxTable t:
          for (final r in t.rows) {
            for (final c in r.cells) {
              walk(c.blocks);
            }
          }
        case office.DocxPageBreak():
          break;
      }
    }
  }

  walk(doc.blocks);
  return b.toString();
}

const _headingScale = [1.8, 1.5, 1.25, 1.1, 1.0, 1.0];

List<StyledSpan> _docxSpans(office.DocxParagraph p, ToPdfOptions o, {List<office.DocxImage>? images}) {
  final spans = <StyledSpan>[];
  final level = p.headingLevel;
  for (final inl in p.inlines) {
    switch (inl) {
      case office.DocxRun r:
        final txt = normalizeForPdf(r.text);
        if (txt.isEmpty) continue;
        final link = r.hyperlink != null;
        spans.add(StyledSpan(
          txt,
          bold: r.bold || level != null,
          italic: r.italic,
          underline: r.underline || (link && r.colorArgb == null),
          strike: r.strike,
          size: r.fontSizePt ?? (level != null ? o.fontSize * _headingScale[(level - 1).clamp(0, 5)] : null),
          colorArgb: r.colorArgb ?? (link ? 0xFF1155CC : null),
          highlightArgb: r.highlightArgb,
          rise: r.superscript ? 1 : (r.subscript ? -1 : 0),
        ));
      case office.DocxBreak():
        spans.add(const StyledSpan('\n'));
      case office.DocxImage img:
        images?.add(img);
    }
  }
  return spans;
}

FlowAlign _align(office.DocxAlign a) => switch (a) {
      office.DocxAlign.center => FlowAlign.center,
      office.DocxAlign.right => FlowAlign.right,
      _ => FlowAlign.left,
    };

void _docxParagraph(PdfFlowWriter w, office.DocxParagraph p, ToPdfOptions o) {
  if (p.pageBreakBefore) w.pageBreak();
  final images = <office.DocxImage>[];
  final spans = _docxSpans(p, o, images: images);
  final isList = p.listLevel != null;
  final indent = p.indentLeftPt ?? (isList ? 18.0 * (p.listLevel! + 1) : 0.0);
  final hasText = spans.any((s) => s.text.trim().isNotEmpty);
  if (hasText || images.isEmpty) {
    w.paragraph(
      spans,
      align: _align(p.align),
      indentLeft: indent.clamp(0.0, w.contentWidth / 2),
      indentRight: (p.indentRightPt ?? 0).clamp(0.0, w.contentWidth / 4),
      firstLineIndent: isList ? 0 : (p.firstLineIndentPt ?? 0).clamp(-indent, w.contentWidth / 3),
      spaceBefore: (p.spaceBeforePt ?? 0).clamp(0.0, 40.0),
      spaceAfter: (p.spaceAfterPt ?? (p.headingLevel != null ? 6 : 4)).clamp(0.0, 40.0),
      lineSpacing: (p.lineSpacing ?? 1.0).clamp(1.0, 2.5),
      marker: isList ? p.listLabel : null,
    );
  }
  for (final img in images) {
    w.image(img.bytes, width: img.widthPt, height: img.heightPt);
  }
}

List<StyledSpan> _cellSpans(List<office.DocxBlock> blocks, ToPdfOptions o) {
  final out = <StyledSpan>[];
  for (final b in blocks) {
    if (b is office.DocxParagraph) {
      if (out.isNotEmpty) out.add(const StyledSpan('\n'));
      if (b.listLabel != null) out.add(StyledSpan('${b.listLabel} '));
      out.addAll(_docxSpans(b, o));
    } else if (b is office.DocxTable) {
      for (final r in b.rows) {
        for (final c in r.cells) {
          out.addAll(_cellSpans(c.blocks, o));
        }
      }
    }
  }
  return out;
}

void _docxTable(PdfFlowWriter w, office.DocxTable t, ToPdfOptions o) {
  if (t.rows.isEmpty) return;
  var ncols = t.columnWidthsTwips.length;
  for (final r in t.rows) {
    final n = r.cells.fold<int>(0, (a, c) => a + c.gridSpan);
    if (n > ncols) ncols = n;
  }
  if (ncols == 0) return;
  final widths = <double>[
    for (var i = 0; i < ncols; i++)
      i < t.columnWidthsTwips.length && t.columnWidthsTwips[i] > 0 ? t.columnWidthsTwips[i] / 20 : 0,
  ];
  final known = widths.where((x) => x > 0).fold<double>(0, (a, b) => a + b);
  final unknownCount = widths.where((x) => x == 0).length;
  if (unknownCount > 0) {
    final each = known > 0 ? (known / (ncols - unknownCount)) : w.contentWidth / ncols;
    for (var i = 0; i < ncols; i++) {
      if (widths[i] == 0) widths[i] = each;
    }
  }
  final total = widths.fold<double>(0, (a, b) => a + b);
  if (total > w.contentWidth) {
    final k = w.contentWidth / total;
    for (var i = 0; i < ncols; i++) {
      widths[i] *= k;
    }
  }
  final rows = <List<GridCell>>[
    for (final r in t.rows)
      [
        for (final c in r.cells)
          GridCell(
            _cellSpans(c.blocks, o),
            colSpan: c.gridSpan,
            covered: c.vMergeContinue,
            fillArgb: c.shadingArgb,
            border: t.bordered,
          ),
      ],
  ];
  w.table(colWidths: widths, rows: rows, fontSize: o.fontSize, padding: 3);
  w.gap(6);
}

PdfBuildResult buildDocxPdf(
  office.DocxDocument doc,
  ToPdfOptions options,
  PdfFontSet fonts, {
  Report? report,
}) {
  final w = _writer(fonts, options);
  final blocks = doc.blocks;
  for (var i = 0; i < blocks.length; i++) {
    switch (blocks[i]) {
      case office.DocxParagraph p:
        _docxParagraph(w, p, options);
      case office.DocxTable t:
        _docxTable(w, t, options);
      case office.DocxPageBreak():
        w.pageBreak();
    }
    if (i % 20 == 0) report?.call(i / blocks.length);
  }
  final pages = w.pageCount;
  report?.call(1);
  return PdfBuildResult(w.finish(), pages);
}

// -------------------------------------------------------------------- XLSX

String xlsxPlainText(office.XlsxWorkbook wb) {
  final b = StringBuffer();
  for (final s in wb.sheets) {
    b.writeln(s.name);
    for (final c in s.cells.values) {
      b.writeln(c.display);
    }
  }
  return b.toString();
}

/// Chia các cột thành dải, mỗi dải tổng chiều rộng ≤ [maxWidth] (mỗi dải ≥ 1 cột). Trả về chỉ số cột.
List<List<int>> partitionColumns(List<double> widths, double maxWidth) {
  final bands = <List<int>>[];
  var cur = <int>[];
  var sum = 0.0;
  for (var i = 0; i < widths.length; i++) {
    if (cur.isNotEmpty && sum + widths[i] > maxWidth + 0.01) {
      bands.add(cur);
      cur = <int>[];
      sum = 0;
    }
    cur.add(i);
    sum += widths[i];
  }
  if (cur.isNotEmpty) bands.add(cur);
  return bands;
}

const _maxXlsxRows = 50000;

PdfBuildResult buildXlsxPdf(
  office.XlsxWorkbook wb,
  ToPdfOptions options,
  PdfFontSet fonts, {
  Report? report,
}) {
  final w = _writer(fonts, options);
  const cellSize = 10.0;
  final sheets = wb.sheets.where((s) => !s.hidden).toList();
  for (var si = 0; si < sheets.length; si++) {
    final s = sheets[si];
    var lastRow = -1;
    var lastCol = -1;
    for (final e in s.cells.entries) {
      final c = e.value;
      if (c.display.isEmpty && c.style.fillArgb == null) continue;
      if (e.key.$1 > lastRow) lastRow = e.key.$1;
      if (e.key.$2 > lastCol) lastCol = e.key.$2;
    }
    if (lastRow < 0 || lastCol < 0) continue;
    final rowsAll = <int>[
      for (var r = 0; r <= lastRow && r < _maxXlsxRows; r++)
        if ((s.rowHeightsPt[r] ?? 1) != 0) r,
    ];
    if (lastRow >= _maxXlsxRows) debugPrint('convert: sheet ${s.name} bị cắt còn $_maxXlsxRows hàng');
    final cols = <int>[
      for (var c = 0; c <= lastCol; c++)
        if ((s.columnWidthsChars[c] ?? s.defaultColumnWidthChars) != 0) c,
    ];
    final widths = <double>[
      for (final c in cols)
        (((s.columnWidthsChars[c] ?? s.defaultColumnWidthChars) * 7 + 5) * 0.75).clamp(12.0, w.contentWidth),
    ];
    final bands = partitionColumns(widths, w.contentWidth);

    // Ô gộp: neo -> vùng.
    final anchors = <(int, int), office.XlsxRange>{};
    for (final m in s.merges) {
      anchors[(m.firstRow, m.firstCol)] = m;
    }
    office.XlsxRange? mergeCovering(int r, int c) {
      for (final m in s.merges) {
        if (m.contains(r, c)) return m;
      }
      return null;
    }

    for (var bi = 0; bi < bands.length; bi++) {
      final band = bands[bi];
      w.pageBreak();
      w.paragraph(
        [StyledSpan(bands.length > 1 ? '${s.name} (${bi + 1}/${bands.length})' : s.name, bold: true)],
        fontSize: 13,
        spaceAfter: 6,
      );
      final bandCols = [for (final i in band) cols[i]];
      final bandWidths = [for (final i in band) widths[i]];
      final rows = <List<GridCell>>[];
      for (final r in rowsAll) {
        final cells = <GridCell>[];
        var k = 0;
        while (k < bandCols.length) {
          final c = bandCols[k];
          final cell = s.cell(r, c);
          final m = s.merges.isEmpty ? null : mergeCovering(r, c);
          var span = 1;
          var covered = false;
          var source = cell;
          if (m != null) {
            if (m.firstRow == r && m.firstCol == c) {
              while (k + span < bandCols.length && bandCols[k + span] <= m.lastCol) {
                span++;
              }
            } else {
              covered = true;
              if (m.firstRow == r) {
                // phần còn lại của vùng gộp trong cùng hàng đã thuộc ô neo (nếu neo cùng dải)
                if (bandCols.contains(m.firstCol)) {
                  k++;
                  continue;
                }
              }
              source = null;
            }
          }
          final st = source?.style;
          final text = normalizeForPdf(source?.display ?? '');
          final numeric = source != null &&
              (source.type == office.XlsxCellType.number ||
                  source.type == office.XlsxCellType.date ||
                  source.type == office.XlsxCellType.boolean);
          final align = switch (st?.hAlign) {
            office.XlsxHAlign.center || office.XlsxHAlign.centerContinuous => FlowAlign.center,
            office.XlsxHAlign.right => FlowAlign.right,
            office.XlsxHAlign.left => FlowAlign.left,
            _ => numeric ? FlowAlign.right : FlowAlign.left,
          };
          cells.add(GridCell(
            covered || text.isEmpty
                ? const []
                : [
                    StyledSpan(
                      text,
                      bold: st?.bold ?? false,
                      italic: st?.italic ?? false,
                      underline: st?.underline ?? false,
                      strike: st?.strike ?? false,
                      size: st?.fontSizePt ?? cellSize,
                      colorArgb: st?.fontColorArgb,
                    ),
                  ],
            colSpan: span,
            covered: covered,
            fillArgb: st?.fillArgb,
            align: align,
            wrap: st?.wrap ?? false,
            borderArgb: (st?.hasBorder ?? false) ? 0xFF000000 : 0xFFC8C8C8,
          ));
          k += span;
        }
        rows.add(cells);
      }
      // Chiều cao tối thiểu theo từng hàng: vẽ theo từng nhóm hàng cùng chiều cao.
      var idx = 0;
      while (idx < rows.length) {
        final r = rowsAll[idx];
        final h = (s.rowHeightsPt[r] ?? s.defaultRowHeightPt).toDouble();
        var j = idx + 1;
        while (j < rows.length &&
            ((s.rowHeightsPt[rowsAll[j]] ?? s.defaultRowHeightPt).toDouble()) == h) {
          j++;
        }
        w.table(
          colWidths: bandWidths,
          rows: rows.sublist(idx, j),
          fontSize: cellSize,
          padding: 2,
          minRowHeight: h.clamp(8.0, 400.0),
        );
        idx = j;
      }
    }
    report?.call((si + 1) / sheets.length);
  }
  final pages = w.pageCount;
  report?.call(1);
  return PdfBuildResult(w.finish(), pages);
}

/// Hệ chữ có trong [text] (để chọn font cần nạp).
Set<ScriptFace> facesFor(String text) => scriptsIn(text);
