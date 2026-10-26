import 'dart:typed_data';

import 'package:office_reader/office_reader.dart';
import 'package:test/test.dart';

import 'helpers/ooxml.dart';

const _styles = '''
<numFmts count="6">
  <numFmt numFmtId="164" formatCode="0.0%"/>
  <numFmt numFmtId="165" formatCode="yyyy-mm-dd"/>
  <numFmt numFmtId="166" formatCode="d/m/yyyy"/>
  <numFmt numFmtId="167" formatCode="hh:mm:ss"/>
  <numFmt numFmtId="168" formatCode="#,##0.000"/>
  <numFmt numFmtId="169" formatCode="dd/mm/yyyy\\ hh:mm"/>
</numFmts>
<fonts count="3">
  <font><sz val="11"/><color theme="1"/><name val="Calibri"/></font>
  <font><b/><sz val="14"/><color rgb="FFFF0000"/><name val="Arial"/></font>
  <font><i/><u/><sz val="11"/><color indexed="12"/><name val="Calibri"/></font>
</fonts>
<fills count="3">
  <fill><patternFill patternType="none"/></fill>
  <fill><patternFill patternType="gray125"/></fill>
  <fill><patternFill patternType="solid"><fgColor rgb="FFFFFF00"/><bgColor indexed="64"/></patternFill></fill>
</fills>
<borders count="2">
  <border><left/><right/><top/><bottom/><diagonal/></border>
  <border><left style="thin"><color indexed="64"/></left><right style="thin"/><top style="thin"/><bottom style="thin"/><diagonal/></border>
</borders>
<cellXfs count="13">
  <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
  <xf numFmtId="0" fontId="1" fillId="2" borderId="1" applyFont="1" applyFill="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>
  <xf numFmtId="10" fontId="0" fillId="0" borderId="0" applyNumberFormat="1"/>
  <xf numFmtId="164" fontId="0" fillId="0" borderId="0" applyNumberFormat="1"/>
  <xf numFmtId="165" fontId="0" fillId="0" borderId="0" applyNumberFormat="1"/>
  <xf numFmtId="166" fontId="0" fillId="0" borderId="0" applyNumberFormat="1"/>
  <xf numFmtId="167" fontId="0" fillId="0" borderId="0" applyNumberFormat="1"/>
  <xf numFmtId="4" fontId="0" fillId="0" borderId="0" applyNumberFormat="1"/>
  <xf numFmtId="14" fontId="0" fillId="0" borderId="0" applyNumberFormat="1"/>
  <xf numFmtId="168" fontId="0" fillId="0" borderId="0" applyNumberFormat="1"/>
  <xf numFmtId="2" fontId="0" fillId="0" borderId="0" applyNumberFormat="1"/>
  <xf numFmtId="0" fontId="2" fillId="0" borderId="0" applyFont="1"><alignment horizontal="right" vertical="top"/></xf>
  <xf numFmtId="169" fontId="0" fillId="0" borderId="0" applyNumberFormat="1"/>
</cellXfs>
''';

const _shared = '''
<si><t>Hello</t></si>
<si><r><rPr><b/></rPr><t>Bold</t></r><r><t xml:space="preserve"> normal</t></r></si>
<si><t>漢字</t><rPh sb="0" eb="2"><t>かんじ</t></rPh></si>
<si><t>Xin chào thế giới ภาษาไทย</t></si>
''';

String _c(String ref, String v, {String? t, int? s, String? f}) {
  final ta = t == null ? '' : ' t="$t"';
  final sa = s == null ? '' : ' s="$s"';
  final fe = f == null ? '' : '<f>$f</f>';
  return '<c r="$ref"$ta$sa>$fe<v>$v</v></c>';
}

