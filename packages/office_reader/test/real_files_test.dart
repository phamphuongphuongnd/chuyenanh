// Tests against files produced by real Microsoft Word / Excel
// (see tool/make_real_fixtures.ps1). Values are asserted exactly.
import 'dart:io';

import 'package:office_reader/office_reader.dart';
import 'package:office_reader/src/xlsx/xlsx_reader.dart' show shiftFormula;
import 'package:test/test.dart';

const _dir = 'test/fixtures/real';

DocxDocument _loadDocx(String name) =>
    readDocx(File('$_dir/$name').readAsBytesSync());
XlsxWorkbook _loadXlsx(String name) =>
    readXlsx(File('$_dir/$name').readAsBytesSync());

Iterable<DocxParagraph> _allParagraphs(Iterable<DocxBlock> blocks) sync* {
  for (final b in blocks) {
    switch (b) {
      case DocxParagraph p:
        yield p;
      case DocxTable t:
        for (final r in t.rows) {
          for (final c in r.cells) {
            yield* _allParagraphs(c.blocks);
          }
        }
      case DocxPageBreak():
        break;
    }
  }
}

DocxParagraph _para(DocxDocument d, String text) =>
    _allParagraphs(d.blocks).firstWhere(
      (p) => p.plainText == text,
      orElse: () => fail('No paragraph "$text"'),
    );

DocxRun _run(DocxParagraph p, String text) => p.inlines
    .whereType<DocxRun>()
    .firstWhere((r) => r.text == text, orElse: () => fail('No run "$text"'));

