import 'package:office_reader/office_reader.dart' as rd;

import '../../../engines/office/docx_engine.dart' as eng;

/// Đổi model của `office_reader` sang model của interface `DocxEngine`
/// (dùng cho DOCX→PDF). Màn xem DOCX dùng thẳng model `office_reader` (giàu thông tin hơn).
eng.DocxDocument mapDocx(rd.DocxDocument doc) =>
    eng.DocxDocument(blocks: _mapBlocks(doc.blocks));

List<eng.DocxBlock> _mapBlocks(List<rd.DocxBlock> blocks) {
  final out = <eng.DocxBlock>[];
  for (final b in blocks) {
    switch (b) {
      case rd.DocxParagraph():
        _mapParagraph(b, out);
      case rd.DocxTable():
        out.add(_mapTable(b));
      case rd.DocxPageBreak():
        out.add(const eng.DocxPageBreak());
    }
  }
  return out;
}

eng.DocxAlignment _align(rd.DocxAlign a) => switch (a) {
  rd.DocxAlign.left => eng.DocxAlignment.left,
  rd.DocxAlign.center => eng.DocxAlignment.center,
  rd.DocxAlign.right => eng.DocxAlignment.right,
  rd.DocxAlign.justify => eng.DocxAlignment.justify,
};

/// Ảnh nằm giữa đoạn được tách thành khối ảnh riêng (engine coi ảnh là block).
void _mapParagraph(rd.DocxParagraph p, List<eng.DocxBlock> out) {
  var runs = <eng.DocxRun>[];
  var first = true;

  void flush() {
    out.add(
      eng.DocxParagraph(
        runs,
        headingLevel: first ? (p.headingLevel ?? 0) : 0,
        alignment: _align(p.align),
        listLevel: first ? p.listLevel : null,
        listOrdered: first && p.listOrdered,
        spacingAfter: p.spaceAfterPt,
      ),
    );
    runs = <eng.DocxRun>[];
    first = false;
  }

  var emittedImage = false;
  for (final i in p.inlines) {
    switch (i) {
      case rd.DocxRun():
        runs.add(
          eng.DocxRun(
            i.text,
            bold: i.bold,
            italic: i.italic,
            underline: i.underline,
            strike: i.strike,
            fontSize: i.fontSizePt,
            colorArgb: i.colorArgb,
            highlightArgb: i.highlightArgb,
          ),
        );
      case rd.DocxBreak():
        runs.add(const eng.DocxRun('\n'));
      case rd.DocxImage():
        if (runs.isNotEmpty) flush();
        out.add(
          eng.DocxImage(
            i.bytes,
            width: i.widthPt,
            height: i.heightPt,
            contentType: _contentType(i.extension),
          ),
        );
        emittedImage = true;
        first = false;
    }
  }
  if (runs.isNotEmpty || !emittedImage) flush();
}

String _contentType(String ext) => switch (ext.toLowerCase()) {
  'jpg' || 'jpeg' => 'image/jpeg',
  'svg' => 'image/svg+xml',
  'tif' || 'tiff' => 'image/tiff',
  final e => 'image/$e',
};

eng.DocxTable _mapTable(rd.DocxTable t) => eng.DocxTable(
  [
    for (final r in t.rows)
      [
        for (final c in r.cells)
          eng.DocxTableCell(
            _mapBlocks(c.blocks),
            colSpan: c.gridSpan < 1 ? 1 : c.gridSpan,
            rowSpan: c.vMergeContinue ? 0 : (c.rowSpan < 1 ? 1 : c.rowSpan),
            fillArgb: c.shadingArgb,
          ),
      ],
  ],
  columnWidths: [for (final w in t.columnWidthsTwips) w / 20],
);
