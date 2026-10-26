// Debug helper: prints the parsed model of a .docx/.xlsx file.
// Usage: dart run tool/dump.dart <file>
import 'dart:io';

import 'package:office_reader/office_reader.dart';

void blk(DocxBlock b, String ind) {
  switch (b) {
    case DocxParagraph p:
      print(
        '$ind P h=${p.headingLevel} style=${p.styleId} align=${p.align.name} '
        'list=${p.listLevel}/${p.listOrdered}/${p.listLabel} '
        'ind=${p.indentLeftPt},${p.firstLineIndentPt} '
        'sp=${p.spaceBeforePt},${p.spaceAfterPt} pbb=${p.pageBreakBefore}',
      );
      for (final i in p.inlines) {
        switch (i) {
          case DocxRun r:
            print(
              '$ind    R "${r.text.replaceAll('\n', '\\n')}" b=${r.bold} '
              'i=${r.italic} u=${r.underline} s=${r.strike} sz=${r.fontSizePt} '
              'c=${r.colorArgb?.toRadixString(16)} hl=${r.highlightArgb} '
              'f=${r.fontFamily} link=${r.hyperlink}',
            );
          case DocxBreak():
            print('$ind    BR');
          case DocxImage im:
            print(
              '$ind    IMG ${im.extension} ${im.bytes.length}B '
              '${im.widthEmu}x${im.heightEmu} float=${im.floating}',
            );
        }
      }
    case DocxPageBreak():
      print('$ind PAGEBREAK');
    case DocxTable t:
      print('$ind TABLE grid=${t.columnWidthsTwips} bordered=${t.bordered}');
      for (final r in t.rows) {
        print('$ind  ROW h=${r.heightTwips} hdr=${r.isHeader}');
        for (final c in r.cells) {
          print(
            '$ind   CELL span=${c.gridSpan} vmc=${c.vMergeContinue} '
            'rs=${c.rowSpan} shd=${c.shadingArgb?.toRadixString(16)} '
            'w=${c.widthTwips}',
          );
          for (final x in c.blocks) {
            blk(x, '$ind     ');
          }
        }
      }
  }
}

void main(List<String> a) {
  final bytes = File(a[0]).readAsBytesSync();
  if (a[0].endsWith('.docx')) {
    final d = readDocx(bytes);
    print(
      'PAGE ${d.page.widthTwips}x${d.page.heightTwips} '
      'm=${d.page.marginTopTwips},${d.page.marginRightTwips},'
      '${d.page.marginBottomTwips},${d.page.marginLeftTwips}',
    );
    for (final b in d.blocks) {
      blk(b, '');
    }
  } else {
    final w = readXlsx(bytes);
    print('date1904=${w.date1904}');
    for (final s in w.sheets) {
      print(
        'SHEET "${s.name}" hidden=${s.hidden} max=${s.maxRow}x${s.maxCol} '
        'merges=${s.merges} colW=${s.columnWidthsChars} rowH=${s.rowHeightsPt} '
        'defW=${s.defaultColumnWidthChars} defH=${s.defaultRowHeightPt} '
        'frozen=${s.frozenRows},${s.frozenCols}',
      );
      final keys = s.cells.keys.toList()
        ..sort(
          (x, y) => x.$1 != y.$1 ? x.$1.compareTo(y.$1) : x.$2.compareTo(y.$2),
        );
      for (final k in keys) {
        final c = s.cells[k]!;
        final st = c.style;
        print(
          '  ${k.$1},${k.$2} "${c.display}" raw=${c.raw} type=${c.type.name} '
          'f=${c.formula} fmt=${st.numberFormat} b=${st.bold} i=${st.italic} '
          'u=${st.underline} sz=${st.fontSizePt} '
          'fc=${st.fontColorArgb?.toRadixString(16)} '
          'fill=${st.fillArgb?.toRadixString(16)} ha=${st.hAlign.name} '
          'va=${st.vAlign.name} wrap=${st.wrap} bd=${st.hasBorder} '
          'font=${st.fontFamily}',
        );
      }
    }
  }
}