void main() {
  group('word_full.docx (Microsoft Word)', () {
    late DocxDocument d;
    setUpAll(() => d = _loadDocx('word_full.docx'));

    test('headings 1-3 from built-in styles', () {
      expect(_para(d, 'Heading Mot').headingLevel, 1);
      expect(_para(d, 'Heading Hai').headingLevel, 2);
      expect(_para(d, 'Heading Ba').headingLevel, 3);
      expect(_para(d, 'Heading Mot').styleId, 'Heading1');
      // Heading sizes come from the style (theme: Calibri Light, 20/16/14).
      expect(_run(_para(d, 'Heading Mot'), 'Heading Mot').fontSizePt, 20);
      expect(_run(_para(d, 'Heading Hai'), 'Heading Hai').fontSizePt, 16);
      expect(
        _para(d, 'Thuong Dam Nghieng GachChan MauDo Co20').headingLevel,
        isNull,
      );
    });

    test('character formatting per run', () {
      final p = _para(d, 'Thuong Dam Nghieng GachChan MauDo Co20');
      final plain = _run(p, 'Thuong ');
      expect(
        [plain.bold, plain.italic, plain.underline, plain.colorArgb],
        [false, false, false, null],
      );
      expect(plain.fontSizePt, 12);
      expect(plain.fontFamily, 'Calibri');
      expect(_run(p, 'Dam').bold, isTrue);
      expect(_run(p, 'Dam').italic, isFalse);
      expect(_run(p, 'Nghieng').italic, isTrue);
      expect(_run(p, 'Nghieng').bold, isFalse);
      expect(_run(p, 'GachChan').underline, isTrue);
      expect(_run(p, 'MauDo').colorArgb, 0xFFFF0000);
      expect(_run(p, 'Co20').fontSizePt, 20);
    });

    test('Vietnamese stacked diacritics and Chinese survive', () {
      final vi = _para(d, 'Tiếng Việt: mặt đỗ ngữ cẫn mật ương');
      expect(vi.inlines, hasLength(1));
      final zh = _allParagraphs(
        d.blocks,
      ).firstWhere((p) => p.plainText.contains('你好'));
      expect(zh.plainText, '你好，世界 中文测试');
    });

    test('bullet and numbered lists, several levels', () {
      final a = _para(d, 'Bullet A');
      expect(a.listLevel, 0);
      expect(a.listOrdered, isFalse);
      expect(a.listLabel, '•');
      expect(a.indentLeftPt, 18);
      final a1 = _para(d, 'Bullet A1');
      expect(a1.listLabel, '•');
      expect(a1.indentLeftPt, 36);
      expect(_para(d, 'Bullet B').listLabel, '•');

      expect(_para(d, 'Number Mot').listLabel, '1.');
      expect(_para(d, 'Number Mot').listOrdered, isTrue);
      expect(_para(d, 'Number Hai').listLabel, '2.');
      expect(_para(d, 'Number Mot-a').listLabel, '1.');
      expect(_para(d, 'Number Mot-a').indentLeftPt, 36);

      // Outline numbering 1) / a) / i) applied with a list template.
      final l1 = _para(d, 'Outline L1');
      expect((l1.listLevel, l1.listLabel, l1.listOrdered), (0, '1)', true));
      final l2 = _para(d, 'Outline L2');
      expect((l2.listLevel, l2.listLabel), (1, 'a)'));
      final l3 = _para(d, 'Outline L3');
      expect((l3.listLevel, l3.listLabel), (2, 'i)'));
      expect(_para(d, 'Outline L1 b').listLabel, '2)');
      expect(_para(d, 'Heading Mot').listLevel, isNull);
    });

    test('table 4x3 with horizontal + vertical merge and shading', () {
      final t = d.blocks.whereType<DocxTable>().single;
      expect(t.rows, hasLength(4));
      expect(t.columnWidthsTwips, hasLength(3));
      expect(t.bordered, isTrue);

      final r0 = t.rows[0].cells;
      expect(r0, hasLength(2));
      expect(r0[0].gridSpan, 2);
      expect(r0[0].shadingArgb, 0xFFFFFF00);
      expect(r0[0].widthTwips, t.columnWidthsTwips[0] + t.columnWidthsTwips[1]);
      expect((r0[0].blocks.single as DocxParagraph).plainText, 'Gop ngang');
      expect((r0[1].blocks.single as DocxParagraph).plainText, 'R1C3');

      final r1 = t.rows[1].cells;
      expect(r1, hasLength(3));
      expect(r1[2].rowSpan, 2);
      expect(r1[2].vMergeContinue, isFalse);
      expect((r1[2].blocks.single as DocxParagraph).plainText, 'Gop doc');

      final r2 = t.rows[2].cells;
      expect(r2, hasLength(3));
      expect(r2[2].vMergeContinue, isTrue);
      expect(r2[2].rowSpan, 1);

      final r3 = t.rows[3].cells;
      expect(r3[1].shadingArgb, 0xFFADD8E6);
      expect(r3[0].shadingArgb, isNull);
      expect(
        [for (final c in r3) (c.blocks.single as DocxParagraph).plainText],
        ['R4C1', 'R4C2', 'R4C3'],
      );
    });

    test('inline PNG image with real bytes and size', () {
      final p = _para(d, 'Anh: ');
      final img = p.inlines.whereType<DocxImage>().single;
      expect(img.extension, 'png');
      expect(img.bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      // 48x32 px at 96 dpi = 36x24 pt.
      expect(img.widthPt, closeTo(36, 0.1));
      expect(img.heightPt, closeTo(24, 0.1));
      expect(img.floating, isFalse);
    });

    test('hyperlink keeps URL and visible text', () {
      final p = _para(d, 'Link: Example link');
      final r = _run(p, 'Example link');
      expect(r.hyperlink, 'https://example.com/test');
      expect(_run(p, 'Link: ').hyperlink, isNull);
    });

    test('explicit page break becomes a block between the two paragraphs', () {
      final i = d.blocks.indexWhere(
        (b) => b is DocxParagraph && b.plainText == 'Truoc ngat trang',
      );
      expect(i, greaterThan(0));
      expect(d.blocks[i + 1], isA<DocxPageBreak>());
      expect((d.blocks[i + 2] as DocxParagraph).plainText, 'Sau ngat trang');
    });

    test('header, footer, footnote and textbox text are not in the body', () {
      final all = _allParagraphs(d.blocks).map((p) => p.plainText).join('|');
      expect(all, isNot(contains('Header')));
      expect(all, isNot(contains('Footer')));
      expect(all, isNot(contains('Noi dung footnote')));
      expect(all, isNot(contains('Noi dung textbox')));
      // Footnote reference mark does not leak into the text.
      expect(_para(d, 'Co chu thich').inlines, hasLength(1));
      expect(_para(d, 'Doan chua textbox').inlines, hasLength(1));
    });

    test('page setup is that of the last section: Letter landscape', () {
      expect(d.page.widthTwips, 15840);
      expect(d.page.heightTwips, 12240);
      expect(_para(d, 'Section hai Letter ngang'), isNotNull);
    });
  });

  group('excel_full.xlsx (Microsoft Excel)', () {
    late XlsxWorkbook wb;
    setUpAll(() => wb = _loadXlsx('excel_full.xlsx'));

    test('sheet order, names (Unicode) and hidden flag', () {
      expect(wb.sheets.map((s) => s.name), ['Dữ liệu', 'Cong thuc', 'An']);
      expect(wb.sheets.map((s) => s.hidden), [false, false, true]);
      expect(wb.date1904, isFalse);
    });

    test('numbers, percent, currency', () {
      final s = wb.sheets[0];
      expect(s.cell(1, 1)!.display, '1234');
      expect(s.cell(1, 1)!.raw, 1234.0);
      expect(s.cell(1, 1)!.type, XlsxCellType.number);
      expect(s.cell(2, 1)!.display, '3.14');
      expect(s.cell(2, 1)!.raw, 3.14159);
      expect(s.cell(3, 1)!.display, '25.6%');
      expect(s.cell(4, 1)!.display, r'$1,234,567.50');
      expect(s.cell(5, 1)!.display, '1,500,000 ₫');
    });

    test('dates and times in several formats', () {
      final s = wb.sheets[0];
      final date = DateTime.utc(2025, 12, 9);
      expect(s.cell(6, 1)!.display, '09/12/2025');
      expect(s.cell(6, 1)!.type, XlsxCellType.date);
      expect(s.cell(6, 1)!.raw, date);
      expect(s.cell(7, 1)!.display, '2025-12-09');
      expect(s.cell(8, 1)!.display, '9 Dec 2025');
      expect(s.cell(9, 1)!.display, '18:00');
      expect(s.cell(10, 1)!.display, '12:30:00 PM');
      expect(s.cell(11, 1)!.display, '09/12/2025 12:00');
      expect(s.cell(11, 1)!.raw, DateTime.utc(2025, 12, 9, 12));
    });

    test('Vietnamese and Chinese strings, header style', () {
      final s = wb.sheets[0];
      expect(s.cell(12, 0)!.display, 'Tiếng Việt: đặc biệt, mặt ự');
      expect(s.cell(12, 1)!.display, '你好');
      expect(s.cell(12, 1)!.type, XlsxCellType.string);
      final h = s.cell(0, 0)!;
      expect(h.display, 'Loai');
      expect(h.style.bold, isTrue);
      expect(h.style.fillArgb, 0xFFFFC000);
      expect(h.style.hAlign, XlsxHAlign.center);
      expect(s.cell(1, 0)!.style.bold, isFalse);
      expect(s.cell(1, 0)!.style.fillArgb, isNull);
      expect(s.maxRow, 13);
      expect(s.maxCol, 3);
    });

    test('formulas keep cached value and formula text; error cell', () {
      final s = wb.sheets[1];
      expect(s.cell(4, 0)!.display, '100');
      expect(s.cell(4, 0)!.raw, 100.0);
      expect(s.cell(4, 0)!.formula, 'SUM(A1:A4)');
      expect(s.cell(0, 1)!.display, 'Lon');
      expect(s.cell(0, 1)!.formula, 'IF(A5>50,"Lon","Nho")');
      final e = s.cell(1, 1)!;
      expect(e.type, XlsxCellType.error);
      expect(e.display, '#DIV/0!');
    });

    test('merge, style, wrap, widths, heights, freeze panes', () {
      final s = wb.sheets[1];
      expect(s.merges, hasLength(1));
      final m = s.merges.single;
      expect([m.firstRow, m.firstCol, m.lastRow, m.lastCol], [0, 3, 1, 5]);
      final c = s.cell(0, 3)!;
      expect(c.display, 'Gop o');
      expect(c.style.bold, isTrue);
      expect(c.style.fillArgb, 0xFF00B050);
      expect(c.style.hAlign, XlsxHAlign.center);
      expect(c.style.vAlign, XlsxVAlign.center);
      expect(s.cell(6, 0)!.style.wrap, isTrue);
      expect(s.cell(0, 0)!.style.wrap, isFalse);

      final i = s.cell(8, 0)!.style;
      expect(
        [i.italic, i.underline, i.fontSizePt, i.fontColorArgb],
        [true, true, 14.0, 0xFFFF0000],
      );

      // Excel stores width + 5px padding: 20 -> 20.7773..., 5 -> 5.7773...
      expect(s.columnWidthsChars[0], closeTo(20.78, 0.01));
      expect(s.columnWidthsChars[1], closeTo(5.78, 0.01));
      expect(s.rowHeightsPt[2], closeTo(40, 0.1));
      expect(s.frozenRows, 1);
      expect(s.frozenCols, 1);
      expect(wb.sheets[0].frozenRows, 0);
    });

    test('hidden sheet is still readable', () {
      expect(wb.sheets[2].cell(0, 0)!.display, 'bi mat');
    });
  });

  group('word_extra.docx (Microsoft Word, harder features)', () {
    late DocxDocument d;
    setUpAll(() => d = _loadDocx('word_extra.docx'));

    test('alignment, indents, spacing, line spacing', () {
      expect(_para(d, 'AlignCenter').align, DocxAlign.center);
      expect(_para(d, 'AlignRight').align, DocxAlign.right);
      final j = _allParagraphs(
        d.blocks,
      ).firstWhere((p) => p.plainText.startsWith('AlignJustify'));
      expect(j.align, DocxAlign.justify);
      final p = _para(d, 'IndentSpacing');
      expect(p.indentLeftPt, 36);
      expect(p.indentRightPt, 10);
      expect(p.firstLineIndentPt, 18);
      expect(p.spaceBeforePt, 6);
      expect(p.spaceAfterPt, 12);
      expect(p.lineSpacing, closeTo(1.5, 0.001));
    });

    test('strike, super/subscript, highlight, font, caps, hidden', () {
      final p = _allParagraphs(
        d.blocks,
      ).firstWhere((p) => p.plainText.contains('Strike'));
      expect(_run(p, 'Strike').strike, isTrue);
      expect(_run(p, 'Sup').superscript, isTrue);
      expect(_run(p, 'Sub').subscript, isTrue);
      expect(_run(p, 'Hi').highlightArgb, 0xFFFFFF00);
      expect(_run(p, 'Times').fontFamily, 'Times New Roman');
      // w:caps / w:smallCaps: text is shown upper-case.
      expect(_run(p, 'CAPS').smallCaps, isFalse);
      expect(_run(p, 'SMALL').smallCaps, isTrue);
      // Hidden text (w:vanish) is dropped.
      expect(p.plainText, isNot(contains('Hidden')));
      expect(p.plainText, 'Strike Sup Sub Hi Times CAPS SMALL  End');
    });

    test('character styles Strong / Emphasis', () {
      final p = _para(d, 'StrongText EmphText');
      expect(_run(p, 'StrongText').bold, isTrue);
      expect(_run(p, 'StrongText').italic, isFalse);
      expect(_run(p, 'EmphText').italic, isTrue);
      expect(_run(p, 'EmphText').bold, isFalse);
    });

    test('line break, tab, XML special characters, spaces kept', () {
      final p = _para(d, 'Line1\nLine2\tAfterTab');
      expect(p.inlines.whereType<DocxBreak>(), hasLength(1));
      expect(_para(d, '  A & B < C > D "q"  '), isNotNull);
    });

    test('internal hyperlink, field result, tracked changes', () {
      expect(_run(_para(d, 'Go: Go to bm1'), 'Go to bm1').hyperlink, '#bm1');
      expect(_para(d, 'Page: 1'), isNotNull);
      // Insertion kept, deletion dropped.
      expect(_para(d, 'Rev: keepNEW'), isNotNull);
      // Content control text and comment-anchored text; comment body absent.
      expect(_para(d, 'CC: cc value'), isNotNull);
      expect(_para(d, 'Commented text'), isNotNull);
      final all = _allParagraphs(d.blocks).map((p) => p.plainText).join('|');
      expect(all, isNot(contains('a comment')));
    });

    test('pageBreakBefore flag', () {
      expect(_para(d, 'Starts new page').pageBreakBefore, isTrue);
      expect(_para(d, 'Table below').pageBreakBefore, isFalse);
    });

    test('table: header row, row height, nested table', () {
      final t = d.blocks.whereType<DocxTable>().single;
      expect(t.columnWidthsTwips, [2000, 4680]);
      expect(t.bordered, isTrue);
      expect(t.rows[0].isHeader, isTrue);
      expect(t.rows[1].isHeader, isFalse);
      expect(t.rows[2].heightTwips, 800);
      final nested = t.rows[1].cells[0].blocks.whereType<DocxTable>().single;
      expect(nested.bordered, isTrue);
      expect(nested.columnWidthsTwips, [892, 892]);
      expect(
        [
          for (final c in nested.rows.single.cells)
            (c.blocks.single as DocxParagraph).plainText,
        ],
        ['in21', 'in22'],
      );
      expect(_para(d, 'R2C2'), isNotNull);
    });

    test('floating (anchored) image', () {
      final img = _para(d, 'Float: ').inlines.whereType<DocxImage>().single;
      expect(img.floating, isTrue);
      expect(img.extension, 'png');
      expect(img.widthPt, closeTo(30, 0.1));
      expect(img.heightPt, closeTo(30, 0.1));
    });

    test('page setup default template is Letter portrait', () {
      expect((d.page.widthTwips, d.page.heightTwips), (12240, 15840));
    });
  });

  group('excel_extra.xlsx (Microsoft Excel, harder features)', () {
    late XlsxWorkbook wb;
    setUpAll(() => wb = _loadXlsx('excel_extra.xlsx'));
    String disp(XlsxSheet s, int row) => s.cell(row, 1)!.display;

    test('General and custom number formats', () {
      final s = wb.sheets[0];
      expect(s.name, 'Formats');
      expect(disp(s, 0), '1234.5678');
      expect(disp(s, 1), '0.3'); // 0.30000000000000004
      expect(s.cell(1, 1)!.raw, 0.30000000000000004);
      expect(disp(s, 2), '0.333333333');
      expect(disp(s, 3), '1.23457E+13');
      expect(disp(s, 4), '0.000012345');
      expect(disp(s, 5), '-42');
      expect(disp(s, 6), '1.23E+03');
      expect(disp(s, 7), '3/4');
      expect(disp(s, 8), '-1,235');
      expect(disp(s, 9).trim(), r'$1,234.50');
      expect(disp(s, 10), '50%');
      expect(disp(s, 11), 'December 9, 2025');
      expect(disp(s, 12), 'Tuesday');
      expect(disp(s, 13), '36:00:00');
      expect(disp(s, 15), '1,234,567');
      expect(disp(s, 16), '5.6%');
      expect(disp(s, 17), '005');
      expect(disp(s, 18), '1,234.50');
      expect(disp(s, 19), 'zero');
    });

    test('built-in date format id 14 follows documented d/m/yyyy', () {
      expect(disp(wb.sheets[0], 14), '9/12/2025');
      expect(wb.sheets[0].cell(14, 1)!.type, XlsxCellType.date);
    });

    test('boolean, newline, text-number, spaces, 1900 leap quirk', () {
      final s = wb.sheets[0];
      expect(s.cell(20, 1)!.type, XlsxCellType.boolean);
      expect(s.cell(20, 1)!.raw, true);
      expect(s.cell(20, 1)!.display, 'TRUE');
      expect(s.cell(21, 1)!.display, 'dong1\ndong2');
      expect(s.cell(21, 1)!.style.wrap, isTrue);
      expect(s.cell(22, 1)!.display, '00123');
      expect(s.cell(22, 1)!.type, XlsxCellType.string);
      expect(s.cell(23, 1)!.display, '  lead & trail <x>  ');
      expect(s.cell(26, 1)!.display, '1900-03-01'); // serial 61
    });

    test('rich text concatenated, hyperlink cell text, styles', () {
      final s = wb.sheets[0];
      expect(s.cell(24, 1)!.display, 'BoldNormal');
      expect(s.cell(25, 1)!.display, 'Click');
      expect(s.cell(27, 1)!.style.hasBorder, isTrue);
      expect(s.cell(28, 1)!.style.hAlign, XlsxHAlign.left);
      expect(s.cell(28, 1)!.style.indent, 2);
      expect(s.cell(29, 1)!.style.strike, isTrue);
      expect(s.cell(30, 1)!.style.fillArgb, 0xFF4472C4); // theme accent1
      expect(s.cell(31, 1)!.style.fillArgb, 0xFFB4C7E7); // accent1 tint 0.6
      expect(s.cell(32, 1)!.style.fontFamily, 'Arial');
      expect(s.cell(32, 1)!.style.fontSizePt, 12);
      expect(s.cell(33, 1)!.display, 'has note'); // comment ignored
    });

    test('shared / array formulas and formula result types', () {
      final s = wb.sheets[1];
      expect(s.name, 'Formulas');
      for (var r = 0; r < 5; r++) {
        expect(s.cell(r, 1)!.raw, (r + 1) * 2.0);
        expect(s.cell(r, 1)!.formula, 'A${r + 1}*2', reason: 'row ${r + 1}');
      }
      expect(s.cell(0, 2)!.type, XlsxCellType.boolean);
      expect(s.cell(0, 2)!.display, 'FALSE');
      expect(s.cell(1, 2)!.display, 'x2');
      expect(s.cell(1, 2)!.formula, '"x"&A2');
      expect(s.cell(2, 2)!.display, '09/12/2025');
      expect(s.cell(2, 2)!.type, XlsxCellType.string);
      expect(s.cell(3, 2)!.display, '#DIV/0!');
      expect(s.cell(4, 2)!.display, '#N/A');
      expect(s.cell(4, 2)!.type, XlsxCellType.error);
      expect(s.cell(0, 4)!.raw, 10.0);
      expect(s.cell(1, 4)!.raw, 20.0);
    });

    test('column ranges, hidden column and row', () {
      final s = wb.sheets[1];
      for (final c in [6, 7, 8]) {
        expect(s.columnWidthsChars[c], closeTo(12.78, 0.01), reason: 'col $c');
      }
      expect(s.columnWidthsChars[9], 0);
      expect(s.cell(0, 10)!.display, 'after hidden col');
      expect(s.rowHeightsPt[6], 0);
      expect(s.cell(6, 0)!.display, 'hidden row');
      expect(s.maxRow, 8);
      expect(s.maxCol, 11);
    });

    test('sheet with a table (ListObject) and a far-away cell', () {
      final s = wb.sheets[2];
      expect(s.name, 'Table');
      expect(s.cell(2, 0)!.display, 'pear');
      expect(s.cell(2, 1)!.raw, 5.0);
      expect(s.cell(4, 3)!.display, 'far away');
      expect((s.maxRow, s.maxCol), (5, 4));
    });

    test('date1904 workbook', () {
      final w = _loadXlsx('excel_1904.xlsx');
      expect(w.date1904, isTrue);
      final c = w.sheets.single.cell(0, 0)!;
      expect(c.raw, DateTime.utc(2025, 12, 9));
      expect(c.display, '2025-12-09');
    });
  });

  group('shiftFormula', () {
    test('relative, absolute, strings and sheet names', () {
      expect(shiftFormula('A1*2', 2, 0), 'A3*2');
      expect(shiftFormula(r'$A1+B$2', 1, 1), r'$A2+C$2');
      expect(shiftFormula('SUM(A1:B2)', 0, 1), 'SUM(B1:C2)');
      expect(shiftFormula('"A1"&A1', 1, 0), '"A1"&A2');
      expect(
        shiftFormula("'Sheet A1'!A1+LOG10(A1)", 1, 0),
        "'Sheet A1'!A2+LOG10(A2)",
      );
      expect(shiftFormula('Data!B2', 1, 0), 'Data!B3');
      expect(shiftFormula('A1', 0, 0), 'A1');
      expect(shiftFormula('Z1', 0, 1), 'AA1');
    });
  });
}