Uint8List _workbook() {
  final data =
      '<sheetViews><sheetView workbookViewId="0">'
      '<pane xSplit="1" ySplit="2" topLeftCell="B3" activePane="bottomRight" state="frozen"/>'
      '</sheetView></sheetViews>'
      '<sheetFormatPr defaultRowHeight="15"/>'
      '<cols><col min="1" max="2" width="20.5" customWidth="1"/>'
      '<col min="3" max="3" width="5" hidden="1" customWidth="1"/></cols>'
      '<sheetData>'
      '<row r="1" ht="30" customHeight="1">'
      '${_c('A1', '0', t: 's', s: 1)}${_c('B1', '1', t: 's')}${_c('C1', '2', t: 's')}'
      '<c r="D1" t="inlineStr"><is><t>inline</t></is></c>'
      '${_c('E1', '3', t: 's', s: 11)}'
      '</row>'
      '<row r="2">'
      '${_c('A2', '1234.5', s: 7)}${_c('B2', '-1234.5', s: 7)}${_c('C2', '0.1234', s: 2)}'
      '${_c('D2', '0.1234', s: 3)}${_c('E2', '1234.5', s: 9)}${_c('F2', '2.5', s: 10)}'
      '</row>'
      '<row r="3">'
      '${_c('A3', '45000', s: 4)}${_c('B3', '45000', s: 5)}${_c('C3', '0.520833333333333', s: 6)}'
      '${_c('D3', '61', s: 4)}${_c('E3', '1', s: 4)}${_c('F3', '45000', s: 8)}${_c('G3', '45000.75', s: 12)}'
      '</row>'
      '<row r="4">'
      '${_c('A4', '3')}${_c('B4', '0.30000000000000004')}${_c('C4', '1234567.891')}'
      '${_c('D4', '0.333333333333333')}${_c('E4', '1', t: 'b')}${_c('F4', '#DIV/0!', t: 'e')}'
      '${_c('G4', '3', f: 'SUM(A4,0)')}${_c('H4', 'hix', t: 'str', f: 'A1&amp;"x"')}'
      '<c r="I4" s="1"/>'
      '</row>'
      '<row r="5"><c><v>1</v></c><c><v>2</v></c></row>'
      '<row><c><v>9</v></c></row>'
      '</sheetData>'
      '<mergeCells count="1"><mergeCell ref="A1:B2"/></mergeCells>';
  return buildXlsx(
    styles: _styles,
    sharedStrings: _shared,
    sheets: [
      SheetSpec('Data', data),
      const SheetSpec(
        'Ẩn',
        '<sheetData><row r="1"><c r="A1"><v>1</v></c></row></sheetData>',
        state: 'hidden',
      ),
      const SheetSpec('Third', '<sheetData/>'),
    ],
  );
}

