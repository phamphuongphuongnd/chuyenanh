// Kiểm thử hộp trắng (agent A17, lượt bổ sung A17b) cho lib/src/xlsx/xlsx_reader.dart.
// Sinh từ Bước 5 (test-output/whitebox/office-reader/xlsx_reader/buoc-5-du-lieu-thu.md).
// Expected chép từ Bước 5 — KHÔNG chỉnh cho khớp code. Tên test bắt đầu bằng mã bộ.
import 'package:office_reader/office_reader.dart';
import 'package:test/test.dart';

import '../helpers/ooxml.dart';
Object? _run(Object? Function() f) {
  try {
    return f();
  } catch (e) {
    return e;
  }
}

/// Chữ ký sheet: tên|maxRow x maxCol|ô|merge|độ rộng cột|chiều cao hàng|mặc định rộng/cao|frozen hàng,cột|ẩn.
String sig(XlsxSheet s) {
  final keys = s.cells.keys.toList()..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
  final cells = keys.map((k) => '${k.$1},${k.$2}=${s.cells[k]!.display}').join(';');
  final m = s.merges.map((r) => '${r.firstRow},${r.firstCol}-${r.lastRow},${r.lastCol}').join(';');
  String mp(Map<int, double> x) => (x.keys.toList()..sort()).map((k) => '$k:${x[k]}').join(';');
  return '${s.name}|${s.maxRow}x${s.maxCol}|$cells|$m|${mp(s.columnWidthsChars)}|${mp(s.rowHeightsPt)}|'
      '${s.defaultColumnWidthChars}/${s.defaultRowHeightPt}|${s.frozenRows},${s.frozenCols}|${s.hidden}';
}

const pctStyles = '<cellXfs count="2"><xf numFmtId="0"/><xf numFmtId="10"/></cellXfs>';

XlsxSheet sheetOf({
  String row = '<row r="1">',
  String cells = '<c r="A1"><v>1</v></c>',
  String? data,
  String merge = '<mergeCells count="1"><mergeCell ref="A1:B2"/></mergeCells>',
  String fmt = '<sheetFormatPr defaultColWidth="10" defaultRowHeight="20"/>',
  String cols = '<cols><col min="2" max="2" width="12"/></cols>',
  String pane = '<sheetViews><sheetView workbookViewId="0"><pane xSplit="1" ySplit="2" state="frozen"/></sheetView></sheetViews>',
  String? styles,
}) {
  final d = data ?? '<sheetData>$row$cells</row></sheetData>';
  return readXlsx(buildXlsx(sheets: [SheetSpec('S', '$pane$fmt$cols$d$merge')], styles: styles)).sheets.single;
}

String sh({
  String row = '<row r="1">',
  String cells = '<c r="A1"><v>1</v></c>',
  String? data,
  String merge = '<mergeCells count="1"><mergeCell ref="A1:B2"/></mergeCells>',
  String fmt = '<sheetFormatPr defaultColWidth="10" defaultRowHeight="20"/>',
  String cols = '<cols><col min="2" max="2" width="12"/></cols>',
  String pane = '<sheetViews><sheetView workbookViewId="0"><pane xSplit="1" ySplit="2" state="frozen"/></sheetView></sheetViews>',
  String? styles,
}) =>
    sig(sheetOf(row: row, cells: cells, data: data, merge: merge, fmt: fmt, cols: cols, pane: pane, styles: styles));

/// Workbook có sheet trỏ tới part không tồn tại.
String missingSheet() {
  const ns = 'xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"';
  final z = buildZip({
    '[Content_Types].xml': '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>',
    'xl/workbook.xml': '<workbook $ns><sheets><sheet name="S1" sheetId="1" r:id="rId1"/></sheets></workbook>',
    'xl/_rels/workbook.xml.rels':
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/missing.xml"/></Relationships>',
  });
  return sig(readXlsx(z).sheets.single);
}

/// Mọi khoá (hàng, cột) của ô / chiều cao hàng / độ rộng cột đều ≥ 0.
bool nonNeg(XlsxSheet s) =>
    s.cells.keys.every((k) => k.$1 >= 0 && k.$2 >= 0) &&
    s.rowHeightsPt.keys.every((k) => k >= 0) &&
    s.columnWidthsChars.keys.every((k) => k >= 0);

