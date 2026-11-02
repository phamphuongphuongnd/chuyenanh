// Kiểm thử hộp trắng (agent A17) cho lib/src/xlsx/xlsx_reader.dart.
// Sinh từ Bước 5 (test-output/whitebox/office-reader/xlsx_reader/buoc-5-du-lieu-thu.md).
// Expected chép từ Bước 5 — KHÔNG chỉnh cho khớp code. Tên test bắt đầu bằng mã bộ.
import 'package:office_reader/office_reader.dart';
import 'package:office_reader/src/xlsx/xlsx_reader.dart' show shiftFormula;
import 'package:test/test.dart';

import '../helpers/ooxml.dart';
Object? _run(Object? Function() f) {
  try {
    return f();
  } catch (e) {
    return e;
  }
}

const sNs = 'xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"';
String rels(String inner) => '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">$inner</Relationships>';
String rl(String id, String type, String target, {bool ext = false}) =>
    '<Relationship Id="$id" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/$type" Target="$target"${ext ? ' TargetMode="External"' : ''}/>';
const sheet1 = '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="1"><c r="A1"><v>7</v></c></row></sheetData></worksheet>';
String wbXml({String pr = '<workbookPr date1904="1"/>', String? sheets = '<sheet name="S1" sheetId="1" r:id="rId1"/>'}) =>
    '<workbook $sNs>$pr${sheets == null ? '' : '<sheets>$sheets</sheets>'}</workbook>';
/// Gói chuẩn: _rels/.rels → xl/workbook.xml, rId1 → worksheets/sheet1.xml.
Map<String, Object> pk({String root = 'xl/workbook.xml', String rootType = 'officeDocument', String? wb, String wbRels = '', String sheetRel = ''}) => {
      '_rels/.rels': rels(rl('r0', rootType, root)),
      'xl/workbook.xml': wb ?? wbXml(),
      'xl/_rels/workbook.xml.rels': rels((sheetRel.isEmpty ? rl('rId1', 'worksheet', 'worksheets/sheet1.xml') : sheetRel) + wbRels),
      'xl/worksheets/sheet1.xml': sheet1,
    };
XlsxWorkbook wbOf(Map<String, Object> parts) => readXlsx(buildZip(parts));
String sig(XlsxWorkbook w) => w.sheets.map((s) => '${s.name}:${s.hidden}:${s.cell(0, 0)?.display}').join(',') + '|${w.date1904}';
const dateStyles = '<cellXfs><xf numFmtId="0"/><xf numFmtId="14"/></cellXfs>';
XlsxCell? cell(String c, {String? ss, String? styles = dateStyles, String rows = ''}) => readXlsx(buildXlsx(
      sheets: [SheetSpec('S', '<sheetData><row r="1">$c</row>$rows</sheetData>')],
      sharedStrings: ss,
      styles: styles,
    )).sheets.single.cell(0, 0);
String? kd(XlsxCell? c) => c == null ? null : '${c.type.name}|${c.display}|${c.raw}|${c.formula}';