void main() {
  late XlsxWorkbook wb;
  late XlsxSheet sh;
  setUpAll(() {
    wb = readXlsx(_workbook());
    sh = wb.sheets.first;
  });
  String d(int r, int c) => sh.cells[(r, c)]!.display;

  test('sheets keep workbook order, names and hidden state', () {
    expect(wb.sheets.map((s) => s.name).toList(), ['Data', 'Ẩn', 'Third']);
    expect(wb.sheets.map((s) => s.hidden).toList(), [false, true, false]);
    expect(wb.sheets[1].cells[(0, 0)]!.display, '1');
    expect(wb.sheets[2].cells, isEmpty);
    expect(wb.sheets[2].maxRow, 0);
  });

  test('shared, rich, phonetic and inline strings', () {
    expect(d(0, 0), 'Hello');
    expect(d(0, 1), 'Bold normal');
    expect(d(0, 2), '漢字');
    expect(d(0, 3), 'inline');
    expect(d(0, 4), 'Xin chào thế giới ภาษาไทย');
    expect(sh.cells[(0, 0)]!.type, XlsxCellType.string);
    expect(sh.cells[(0, 0)]!.raw, 'Hello');
  });

  test('number and percent formats', () {
    expect(d(1, 0), '1,234.50');
    expect(d(1, 1), '-1,234.50');
    expect(d(1, 2), '12.34%');
    expect(d(1, 3), '12.3%');
    expect(d(1, 4), '1,234.500');
    expect(d(1, 5), '2.50');
    expect(sh.cells[(1, 0)]!.type, XlsxCellType.number);
    expect(sh.cells[(1, 0)]!.raw, 1234.5);
  });

  test('date and time formats with 1900 serials', () {
    expect(d(2, 0), '2023-03-15');
    expect(d(2, 1), '15/3/2023');
    expect(d(2, 2), '12:30:00');
    expect(d(2, 3), '1900-03-01', reason: 'serial 61 after fake 29 Feb');
    expect(d(2, 4), '1900-01-01');
    expect(d(2, 5), '15/3/2023', reason: 'built-in 14 as d/m/yyyy');
    expect(d(2, 6), '15/03/2023 18:00');
    final c = sh.cells[(2, 0)]!;
    expect(c.type, XlsxCellType.date);
    expect(c.raw, DateTime.utc(2023, 3, 15));
  });

  test('general, bool, error and formulas use cached value', () {
    expect(d(3, 0), '3');
    expect(d(3, 1), '0.3');
    expect(d(3, 2), '1234567.891');
    expect(d(3, 3), '0.333333333');
    expect(d(3, 4), 'TRUE');
    expect(sh.cells[(3, 4)]!.type, XlsxCellType.boolean);
    expect(sh.cells[(3, 4)]!.raw, true);
    expect(d(3, 5), '#DIV/0!');
    expect(sh.cells[(3, 5)]!.type, XlsxCellType.error);
    expect(d(3, 6), '3');
    expect(sh.cells[(3, 6)]!.formula, 'SUM(A4,0)');
    expect(d(3, 7), 'hix');
    expect(sh.cells[(3, 7)]!.type, XlsxCellType.string);
    expect(sh.cells[(3, 7)]!.formula, 'A1&"x"');
    final blank = sh.cells[(3, 8)]!;
    expect(blank.type, XlsxCellType.blank);
    expect(blank.display, '');
    expect(blank.style.fillArgb, 0xFFFFFF00);
  });

  test('cells without r attribute are positional', () {
    expect(d(4, 0), '1');
    expect(d(4, 1), '2');
    expect(d(5, 0), '9');
    expect(sh.maxRow, 6);
    expect(sh.maxCol, 9);
  });

  test('styles: font, fill, border, alignment', () {
    final s = sh.cells[(0, 0)]!.style;
    expect(s.bold, isTrue);
    expect(s.fontSizePt, 14);
    expect(s.fontColorArgb, 0xFFFF0000);
    expect(s.fontFamily, 'Arial');
    expect(s.fillArgb, 0xFFFFFF00);
    expect(s.hasBorder, isTrue);
    expect(s.hAlign, XlsxHAlign.center);
    expect(s.vAlign, XlsxVAlign.center);
    expect(s.wrap, isTrue);

    final plain = sh.cells[(0, 1)]!.style;
    expect(plain.bold, isFalse);
    expect(plain.fillArgb, isNull);
    expect(plain.hasBorder, isFalse);
    expect(plain.hAlign, XlsxHAlign.general);
    expect(plain.vAlign, XlsxVAlign.bottom);
    expect(plain.fontSizePt, 11);

    final it = sh.cells[(0, 4)]!.style;
    expect(it.italic, isTrue);
    expect(it.underline, isTrue);
    expect(it.fontColorArgb, 0xFF0000FF, reason: 'indexed 12 = blue');
    expect(it.hAlign, XlsxHAlign.right);
    expect(it.vAlign, XlsxVAlign.top);
  });

  test('merges, columns, rows, frozen panes', () {
    expect(sh.merges, hasLength(1));
    final m = sh.merges.single;
    expect([m.firstRow, m.firstCol, m.lastRow, m.lastCol], [0, 0, 1, 1]);
    expect(sh.columnWidthsChars[0], 20.5);
    expect(sh.columnWidthsChars[1], 20.5);
    expect(sh.columnWidthsChars[2], 0, reason: 'hidden column');
    expect(sh.rowHeightsPt[0], 30);
    expect(sh.rowHeightsPt.containsKey(1), isFalse);
    expect(sh.defaultRowHeightPt, 15);
    expect(sh.frozenRows, 2);
    expect(sh.frozenCols, 1);
  });

  test('date1904 workbooks', () {
    final bytes = buildXlsx(
      workbookPr: '<workbookPr date1904="1"/>',
      styles: _styles,
      sheets: [
        SheetSpec(
          'S',
          '<sheetData><row r="1">${_c('A1', '0', s: 4)}</row></sheetData>',
        ),
      ],
    );
    expect(readXlsx(bytes).sheets.single.cells[(0, 0)]!.display, '1904-01-01');
  });

  test('broken files throw OfficeFormatException', () {
    expect(
      () => readXlsx(Uint8List.fromList(List.filled(64, 7))),
      throwsA(isA<OfficeFormatException>()),
    );
    expect(
      () => readXlsx(buildZip({'x.xml': '<a/>'})),
      throwsA(isA<OfficeFormatException>()),
    );
    expect(() => readXlsx(Uint8List(0)), throwsA(isA<OfficeFormatException>()));
  });
}