void main() {
  group('Đơn vị 12 — _XlsxReader._sheet', () {
    // Đường: S1S S2S S3S S4Đ S5S S6S S8S S9S S10Đ S11S S12S S13S S14S S15Đ S16S S17S S18S S19S S22S S23S S24S S25S S26S S27S S28S S30Đ S31Đ S32S S30S S33S S34S S35Đ S36Đ S38S S39S S40S S41S → R2
    test('12-1 sheet đủ: hàng r=1 có A1=1, merge A1:B2, sheetFormatPr 10/20, cột B rộng 12, pane frozen xSplit=1 ySplit=2', () {
      final res = _run(() => sh());
      expect(res, r'S|2x2|0,0=1|0,0-1,1|1:12.0||10.0/20.0|2,1|false');
    });
    // Đường: S1Đ → R1
    test('12-2 sheet trỏ tới part không có trong gói', () {
      final res = _run(() => missingSheet());
      expect(res, r'S1|0x0|||||8.43/15.0|0,0|false');
    });
    // Đường: S1S S2Đ S3Đ S12S S13S S14S S15Đ S16S S17S S18S S19S S22S S23S S24S S25S S26S S27S S28S S30Đ S31Đ S32S S30S S33S S34S S35Đ S36Đ S38S S39S S40S S41S → R2
    test('12-3 không có sheetData', () {
      final res = _run(() => sh(data: ''));
      expect(res, r'S|2x2||0,0-1,1|1:12.0||10.0/20.0|2,1|false');
    });
    // Đường: S1S S2S S3S S4S S5S S6S S8S S9S S10Đ S11S S12S S13S S14S S15Đ S16S S17S S18S S19S S22S S23S S24S S25S S26S S27S S28S S30Đ S31Đ S32S S30S S33S S34S S35Đ S36Đ S38S S39S S40S S41S → R2
    test('12-5 hàng r=3 rồi 1 hàng không có r', () {
      final res = _run(() => sh(data: '<sheetData><row r="3"><c r="A3"><v>1</v></c></row><row><c r="A4"><v>2</v></c></row></sheetData>'));
      expect(res, r'S|4x2|2,0=1;3,0=2|0,0-1,1|1:12.0||10.0/20.0|2,1|false');
    });
    // Đường: S1S S2S S3S S4Đ S5Đ S8S S9S S10Đ S11S S12S S13S S14S S15Đ S16S S17S S18S S19S S22S S23S S24S S25S S26S S27S S28S S30Đ S31Đ S32S S30S S33S S34S S35Đ S36Đ S38S S39S S40S S41S → R2
    test('12-6 hàng ẩn', () {
      final res = _run(() => sh(row: '<row r="1" hidden="1">'));
      expect(res, r'S|2x2|0,0=1|0,0-1,1|1:12.0|0:0.0|10.0/20.0|2,1|false');
    });
    // Đường: S1S S2S S3S S4Đ S5S S6Đ S7Đ S8S S9S S10Đ S11S S12S S13S S14S S15Đ S16S S17S S18S S19S S22S S23S S24S S25S S26S S27S S28S S30Đ S31Đ S32S S30S S33S S34S S35Đ S36Đ S38S S39S S40S S41S → R2
    test('12-7 ht=30 customHeight=1', () {
      final res = _run(() => sh(row: '<row r="1" ht="30" customHeight="1">'));
      expect(res, r'S|2x2|0,0=1|0,0-1,1|1:12.0|0:30.0|10.0/20.0|2,1|false');
    });
    // Đường: S1S S2S S3S S4Đ S5S S6S S8Đ S9S S10Đ S11S S12S S13S S14S S15Đ S16S S17S S18S S19S S22S S23S S24S S25S S26S S27S S28S S30Đ S31Đ S32S S30S S33S S34S S35Đ S36Đ S38S S39S S40S S41S → R2
    test('12-8 hàng customFormat=1 s=1 (0.00%), ô không có s', () {
      final res = _run(() => sh(row: '<row r="1" customFormat="1" s="1">', styles: pctStyles));
      expect(res, r'S|2x2|0,0=100.00%|0,0-1,1|1:12.0||10.0/20.0|2,1|false');
    });
    // Đường: S1S S2S S3S S4Đ S5S S6S S8S S9Đ S10S S11S S12S S13S S14S S15Đ S16S S17S S18S S19S S22S S23S S24S S25S S26S S27S S28S S30Đ S31Đ S32S S30S S33S S34S S35Đ S36Đ S38S S39S S40S S41S → R2
    test('12-9 ô B1 rồi 1 ô không có r', () {
      final res = _run(() => sh(cells: '<c r="B1"><v>1</v></c><c><v>2</v></c>'));
      expect(res, r'S|2x3|0,1=1;0,2=2|0,0-1,1|1:12.0||10.0/20.0|2,1|false');
    });
    // Đường: S1S S2S S3S S4Đ S5S S6S S8S S9S S10S S11S S12S S13S S14S S15Đ S16S S17S S18S S19S S22S S23S S24S S25S S26S S27S S28S S30Đ S31Đ S32S S30S S33S S34S S35Đ S36Đ S38S S39S S40S S41S → R2
    test('12-10 ô B1 rồi ô ref hỏng "A0"', () {
      final res = _run(() => sh(cells: '<c r="B1"><v>1</v></c><c r="A0"><v>2</v></c>'));
      expect(res, r'S|2x3|0,1=1;0,2=2|0,0-1,1|1:12.0||10.0/20.0|2,1|false');
    });
    // Đường: S1S S2S S3S S4Đ S5S S6S S8S S9S S10Đ S11Đ S12S S13S S14S S15Đ S16S S17S S18S S19S S22S S23S S24S S25S S26S S27S S28S S30Đ S31Đ S32S S30S S33S S34S S35Đ S36Đ S38S S39S S40S S41S → R2
    test('12-11 ô rỗng không style', () {
      final res = _run(() => sh(cells: '<c r="A1"/>'));
      expect(res, r'S|2x2||0,0-1,1|1:12.0||10.0/20.0|2,1|false');
    });
    // Đường: S1S S2S S3S S4Đ S5S S6S S8S S9S S10Đ S11S S12Đ S13Đ S18S S19S S22S S23S S24S S25S S26S S27S S28S S30Đ S31Đ S32S S30S S33S S34S S35Đ S36Đ S38S S39S S40S S41S → R2
    test('12-12 không có mergeCells', () {
      final res = _run(() => sh(merge: ''));
      expect(res, r'S|1x1|0,0=1||1:12.0||10.0/20.0|2,1|false');
    });
    // Đường: S1S S2S S3S S4Đ S5S S6S S8S S9S S10Đ S11S S12S S13S S14Đ S18S S19S S22S S23S S24S S25S S26S S27S S28S S30Đ S31Đ S32S S30S S33S S34S S35Đ S36Đ S38S S39S S40S S41S → R2
    test('12-14 mergeCell không có ref', () {
      final res = _run(() => sh(merge: '<mergeCells><mergeCell/></mergeCells>'));
      expect(res, r'S|1x1|0,0=1||1:12.0||10.0/20.0|2,1|false');
    });
    // Đường: S1S S2S S3S S4Đ S5S S6S S8S S9S S10Đ S11S S12S S13S S14S S15S S16S S17S S18S S19S S22S S23S S24S S25S S26S S27S S28S S30Đ S31Đ S32S S30S S33S S34S S35Đ S36Đ S38S S39S S40S S41S → R2
    test('12-15 mergeCell ref 1 ô "B3"', () {
      final res = _run(() => sh(merge: '<mergeCells><mergeCell ref="B3"/></mergeCells>'));
      expect(res, r'S|3x2|0,0=1|2,1-2,1|1:12.0||10.0/20.0|2,1|false');
    });
    // Đường: S1S S2S S3S S4Đ S5S S6S S8S S9S S10Đ S11S S12S S13S S14S S15Đ S16Đ S18S S19S S22S S23S S24S S25S S26S S27S S28S S30Đ S31Đ S32S S30S S33S S34S S35Đ S36Đ S38S S39S S40S S41S → R2
    test('12-16 merge đầu hỏng "A0:B2"', () {
      final res = _run(() => sh(merge: '<mergeCells><mergeCell ref="A0:B2"/></mergeCells>'));
      expect(res, r'S|1x1|0,0=1||1:12.0||10.0/20.0|2,1|false');
    });
    // Đường: S1S S2S S3S S4Đ S5S S6S S8S S9S S10Đ S11S S12S S13S S14S S15Đ S16S S17Đ S18S S19S S22S S23S S24S S25S S26S S27S S28S S30Đ S31Đ S32S S30S S33S S34S S35Đ S36Đ S38S S39S S40S S41S → R2
    test('12-17 merge cuối hỏng "A1:B0"', () {
      final res = _run(() => sh(merge: '<mergeCells><mergeCell ref="A1:B0"/></mergeCells>'));
      expect(res, r'S|1x1|0,0=1||1:12.0||10.0/20.0|2,1|false');
    });
    // Đường: S1S S2S S3S S4Đ S5S S6S S8S S9S S10Đ S11S S12S S13S S14S S15Đ S16S S17S S18Đ S19Đ S20Đ S21Đ S22Đ S23Đ S24S S25S S26S S27S S28S S30Đ S31Đ S32S S30S S33S S34S S35Đ S36Đ S38S S39S S40S S41S → R2
    test('12-18 không có sheetFormatPr', () {
      final res = _run(() => sh(fmt: ''));
      expect(res, r'S|2x2|0,0=1|0,0-1,1|1:12.0||8.43/15.0|2,1|false');
    });
    // Đường: S1S S2S S3S S4Đ S5S S6S S8S S9S S10Đ S11S S12S S13S S14S S15Đ S16S S17S S18S S19Đ S20S S21S S22S S23S S24S S25S S26S S27S S28S S30Đ S31Đ S32S S30S S33S S34S S35Đ S36Đ S38S S39S S40S S41S → R2
    test('12-19 chỉ có baseColWidth=10', () {
      final res = _run(() => sh(fmt: '<sheetFormatPr baseColWidth="10" defaultRowHeight="20"/>'));
      expect(res, r'S|2x2|0,0=1|0,0-1,1|1:12.0||10.43/20.0|2,1|false');
    });
    // Đường: S1S S2S S3S S4Đ S5S S6S S8S S9S S10Đ S11S S12S S13S S14S S15Đ S16S S17S S18S S19S S22S S23Đ S24S S25S S26S S27S S28S S30Đ S31Đ S32S S30S S33S S34S S35Đ S36Đ S38S S39S S40S S41S → R2
    test('12-21 không có defaultRowHeight', () {
      final res = _run(() => sh(fmt: '<sheetFormatPr defaultColWidth="10"/>'));
      expect(res, r'S|2x2|0,0=1|0,0-1,1|1:12.0||10.0/15.0|2,1|false');
    });
    // Đường: S1S S2S S3S S4Đ S5S S6S S8S S9S S10Đ S11S S12S S13S S14S S15Đ S16S S17S S18S S19S S22S S23S S24Đ S25Đ S33S S34S S35Đ S36Đ S38S S39S S40S S41S → R2
    test('12-22 không có cols', () {
      final res = _run(() => sh(cols: ''));
      expect(res, r'S|2x2|0,0=1|0,0-1,1|||10.0/20.0|2,1|false');
    });
    // Đường: S1S S2S S3S S4Đ S5S S6S S8S S9S S10Đ S11S S12S S13S S14S S15Đ S16S S17S S18S S19S S22S S23S S24S S25S S26Đ S27S S28S S30Đ S31Đ S32S S30S S33S S34S S35Đ S36Đ S38S S39S S40S S41S → R2
    test('12-24 col không có min', () {
      final res = _run(() => sh(cols: '<cols><col max="2" width="12"/></cols>'));
      expect(res, r'S|2x2|0,0=1|0,0-1,1|0:12.0;1:12.0||10.0/20.0|2,1|false');
    });
    // Đường: S1S S2S S3S S4Đ S5S S6S S8S S9S S10Đ S11S S12S S13S S14S S15Đ S16S S17S S18S S19S S22S S23S S24S S25S S26S S27Đ S28S S30Đ S31Đ S32S S30S S33S S34S S35Đ S36Đ S38S S39S S40S S41S → R2
    test('12-25 col không có max', () {
      final res = _run(() => sh(cols: '<cols><col min="2" width="12"/></cols>'));
      expect(res, r'S|2x2|0,0=1|0,0-1,1|1:12.0||10.0/20.0|2,1|false');
    });
    // Đường: S1S S2S S3S S4Đ S5S S6S S8S S9S S10Đ S11S S12S S13S S14S S15Đ S16S S17S S18S S19S S22S S23S S24S S25S S26S S27S S28Đ S29S S30Đ S31Đ S32Đ S30S S33S S34S S35Đ S36Đ S38S S39S S40S S41S → R2
    test('12-26 cột ẩn không có width', () {
      final res = _run(() => sh(cols: '<cols><col min="2" max="2" hidden="1"/></cols>'));
      expect(res, r'S|2x2|0,0=1|0,0-1,1|1:0.0||10.0/20.0|2,1|false');
    });
    // Đường: S1S S2S S3S S4Đ S5S S6S S8S S9S S10Đ S11S S12S S13S S14S S15Đ S16S S17S S18S S19S S22S S23S S24S S25S S26S S27S S28S S30S S33S S34S S35Đ S36Đ S38S S39S S40S S41S → R2
    test('12-27 col min > max', () {
      final res = _run(() => sh(cols: '<cols><col min="3" max="2" width="12"/></cols>'));
      expect(res, r'S|2x2|0,0=1|0,0-1,1|||10.0/20.0|2,1|false');
    });
    // Đường: S1S S2S S3S S4Đ S5S S6S S8S S9S S10Đ S11S S12S S13S S14S S15Đ S16S S17S S18S S19S S22S S23S S24S S25S S26S S27S S28S S30Đ S31S S33S S34S S35Đ S36Đ S38S S39S S40S S41S → R2
    test('12-28 col 100 vượt maxCol + 64', () {
      final res = _run(() => sh(cols: '<cols><col min="100" max="100" width="12"/></cols>'));
      expect(res, r'S|2x2|0,0=1|0,0-1,1|||10.0/20.0|2,1|false');
    });
    // Đường: S1S S2S S3S S4Đ S5S S6S S8S S9S S10Đ S11S S12S S13S S14S S15Đ S16S S17S S18S S19S S22S S23S S24S S25S S26S S27S S28S S30Đ S31Đ S32Đ S30S S33S S34S S35Đ S36Đ S38S S39S S40S S41S → R2
    test('12-29 cột ẩn có width', () {
      final res = _run(() => sh(cols: '<cols><col min="2" max="2" width="12" hidden="1"/></cols>'));
      expect(res, r'S|2x2|0,0=1|0,0-1,1|1:0.0||10.0/20.0|2,1|false');
    });
    // Đường: S1S S2S S3S S4Đ S5S S6S S8S S9S S10Đ S11S S12S S13S S14S S15Đ S16S S17S S18S S19S S22S S23S S24S S25S S26S S27S S28S S30Đ S31Đ S32S S30S S33Đ S35S → R2
    test('12-30 không có sheetViews', () {
      final res = _run(() => sh(pane: ''));
      expect(res, r'S|2x2|0,0=1|0,0-1,1|1:12.0||10.0/20.0|0,0|false');
    });
    // Đường: S1S S2S S3S S4Đ S5S S6S S8S S9S S10Đ S11S S12S S13S S14S S15Đ S16S S17S S18S S19S S22S S23S S24S S25S S26S S27S S28S S30Đ S31Đ S32S S30S S33S S34Đ S35S → R2
    test('12-31 sheetViews rỗng', () {
      final res = _run(() => sh(pane: '<sheetViews></sheetViews>'));
      expect(res, r'S|2x2|0,0=1|0,0-1,1|1:12.0||10.0/20.0|0,0|false');
    });
    // Đường: S1S S2S S3S S4Đ S5S S6S S8S S9S S10Đ S11S S12S S13S S14S S15Đ S16S S17S S18S S19S S22S S23S S24S S25S S26S S27S S28S S30Đ S31Đ S32S S30S S33S S34S S35S → R2
    test('12-32 sheetView không có pane', () {
      final res = _run(() => sh(pane: '<sheetViews><sheetView workbookViewId="0"/></sheetViews>'));
      expect(res, r'S|2x2|0,0=1|0,0-1,1|1:12.0||10.0/20.0|0,0|false');
    });
    // Đường: S1S S2S S3S S4Đ S5S S6S S8S S9S S10Đ S11S S12S S13S S14S S15Đ S16S S17S S18S S19S S22S S23S S24S S25S S26S S27S S28S S30Đ S31Đ S32S S30S S33S S34S S35Đ S36S S37S → R2
    test('12-33 pane state=split', () {
      final res = _run(() => sh(pane: '<sheetViews><sheetView workbookViewId="0"><pane xSplit="1" ySplit="2" state="split"/></sheetView></sheetViews>'));
      expect(res, r'S|2x2|0,0=1|0,0-1,1|1:12.0||10.0/20.0|0,0|false');
    });
    // Đường: S1S S2S S3S S4Đ S5S S6S S8S S9S S10Đ S11S S12S S13S S14S S15Đ S16S S17S S18S S19S S22S S23S S24S S25S S26S S27S S28S S30Đ S31Đ S32S S30S S33S S34S S35Đ S36Đ S38Đ S39Đ S40S S41S → R2
    test('12-34 frozen không có xSplit', () {
      final res = _run(() => sh(pane: '<sheetViews><sheetView workbookViewId="0"><pane ySplit="2" state="frozen"/></sheetView></sheetViews>'));
      expect(res, r'S|2x2|0,0=1|0,0-1,1|1:12.0||10.0/20.0|2,0|false');
    });
    // Đường: S1S S2S S3S S4Đ S5S S6S S8S S9S S10Đ S11S S12S S13S S14S S15Đ S16S S17S S18S S19S S22S S23S S24S S25S S26S S27S S28S S30Đ S31Đ S32S S30S S33S S34S S35Đ S36Đ S38S S39S S40Đ S41Đ → R2
    test('12-36 frozen không có ySplit', () {
      final res = _run(() => sh(pane: '<sheetViews><sheetView workbookViewId="0"><pane xSplit="1" state="frozen"/></sheetView></sheetViews>'));
      expect(res, r'S|2x2|0,0=1|0,0-1,1|1:12.0||10.0/20.0|0,1|false');
    });
    // Đường: S1S S2S S3S S4Đ S5S S6Đ S7S S8S S9S S10Đ S11S S12S S13S S14S S15Đ S16S S17S S18S S19S S22S S23S S24S S25S S26S S27S S28S S30Đ S31Đ S32S S30S S33S S34S S35Đ S36Đ S38S S39S S40S S41S → R2
    test('12-38 ht=30 customHeight=0', () {
      final res = _run(() => sh(row: '<row r="1" ht="30" customHeight="0">'));
      expect(res, r'S|2x2|0,0=1|0,0-1,1|1:12.0||10.0/20.0|2,1|false');
    });
    // Đường: S1S S2S S3S S4Đ S5S S6S S8S S9S S10Đ S11S S12S S13S S14S S15Đ S16S S17S S18S S19S S22S S23S S24S S25S S26S S27S S28Đ S29Đ S33S S34S S35Đ S36Đ S38S S39S S40S S41S → R2
    test('12-41 col không width, không ẩn', () {
      final res = _run(() => sh(cols: '<cols><col min="2" max="2"/></cols>'));
      expect(res, r'S|2x2|0,0=1|0,0-1,1|||10.0/20.0|2,1|false');
    });
    // Đường: S1S S2S S3S S4Đ S5S S6S S8S S9S S10Đ S11S S12S S13S S14S S15Đ S16S S17S S18S S19S S22S S23S S24S S25S S26S S27S S28S S30Đ S31Đ S32S S30S S33S S34S S35Đ S36S S37Đ S38S S39S S40S S41S → R2
    test('12-42 pane state=frozenSplit', () {
      final res = _run(() => sh(pane: '<sheetViews><sheetView workbookViewId="0"><pane xSplit="1" ySplit="2" state="frozenSplit"/></sheetView></sheetViews>'));
      expect(res, r'S|2x2|0,0=1|0,0-1,1|1:12.0||10.0/20.0|2,1|false');
    });
    // Đường: S4Đ với r = "0" (hàng < 1) → R2 (bổ sung) (bổ sung)
    test('12-b1 hàng r="0" có ô A1', () {
      final res = _run(() => nonNeg(sheetOf(row: '<row r="0">')));
      expect(res, isTrue);
    });
    // Đường: S26S với min = "0" (cột < 1) → R2 (bổ sung) (bổ sung)
    test('12-b2 col min="0" max="1" width="12"', () {
      final res = _run(() => nonNeg(sheetOf(cols: '<cols><col min="0" max="1" width="12"/></cols>')));
      expect(res, isTrue);
    });
  });
}