void main() {
  group('Đơn vị 1 — columnIndex', () {
    // Đường: D1S D2S → R1
    test('1-1 \'ab\'', () {
      final res = _run(() => columnIndex('ab'));
      expect(res, 27);
    });
    // Đường: D1Đ → R1
    test('1-2 \'A1\' (dừng ở chữ số)', () {
      final res = _run(() => columnIndex('A1'));
      expect(res, 0);
    });
    // Đường: D1S D2Đ → R1
    test('1-3 \'A[\' (dừng ở ký tự sau Z)', () {
      final res = _run(() => columnIndex('A['));
      expect(res, 0);
    });
  });
  group('Đơn vị 2 — parseCellRef', () {
    // Đường: D1S → R2
    test('2-1 \' \$C\$5 \'', () {
      final res = _run(() => parseCellRef(' \$C\$5 '));
      expect(res, equals((4, 2)));
    });
    // Đường: D1Đ → R1
    test('2-2 \'B\'', () {
      final res = _run(() => parseCellRef('B'));
      expect(res, isNull);
    });
    // Đường: D1S → R2 (bổ sung)
    test('2-b1 \'A0\' (hàng 0 không tồn tại)', () {
      final res = _run(() => parseCellRef('A0'));
      expect(res, isNull);
    });
  });
  group('Đơn vị 3 — shiftFormula', () {
    // Đường: D1S D3Đ D4S D5S D10Đ D11Đ D12Đ D10S D3S → R2
    test('3-1 shiftFormula("A1+B2", 1, 0)', () {
      final res = _run(() => shiftFormula(r'A1+B2', 1, 0));
      expect(res, r'A2+B3');
    });
    // Đường: D1Đ D2S D3Đ D4S D5S D10Đ D11Đ D12Đ D10S D3S → R2
    test('3-2 shiftFormula("A1", 0, 0)', () {
      final res = _run(() => shiftFormula(r'A1', 0, 0));
      expect(res, r'A1');
    });
    // Đường: D1S D3S → R2
    test('3-3 shiftFormula("A1+B2", 0, 1)', () {
      final res = _run(() => shiftFormula(r'A1+B2', 0, 1));
      expect(res, r'B1+C2');
    });
    // Đường: D1S D3Đ D4Đ D6Đ D7Đ D8Đ D9S D3S → R2
    test('3-4 shiftFormula("", 1, 0)', () {
      final res = _run(() => shiftFormula(r'', 1, 0));
      expect(res, r'');
    });
    // Đường: D1S D3Đ D4S D5Đ D6Đ D7Đ D8Đ D9S D3S → R2
    test('3-5 shiftFormula("\\"A1\\"&A1", 1, 0)', () {
      final res = _run(() => shiftFormula(r'"A1"&A1', 1, 0));
      expect(res, r'"A1"&A2');
    });
    // Đường: D1S D3Đ D4S D5S D10S D3S → R2
    test('3-6 shiftFormula("\'Sheet 1\'!A1", 1, 0)', () {
      final res = _run(() => shiftFormula(r"'Sheet 1'!A1", 1, 0));
      expect(res, r"'Sheet 1'!A2");
    });
    // Đường: D1S D3Đ D4S D5S D10Đ D11S D3S → R2
    test('3-7 shiftFormula("A1&\\"", 1, 0)', () {
      final res = _run(() => shiftFormula(r'A1&"', 1, 0));
      expect(res, r'A2&"');
    });
    // Đường: D1S D3Đ D4S D5S D10Đ D11Đ D12S D3S → R2
    test('3-8 shiftFormula("\\"ab\\"&A1", 1, 0)', () {
      final res = _run(() => shiftFormula(r'"ab"&A1', 1, 0));
      expect(res, r'"ab"&A2');
    });
    // Đường: D1Đ D2Đ → R1
    test('3-9 shiftFormula("A1&\\"x\\"", 1, 0)', () {
      final res = _run(() => shiftFormula(r'A1&"x"', 1, 0));
      expect(res, r'A2&"x"');
    });
    // Đường: D1S D3Đ D4Đ D6S D3S → R2
    test('3-10 shiftFormula("\\"a\\"\\"b\\"&A1", 1, 0)', () {
      final res = _run(() => shiftFormula(r'"a""b"&A1', 1, 0));
      expect(res, r'"a""b"&A2');
    });
    // Đường: D1S D3Đ D4Đ D6Đ D7S D6S D3S → R2
    test('3-11 shiftFormula("A1", 1, 0)', () {
      final res = _run(() => shiftFormula(r'A1', 1, 0));
      expect(res, r'A2');
    });
    // Đường: D1S D3Đ D4Đ D6Đ D7Đ D8S D3S → R2
    test('3-12 shiftFormula("A1&\\"x\\"&B1", 1, 0)', () {
      final res = _run(() => shiftFormula(r'A1&"x"&B1', 1, 0));
      expect(res, r'A2&"x"&B2');
    });
    // Đường: D1S D3Đ D4Đ D6Đ D7Đ D8Đ D9Đ D6S D3S → R2
    test('3-13 shiftFormula("A1+\'S\'!B1", 1, 0)', () {
      final res = _run(() => shiftFormula(r"A1+'S'!B1", 1, 0));
      expect(res, r"A2+'S'!B2");
    });
  });
  group('Đơn vị 4 — shiftFormula — lambda thay tham chiếu', () {
    // Đường: D1S D2S D3S D4S → R2
    test('4-1 shiftFormula("A1", 1, 1)', () {
      final res = _run(() => shiftFormula(r'A1', 1, 1));
      expect(res, r'B2');
    });
    // Đường: D1Đ D2S D3S D4S → R2
    test('4-2 shiftFormula("\$A1", 1, 1)', () {
      final res = _run(() => shiftFormula(r'$A1', 1, 1));
      expect(res, r'$A2');
    });
    // Đường: D1S D2Đ D3S D4S → R2
    test('4-3 shiftFormula("A\$1", 1, 1)', () {
      final res = _run(() => shiftFormula(r'A$1', 1, 1));
      expect(res, r'B$1');
    });
    // Đường: D1S D2S D3Đ → R1
    test('4-4 shiftFormula("A1", 0, -1)', () {
      final res = _run(() => shiftFormula(r'A1', 0, -1));
      expect(res, r'#REF!');
    });
    // Đường: D1S D2S D3S D4Đ → R1
    test('4-5 shiftFormula("A1", -1, 0)', () {
      final res = _run(() => shiftFormula(r'A1', -1, 0));
      expect(res, r'#REF!');
    });
  });
  group('Đơn vị 5 — _columnLetters', () {
    // Đường: D1Đ D1S → R1
    test('5-1 shiftFormula("Z1", 0, 1)', () {
      final res = _run(() => shiftFormula(r'Z1', 0, 1));
      expect(res, r'AA1');
    });
  });
  group('Đơn vị 6 — _XlsxReader.read', () {
    // Đường: D1Đ D2Đ D3S D4Đ D5S D6S D7S D8S D9S D10S D11S D12S D13S → R2
    test('6-1 gói chuẩn (rels gốc → xl/workbook.xml, date1904=1, sheet S1 → sheet1 có A1 = 7)', () {
      final res = _run(() => sig(wbOf(pk())));
      expect(res, 'S1:false:7|true');
    });
    // Đường: D1S D3S D4Đ D5S D6S D7S D8S D9S D10S D11S D12S D13S → R2
    test('6-2 rels gốc không có officeDocument ⇒ xl/workbook.xml', () {
      final res = _run(() => sig(wbOf(pk(rootType: 'metadata/core-properties', root: 'docProps/core.xml'))));
      expect(res, 'S1:false:7|true');
    });
    // Đường: D1Đ D2S D3S D4Đ D5S D6S D7S D8S D9S D10S D11S D12S D13S → R2
    test('6-3 officeDocument trỏ part không có ⇒ xl/workbook.xml', () {
      final res = _run(() => sig(wbOf(pk(root: 'xl/missing.xml'))));
      expect(res, 'S1:false:7|true');
    });
    // Đường: D1Đ D2Đ D3Đ → R1
    test('6-4 không có workbook.xml', () {
      final res = _run(() => readXlsx(buildZip({'a.xml': '<a/>'})));
      expect(res, isA<OfficeFormatException>());
    });
    // Đường: D1Đ D2Đ D3S D4S D5S D6S D7S D8S D9S D10S D11S D12S D13S → R2
    test('6-5 workbook ở gốc gói (workbook.xml, không có "/")', () {
      final res = _run(() => sig(wbOf({'_rels/.rels': rels(rl('r0', 'officeDocument', 'workbook.xml')), 'workbook.xml': wbXml(), '_rels/workbook.xml.rels': rels(rl('rId1', 'worksheet', 'sheet1.xml')), 'sheet1.xml': sheet1})));
      expect(res, 'S1:false:7|true');
    });
    // Đường: D1Đ D2Đ D3S D4Đ D5Đ D6S D7S D8S D9S D10S D11S D12S D13S → R2
    test('6-6 không có workbookPr', () {
      final res = _run(() => sig(wbOf(pk(wb: wbXml(pr: '')))));
      expect(res, 'S1:false:7|false');
    });
    // Đường: D1Đ D2Đ D3S D4Đ D5S D6Đ D7Đ → R2
    test('6-7 không có <sheets>', () {
      final res = _run(() => wbOf(pk(wb: wbXml(sheets: null))).sheets);
      expect(res, isEmpty);
    });
    // Đường: D1Đ D2Đ D3S D4Đ D5S D6S D7S D8Đ D9S D10S D11S D12S D13S → R2
    test('6-9 sheet thiếu name', () {
      final res = _run(() => sig(wbOf(pk(wb: wbXml(sheets: '<sheet sheetId="1" r:id="rId1"/>')))));
      expect(res, 'Sheet1:false:7|true');
    });
    // Đường: D1Đ D2Đ D3S D4Đ D5S D6S D7S D8S D9Đ D11S D12S D13S → R2
    test('6-10 state hidden', () {
      final res = _run(() => sig(wbOf(pk(wb: wbXml(sheets: '<sheet name="S1" sheetId="1" state="hidden" r:id="rId1"/>')))));
      expect(res, 'S1:true:7|true');
    });
    // Đường: D1Đ D2Đ D3S D4Đ D5S D6S D7S D8S D9S D10Đ D11S D12S D13S → R2
    test('6-11 state veryHidden', () {
      final res = _run(() => sig(wbOf(pk(wb: wbXml(sheets: '<sheet name="S1" sheetId="1" state="veryHidden" r:id="rId1"/>')))));
      expect(res, 'S1:true:7|true');
    });
    // Đường: D1Đ D2Đ D3S D4Đ D5S D6S D7S D8S D9S D10S D11Đ D12Đ → R2
    test('6-12 sheet thiếu r:id', () {
      final res = _run(() => sig(wbOf(pk(wb: wbXml(sheets: '<sheet name="S1" sheetId="1"/>')))));
      expect(res, 'S1:false:null|true');
    });
    // Đường: D1Đ D2Đ D3S D4Đ D5S D6S D7S D8S D9S D10S D11S D12Đ → R2
    test('6-13 r:id không có trong rels', () {
      final res = _run(() => sig(wbOf(pk(wb: wbXml(sheets: '<sheet name="S1" sheetId="1" r:id="rId9"/>')))));
      expect(res, 'S1:false:null|true');
    });
    // Đường: D1Đ D2Đ D3S D4Đ D5S D6S D7S D8S D9S D10S D11S D12S D13Đ → R2
    test('6-14 rel của sheet là External', () {
      final res = _run(() => sig(wbOf(pk(sheetRel: rl('rId1', 'worksheet', 'http://x/s.xml', ext: true)))));
      expect(res, 'S1:false:null|true');
    });
  });
  group('Đơn vị 7 — read — part (hàm cục bộ)', () {
    // Đường: D1Đ D2Đ → R1
    test('7-1 rels sharedStrings → ss2.xml (chuỗi "hi"); ô t=s v=0', () {
      final res = _run(() => wbOf(pk(wbRels: rl('rS', 'sharedStrings', 'ss2.xml'))..['xl/ss2.xml'] = '<sst $sNs><si><t>hi</t></si></sst>'..['xl/worksheets/sheet1.xml'] = sheet1.replaceFirst('<c r="A1">', '<c r="A1" t="s">').replaceFirst('<v>7</v>', '<v>0</v>')).sheets.single.cell(0, 0)!.display);
      expect(res, 'hi');
    });
    // Đường: D1S → R2
    test('7-2 rel sharedStrings External ⇒ dùng xl/sharedStrings.xml', () {
      final res = _run(() => wbOf(pk(wbRels: rl('rS', 'sharedStrings', 'http://x/ss.xml', ext: true))..['xl/sharedStrings.xml'] = '<sst $sNs><si><t>def</t></si></sst>'..['xl/worksheets/sheet1.xml'] = sheet1.replaceFirst('<c r="A1">', '<c r="A1" t="s">').replaceFirst('<v>7</v>', '<v>0</v>')).sheets.single.cell(0, 0)!.display);
      expect(res, 'def');
    });
    // Đường: D1Đ D2S → R2
    test('7-3 không có rel sharedStrings ⇒ xl/sharedStrings.xml', () {
      final res = _run(() => wbOf(pk()..['xl/sharedStrings.xml'] = '<sst $sNs><si><t>def</t></si></sst>'..['xl/worksheets/sheet1.xml'] = sheet1.replaceFirst('<c r="A1">', '<c r="A1" t="s">').replaceFirst('<v>7</v>', '<v>0</v>')).sheets.single.cell(0, 0)!.display);
      expect(res, 'def');
    });
  });
  group('Đơn vị 8 — _XlsxReader._richText', () {
    // Đường: D1Đ → R1
    test('8-1 si <t>ab</t>', () {
      final res = _run(() => cell(r'<c r="A1" t="s"><v>0</v></c>', ss: '<si><t>ab</t></si>'));
      expect(res, isA<XlsxCell>().having((c) => c.display, 'display', 'ab'));
    });
    // Đường: D1S D2S → R1
    test('8-2 si <t>a</t><rPh><t>x</t></rPh> (phiên âm)', () {
      final res = _run(() => cell(r'<c r="A1" t="s"><v>0</v></c>', ss: '<si><t>a</t><rPh><t>x</t></rPh></si>'));
      expect(res, isA<XlsxCell>().having((c) => c.display, 'display', 'a'));
    });
    // Đường: D1S D2Đ → R1
    test('8-3 si rich <r><t>a</t></r><r><t>b</t></r>', () {
      final res = _run(() => cell(r'<c r="A1" t="s"><v>0</v></c>', ss: '<si><r><t>a</t></r><r><t>b</t></r></si>'));
      expect(res, isA<XlsxCell>().having((c) => c.display, 'display', 'ab'));
    });
  });
  group('Đơn vị 9 — _XlsxReader._unescapeX', () {
    // Đường: D1S → R2
    test('9-1 str "a_x000D_b"', () {
      final res = _run(() => cell(r'<c r="A1" t="str"><v>a_x000D_b</v></c>'));
      expect(res, isA<XlsxCell>().having((c) => c.display, 'display', 'a\rb'));
    });
    // Đường: D1Đ → R1
    test('9-2 str "ab"', () {
      final res = _run(() => cell(r'<c r="A1" t="str"><v>ab</v></c>'));
      expect(res, isA<XlsxCell>().having((c) => c.display, 'display', 'ab'));
    });
  });
  group('Đơn vị 10 — _XlsxReader._sharedStrings', () {
    // Đường: D1S → R2
    test('10-1 có sharedStrings', () {
      final res = _run(() => cell(r'<c r="A1" t="s"><v>0</v></c>', ss: '<si><t>x</t></si>'));
      expect(res, isA<XlsxCell>().having((c) => c.display, 'display', 'x'));
    });
    // Đường: D1Đ → R1
    test('10-2 không có sharedStrings.xml', () {
      final res = _run(() => cell(r'<c r="A1" t="s"><v>0</v></c>'));
      expect(res, isA<XlsxCell>().having((c) => c.display, 'display', ''));
    });
  });
  group('Đơn vị 11 — _XlsxReader._cell', () {
    // Đường: D1S D2S D3S D4Đ D5S D10Đ D11S D12S D13S D14S D15S D16S D17S D18S D34S D35S D38S D39S D41S D42S → R12
    test('11-1 <c r="A1" s="0" t="n"><f>A2+1</f><v>3</v></c>', () {
      final res = _run(() => kd(cell(r'<c r="A1" s="0" t="n"><f>A2+1</f><v>3</v></c>')));
      expect(res, r'number|3|3.0|A2+1');
    });
    // Đường: D1Đ D2S D3S D4Đ D5S D10Đ D11S D12S D13S D14S D15S D16S D17S D18S D34S D35S D38S D39S D41S D42S → R12
    test('11-2 <c r="A1" t="n"><f>A2+1</f><v>3</v></c>', () {
      final res = _run(() => kd(cell(r'<c r="A1" t="n"><f>A2+1</f><v>3</v></c>')));
      expect(res, r'number|3|3.0|A2+1');
    });
    // Đường: D1S D2Đ D3S D4Đ D5S D10Đ D11S D12S D13S D14S D15S D16S D17S D18S D34S D35S D38S D39S D41S D42S → R12
    test('11-3 <c r="A1" s="0"><f>A2+1</f><v>3</v></c>', () {
      final res = _run(() => kd(cell(r'<c r="A1" s="0"><f>A2+1</f><v>3</v></c>')));
      expect(res, r'number|3|3.0|A2+1');
    });
    // Đường: D1S D2S D3Đ D4S D10S D12S D13S D14S D15S D16S D17S D18S D34S D35S D38S D39S D41S D42S → R12
    test('11-4 <c r="A1" s="0"><v>3</v></c>', () {
      final res = _run(() => kd(cell(r'<c r="A1" s="0"><v>3</v></c>')));
      expect(res, r'number|3|3.0|null');
    });
    // Đường: D1S D2S D3S D4Đ D5Đ D6Đ D7Đ D8Đ D10Đ D11S D12S D13S D14S D15S D16S D17S D18S D34S D35S D38S D39S D41S D42S → R12
    test('11-6 <c r="A1" s="0"><f t="shared" ref="A1:A2" si="0">A1*2</f><v>3</v></c>', () {
      final res = _run(() => kd(cell(r'<c r="A1" s="0"><f t="shared" ref="A1:A2" si="0">A1*2</f><v>3</v></c>')));
      expect(res, r'number|3|3.0|A1*2');
    });
    // Đường: D1S D2S D3S D4Đ D5S D10Đ D11Đ D12S D13S D14S D15S D16S D17S D18S D34S D35S D38S D39S D41S D42S → R12
    test('11-8 <c r="A1" s="0"><f></f><v>3</v></c>', () {
      final res = _run(() => kd(cell(r'<c r="A1" s="0"><f></f><v>3</v></c>')));
      expect(res, r'number|3|3.0|null');
    });
    // Đường: D1S D2S D3S D4Đ D5S D10Đ D11S D12Đ D13S D14S D15S D16S D17S D18S D34Đ D36S → R9
    test('11-9 <c r="A1" s="0"><f>A2</f></c>', () {
      final res = _run(() => kd(cell(r'<c r="A1" s="0"><f>A2</f></c>')));
      expect(res, r'blank||null|A2');
    });
    // Đường: D1S D2S D3S D4Đ D5S D10Đ D11S D12S D13Đ D19S → R1
    test('11-10 <c r="A1" s="0" t="inlineStr"><f>X</f><v>9</v><is><t>hi</t></is></c>', () {
      final res = _run(() => kd(cell(r'<c r="A1" s="0" t="inlineStr"><f>X</f><v>9</v><is><t>hi</t></is></c>')));
      expect(res, r'string|hi|hi|X');
    });
    // Đường: D1S D2S D3S D4Đ D5S D10Đ D11S D12S D13S D14Đ D21Đ D22Đ D23Đ → R2
    test('11-11 <c r="A1" s="0" t="s"><f>X</f><v>0</v></c>', () {
      final res = _run(() => kd(cell(r'<c r="A1" s="0" t="s"><f>X</f><v>0</v></c>', ss: '<si><t>hi</t></si>')));
      expect(res, r'string|hi|hi|X');
    });
    // Đường: D1S D2S D3S D4Đ D5S D10Đ D11S D12S D13S D14S D15Đ D24S → R3
    test('11-12 <c r="A1" s="0" t="str"><f>X</f><v>ab</v></c>', () {
      final res = _run(() => kd(cell(r'<c r="A1" s="0" t="str"><f>X</f><v>ab</v></c>')));
      expect(res, r'string|ab|ab|X');
    });
    // Đường: D1S D2S D3S D4Đ D5S D10Đ D11S D12S D13S D14S D15S D16Đ D25Đ D26S D27S → R4
    test('11-13 <c r="A1" s="0" t="b"><f>X</f><v>0</v></c>', () {
      final res = _run(() => kd(cell(r'<c r="A1" s="0" t="b"><f>X</f><v>0</v></c>')));
      expect(res, r'boolean|FALSE|false|X');
    });
    // Đường: D1S D2S D3S D4Đ D5S D10Đ D11S D12S D13S D14S D15S D16S D17Đ D28S D29S → R5
    test('11-14 <c r="A1" s="0" t="e"><f>X</f><v>#DIV/0!</v></c>', () {
      final res = _run(() => kd(cell(r'<c r="A1" s="0" t="e"><f>X</f><v>#DIV/0!</v></c>')));
      expect(res, r'error|#DIV/0!|#DIV/0!|X');
    });
    // Đường: D1S D2S D3S D4Đ D5S D10Đ D11S D12S D13S D14S D15S D16S D17S D18Đ D30S D31S D33S → R7
    test('11-15 <c r="A1" s="0" t="d"><f>X</f><v>2024-01-15</v></c>', () {
      final res = _run(() => kd(cell(r'<c r="A1" s="0" t="d"><f>X</f><v>2024-01-15</v></c>')));
      expect(res, r'date|2024-01-15|2024-01-15 00:00:00.000Z|X');
    });
    // Đường: D1S D2S D3S D4Đ D5S D10Đ D11S D12S D13S D14S D15S D16S D17S D18S D34S D35Đ D36S → R9
    test('11-17 <c r="A1" s="0"><f>X</f><v>  </v></c>', () {
      final res = _run(() => kd(cell(r'<c r="A1" s="0"><f>X</f><v>  </v></c>')));
      expect(res, r'blank||null|X');
    });
    // Đường: D1S D2S D3S D4Đ D5S D10Đ D11S D12S D13S D14S D15S D16S D17S D18S D34S D35S D38Đ → R10
    test('11-18 <c r="A1" s="0"><f>X</f><v>abc</v></c>', () {
      final res = _run(() => kd(cell(r'<c r="A1" s="0"><f>X</f><v>abc</v></c>')));
      expect(res, r'string|abc|abc|X');
    });
    // Đường: D1S D2S D3S D4Đ D5S D10Đ D11S D12S D13S D14S D15S D16S D17S D18S D34S D35S D38S D39Đ D40S D41S D42Đ D43Đ → R13
    test('11-19 <c r="A1" s="1"><f>X</f><v>45000</v></c>', () {
      final res = _run(() => kd(cell(r'<c r="A1" s="1"><f>X</f><v>45000</v></c>')));
      expect(res, r'date|15/3/2023|2023-03-15 00:00:00.000Z|X');
    });
    // Đường: D1S D2S D3S D4Đ D5S D10Đ D11S D12S D13S D14S D15S D16S D17S D18S D34S D35S D38S D39S D41Đ → R11
    test('11-20 mã 0.(21 số 0) làm formatNumber ném', () {
      final res = _run(() => kd(cell(r'<c r="A1" s="1"><f>X</f><v>1.5</v></c>', styles: '<numFmts><numFmt numFmtId="164" formatCode="0.000000000000000000000"/></numFmts><cellXfs><xf numFmtId="0"/><xf numFmtId="164"/></cellXfs>')));
      expect(res, r'number|1.5|1.5|X');
    });
    // Đường: D1S D2S D3S D4Đ D5Đ D6S D10Đ D11S D12S D13S D14S D15S D16S D17S D18S D34S D35S D38S D39S D41S D42S → R12
    test('11-22 <c r="A1" s="0"><f t="shared">A1*2</f><v>3</v></c>', () {
      final res = _run(() => kd(cell(r'<c r="A1" s="0"><f t="shared">A1*2</f><v>3</v></c>')));
      expect(res, r'number|3|3.0|A1*2');
    });
    // Đường: D1S D2S D3S D4Đ D5Đ D6Đ D7Đ D8S D9S D10Đ D11S D12S D13S D14S D15S D16S D17S D18S D34S D35S D38S D39S D41S D42S → R12
    test('11-24 A1 ô gốc shared B1*2 (si 0), A2 ô con <f t="shared" si="0"/>', () {
      final res = _run(() => kd(readXlsx(buildXlsx(sheets: [SheetSpec('S', '<sheetData><row r="1"><c r="A1"><f t="shared" ref="A1:A2" si="0">B1*2</f><v>3</v></c></row><row r="2"><c r="A2"><f t="shared" si="0"/><v>3</v></c></row></sheetData>')])).sheets.single.cell(1, 0)));
      expect(res, r'number|3|3.0|B2*2');
    });
    // Đường: D1S D2S D3S D4Đ D5S D10Đ D11S D12S D13Đ D19Đ D20S → R1
    test('11-26 <c r="A1" s="0" t="inlineStr"><f>X</f><v>x</v></c>', () {
      final res = _run(() => kd(cell(r'<c r="A1" s="0" t="inlineStr"><f>X</f><v>x</v></c>')));
      expect(res, r'string|x|x|X');
    });
    // Đường: D1S D2S D3S D4Đ D5S D10Đ D11S D12S D13S D14Đ D21S → R2
    test('11-27 <c r="A1" s="0" t="s"><f>X</f><v>abc</v></c>', () {
      final res = _run(() => kd(cell(r'<c r="A1" s="0" t="s"><f>X</f><v>abc</v></c>')));
      expect(res, r'string|||X');
    });
    // Đường: D1S D2S D3S D4Đ D5S D10Đ D11S D12S D13S D14Đ D21Đ D22S → R2
    test('11-28 <c r="A1" s="0" t="s"><f>X</f><v>-1</v></c>', () {
      final res = _run(() => kd(cell(r'<c r="A1" s="0" t="s"><f>X</f><v>-1</v></c>')));
      expect(res, r'string|||X');
    });
    // Đường: D1S D2S D3S D4Đ D5S D10Đ D11S D12S D13S D14Đ D21Đ D22Đ D23S → R2
    test('11-29 <c r="A1" s="0" t="s"><f>X</f><v>5</v></c>', () {
      final res = _run(() => kd(cell(r'<c r="A1" s="0" t="s"><f>X</f><v>5</v></c>')));
      expect(res, r'string|||X');
    });
    // Đường: D1S D2S D3S D4Đ D5S D10Đ D11S D12S D13S D14S D15S D16Đ D25Đ D26Đ → R4
    test('11-32 <c r="A1" s="0" t="b"><f>X</f><v>1</v></c>', () {
      final res = _run(() => kd(cell(r'<c r="A1" s="0" t="b"><f>X</f><v>1</v></c>')));
      expect(res, r'boolean|TRUE|true|X');
    });
    // Đường: D1S D2S D3S D4Đ D5S D10Đ D11S D12S D13S D14S D15S D16Đ D25Đ D26S D27Đ → R4
    test('11-33 <c r="A1" s="0" t="b"><f>X</f><v>true</v></c>', () {
      final res = _run(() => kd(cell(r'<c r="A1" s="0" t="b"><f>X</f><v>true</v></c>')));
      expect(res, r'boolean|TRUE|true|X');
    });
    // Đường: D1S D2S D3S D4Đ D5S D10Đ D11S D12S D13S D14S D15S D16S D17S D18Đ D30S D31Đ D32S → R6
    test('11-37 <c r="A1" s="0" t="d"><f>X</f><v>abc</v></c>', () {
      final res = _run(() => kd(cell(r'<c r="A1" s="0" t="d"><f>X</f><v>abc</v></c>')));
      expect(res, r'string|abc|abc|X');
    });
    // Đường: D1S D2S D3S D4Đ D5S D10Đ D11S D12S D13S D14S D15S D16S D17S D18Đ D30S D31S D33Đ → R7
    test('11-38 <c r="A1" s="1" t="d"><f>X</f><v>2024-01-15</v></c>', () {
      final res = _run(() => kd(cell(r'<c r="A1" s="1" t="d"><f>X</f><v>2024-01-15</v></c>')));
      expect(res, r'date|15/1/2024|2024-01-15 00:00:00.000Z|X');
    });
    // Đường: D1S D2S D3S D4Đ D5S D10Đ D11S D12S D13S D14S D15S D16S D17S D18S D34S D35S D38S D39Đ D40Đ → R11
    test('11-39 <c r="A1" s="1"><f>X</f><v>3000000</v></c>', () {
      final res = _run(() => kd(cell(r'<c r="A1" s="1"><f>X</f><v>3000000</v></c>')));
      expect(res, r'number|3000000|3000000.0|X');
    });
    // Đường: D1S D2S D3S D4Đ D5S D10Đ D11S D12S D13S D14S D15S D16S D17S D18S D34S D35S D38S D39Đ D40S D41S D42Đ D43S → R12
    test('11-40 ô định dạng ngày, v = -1', () {
      final res = _run(() => kd(cell(r'<c r="A1" s="1"><f>X</f><v>-1</v></c>')));
      expect(res, startsWith('number|'));
    });
    // Đường: D4Đ D5Đ D6Đ D7Đ D8S D9Đ D10S … D42S → R12 (bổ sung)
    test('11-b1 <c r="A1" s="0"><f t="shared" si="5"/><v>3</v></c>', () {
      final res = _run(() => kd(cell(r'<c r="A1" s="0"><f t="shared" si="5"/><v>3</v></c>')));
      expect(res, r'number|3|3.0|null');
    });
    // Đường: … D12Đ D15Đ D24Đ → R3 (bổ sung)
    test('11-b2 <c r="A1" t="str"><f>A2</f></c>', () {
      final res = _run(() => kd(cell(r'<c r="A1" t="str"><f>A2</f></c>')));
      expect(res, r'string|||A2');
    });
    // Đường: … D12Đ D16Đ D25S → R4 (bổ sung)
    test('11-b3 <c r="A1" t="b"/>', () {
      final res = _run(() => kd(cell(r'<c r="A1" t="b"/>')));
      expect(res, r'boolean|FALSE|false|null');
    });
    // Đường: … D12Đ D17Đ D28Đ D29Đ → R5 (bổ sung)
    test('11-b4 <c r="A1" t="e"/>', () {
      final res = _run(() => kd(cell(r'<c r="A1" t="e"/>')));
      expect(res, r'error|#N/A|#N/A|null');
    });
    // Đường: … D12Đ D18Đ D30Đ D31Đ D32Đ → R6 (bổ sung)
    test('11-b5 <c r="A1" t="d"/>', () {
      final res = _run(() => kd(cell(r'<c r="A1" t="d"/>')));
      expect(res, r'string||null|null');
    });
    // Đường: D1Đ … D12Đ … D34Đ D36Đ D37Đ → R8 (bổ sung)
    test('11-b6 <c r="A1"/>', () {
      final res = _run(() => kd(cell(r'<c r="A1"/>')));
      expect(res, isNull);
    });
    // Đường: D1Đ … D10Đ D11S D12Đ … D34Đ D36Đ D37S → R9 (bổ sung)
    test('11-b7 <c r="A1"><f>B1</f></c>', () {
      final res = _run(() => kd(cell(r'<c r="A1"><f>B1</f></c>')));
      expect(res, r'blank||null|B1');
    });
    // Đường: … D12Đ D13Đ D19Đ D20Đ → R1 (bổ sung)
    test('11-b8 <c r="A1" t="inlineStr"/>', () {
      final res = _run(() => kd(cell(r'<c r="A1" t="inlineStr"/>')));
      expect(res, r'string|||null');
    });
  });
}
