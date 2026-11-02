// Kiểm thử hộp trắng (agent A17) cho lib/src/xlsx/xlsx_styles.dart.
// Sinh từ Bước 5 (test-output/whitebox/office-reader/xlsx_styles/buoc-5-du-lieu-thu.md).
// Expected chép từ Bước 5 — KHÔNG chỉnh cho khớp code. Tên test bắt đầu bằng mã bộ.
import 'package:office_reader/office_reader.dart';
import 'package:office_reader/src/xlsx/xlsx_styles.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';
Object? _run(Object? Function() f) {
  try {
    return f();
  } catch (e) {
    return e;
  }
}

XmlElement el(String xml) => XmlDocument.parse(xml).rootElement;
final dc = XlsxColors.parse(null); // bảng màu theme mặc định
XlsxStyles sty(String inner) => XlsxStyles(XmlDocument.parse('<styleSheet>$inner</styleSheet>'), dc);
int? col(String attrs) => dc.resolve(el('<color $attrs/>'));
XmlDocument theme(String scheme) => XmlDocument.parse('<a:theme xmlns:a="u"><a:themeElements>$scheme</a:themeElements></a:theme>');
const fontsDef = '<fonts><font><b/><i/><u/><strike/><sz val="11"/><color rgb="FFFF0000"/><name val="Arial"/></font></fonts>';
const fillsDef = '<fills><fill><patternFill patternType="solid"><fgColor rgb="FF00FF00"/></patternFill></fill></fills>';
const bordersDef = '<borders><border><left style="thin"/></border></borders>';
const numFmtsDef = '<numFmts><numFmt numFmtId="164" formatCode="0.000"/></numFmts>';
String xfs(String xf) => '<cellXfs>$xf</cellXfs>';
const xfDef = '<xf numFmtId="164" fontId="0" fillId="0" borderId="0"><alignment horizontal="center" vertical="top" wrapText="1" indent="2"/></xf>';
XlsxStyle st0({String numFmts = numFmtsDef, String fonts = fontsDef, String fills = fillsDef, String borders = bordersDef, String xf = xfDef}) =>
    sty(numFmts + fonts + fills + borders + xfs(xf)).xfs.first;
String sg(XlsxStyle s) => [s.numberFormat, s.bold, s.italic, s.underline, s.strike, s.fontSizePt, s.fontColorArgb?.toRadixString(16), s.fontFamily, s.fillArgb?.toRadixString(16), s.hasBorder, s.hAlign.name, s.vAlign.name, s.wrap, s.indent].join('|');
int st0Count() => sty(numFmtsDef + fontsDef + fillsDef + bordersDef).xfs.length;
String fill(String inner) => sty('<fills><fill>$inner</fill></fills>' + xfs('<xf fillId="0"/>')).xfs.first.fillArgb?.toRadixString(16) ?? 'null';

void main() {
  group('Đơn vị 1 — XlsxColors.parse', () {
    // Đường: D1S D2S D3S → R2
    test('1-1 theme có clrScheme đủ lt1 (sysClr FFFFFF) / accent1 srgb 112233', () {
      final res = _run(() => XlsxColors.parse(theme('<a:clrScheme><a:lt1><a:sysClr lastClr="FFFFFF"/></a:lt1><a:accent1><a:srgbClr val="112233"/></a:accent1></a:clrScheme>')).theme[4]);
      expect(res, 0xFF112233);
    });
    // Đường: D1Đ → R1
    test('1-2 themeDoc null', () {
      final res = _run(() => XlsxColors.parse(null).theme[4]);
      expect(res, 0xFF4472C4);
    });
    // Đường: D1S D2Đ → R1
    test('1-3 theme không có clrScheme', () {
      final res = _run(() => XlsxColors.parse(theme('<a:fontScheme/>')).theme[1]);
      expect(res, 0xFF000000);
    });
    // Đường: D1S D2S D3Đ → R2
    test('1-4 clrScheme thiếu accent2 ⇒ dùng mặc định', () {
      final res = _run(() => XlsxColors.parse(theme('<a:clrScheme><a:accent1><a:srgbClr val="112233"/></a:accent1></a:clrScheme>')).theme[5]);
      expect(res, 0xFFED7D31);
    });
  });
  group('Đơn vị 2 — XlsxColors.parse — col (hàm cục bộ)', () {
    // Đường: D1S D2S D3Đ → R2
    test('2-1 accent1 srgbClr 112233', () {
      final res = _run(() => XlsxColors.parse(theme('<a:clrScheme><a:accent1><a:srgbClr val="112233"/></a:accent1></a:clrScheme>')).theme[4]);
      expect(res, 0xFF112233);
    });
    // Đường: D1Đ → R1
    test('2-2 không có dk1 ⇒ mặc định', () {
      final res = _run(() => XlsxColors.parse(theme('<a:clrScheme/>')).theme[1]);
      expect(res, 0xFF000000);
    });
    // Đường: D1S D2Đ D3S D4S → R3
    test('2-3 dk1 chỉ có sysClr lastClr 222222', () {
      final res = _run(() => XlsxColors.parse(theme('<a:clrScheme><a:dk1><a:sysClr val="windowText" lastClr="222222"/></a:dk1></a:clrScheme>')).theme[1]);
      expect(res, 0xFF222222);
    });
    // Đường: D1S D2S D3S D4S → R3
    test('2-4 dk1 có srgbClr nhưng thiếu val ⇒ mặc định', () {
      final res = _run(() => XlsxColors.parse(theme('<a:clrScheme><a:dk1><a:srgbClr/></a:dk1></a:clrScheme>')).theme[1]);
      expect(res, 0xFF000000);
    });
    // Đường: D1S D2Đ D3S D4Đ → R3
    test('2-5 dk1 rỗng (không srgb, không sys) ⇒ mặc định', () {
      final res = _run(() => XlsxColors.parse(theme('<a:clrScheme><a:dk1/></a:clrScheme>')).theme[1]);
      expect(res, 0xFF000000);
    });
  });
  group('Đơn vị 3 — XlsxColors.resolve', () {
    // Đường: D1S D2S D3Đ D10S D11Đ → R2
    test('3-1 rgb FF1F4E79', () {
      final res = _run(() => col('rgb="FF1F4E79"'));
      expect(res, 0xFF1F4E79);
    });
    // Đường: D1Đ → R1
    test('3-2 e null', () {
      final res = _run(() => dc.resolve(null));
      expect(res, isNull);
    });
    // Đường: D1S D2Đ → R1
    test('3-3 auto="1"', () {
      final res = _run(() => col('auto="1" rgb="FF000000"'));
      expect(res, isNull);
    });
    // Đường: D1S D2S D3S D4S D7S D10Đ → R1
    test('3-4 <color/> không thuộc tính', () {
      final res = _run(() => col(''));
      expect(res, isNull);
    });
    // Đường: D1S D2S D3Đ D10Đ → R1
    test('3-5 rgb="zz" (không phải hex)', () {
      final res = _run(() => col('rgb="zz"'));
      expect(res, isNull);
    });
    // Đường: D1S D2S D3Đ D10S D11S D12S → R3
    test('3-6 rgb FFFFFFFF tint -0.5', () {
      final res = _run(() => col('rgb="FFFFFFFF" tint="-0.5"'));
      expect(res, 0xFF808080);
    });
    // Đường: D1S D2S D3S D4Đ D5Đ D6Đ D10S D11Đ → R2
    test('3-7 theme="4"', () {
      final res = _run(() => col('theme="4"'));
      expect(res, 0xFF4472C4);
    });
    // Đường: D1S D2S D3S D4S D7Đ D8Đ D9Đ D10S D11Đ → R2
    test('3-8 indexed="2"', () {
      final res = _run(() => col('indexed="2"'));
      expect(res, 0xFFFF0000);
    });
    // Đường: D1S D2S D3Đ D10S D11S D12Đ → R2
    test('3-9 rgb FF102030 tint 0', () {
      final res = _run(() => col('rgb="FF102030" tint="0"'));
      expect(res, 0xFF102030);
    });
    // Đường: D1S D2S D3S D4Đ D5S D10Đ → R1
    test('3-10 theme="-1"', () {
      final res = _run(() => col('theme="-1"'));
      expect(res, isNull);
    });
    // Đường: D1S D2S D3S D4Đ D5Đ D6S D10Đ → R1
    test('3-11 theme="12" (ngoài 0–11)', () {
      final res = _run(() => col('theme="12"'));
      expect(res, isNull);
    });
    // Đường: D1S D2S D3S D4S D7Đ D8S D10Đ → R1
    test('3-12 indexed="-1"', () {
      final res = _run(() => col('indexed="-1"'));
      expect(res, isNull);
    });
    // Đường: D1S D2S D3S D4S D7Đ D8Đ D9S D10Đ → R1
    test('3-13 indexed="64" (system foreground)', () {
      final res = _run(() => col('indexed="64"'));
      expect(res, isNull);
    });
  });
  group('Đơn vị 4 — resolve — ch (hàm cục bộ)', () {
    // Đường: D1S → R2
    test('4-1 rgb FF000000 tint 0.5', () {
      final res = _run(() => col('rgb="FF000000" tint="0.5"'));
      expect(res, 0xFF808080);
    });
    // Đường: D1Đ → R1
    test('4-2 rgb FFFFFFFF tint -0.25', () {
      final res = _run(() => col('rgb="FFFFFFFF" tint="-0.25"'));
      expect(res, 0xFFBFBFBF);
    });
  });
  group('Đơn vị 5 — XlsxStyles (constructor)', () {
    // Đường: D1S D2S D3S D4Đ D5Đ D6S D7S D8S D9S D10S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20S D21S D22S D23S D24S D25S D26S D27S D28S D29S D30S D31S D32S D33S D34S D35S D36S D37S → R2
    test('5-1 styles đủ: numFmt 164 = 0.000, font b/i/u/strike/11/đỏ/Arial, fill xanh, viền, xf 164/0/0/0 + alignment center/top/wrap/indent 2', () {
      final res = _run(() => sg(st0()));
      expect(res, '0.000|true|true|true|true|11.0|ffff0000|Arial|ff00ff00|true|center|top|true|2');
    });
    // Đường: D1Đ → R1
    test('5-2 XlsxStyles(null)', () {
      final res = _run(() => XlsxStyles(null, dc).xfs.length);
      expect(res, 0);
    });
    // Đường: D1S D2Đ D3Đ D6S D7S D8S D9S D10S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20S D21S D22S D23S D24S D25S D26S D27S D28S D29S D30S D31S D32S D33S D34S D35S D36S D37S → R2
    test('5-3 không có numFmts ⇒ id 164 không dựng sẵn', () {
      final res = _run(() => sg(st0(numFmts: '')));
      expect(res, 'General|true|true|true|true|11.0|ffff0000|Arial|ff00ff00|true|center|top|true|2');
    });
    // Đường: D1S D2S D3S D4S D6S D7S D8S D9S D10S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20S D21S D22S D23S D24S D25S D26S D27S D28S D29S D30S D31S D32S D33S D34S D35S D36S D37S → R2
    test('5-5 numFmt thiếu numFmtId', () {
      final res = _run(() => sg(st0(numFmts: '<numFmts><numFmt formatCode="0.000"/></numFmts>')));
      expect(res, 'General|true|true|true|true|11.0|ffff0000|Arial|ff00ff00|true|center|top|true|2');
    });
    // Đường: D1S D2S D3S D4Đ D5S D6S D7S D8S D9S D10S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20S D21S D22S D23S D24S D25S D26S D27S D28S D29S D30S D31S D32S D33S D34S D35S D36S D37S → R2
    test('5-6 numFmt thiếu formatCode', () {
      final res = _run(() => sg(st0(numFmts: '<numFmts><numFmt numFmtId="164"/></numFmts>')));
      expect(res, 'General|true|true|true|true|11.0|ffff0000|Arial|ff00ff00|true|center|top|true|2');
    });
    // Đường: D1S D2S D3S D4Đ D5Đ D6Đ D7Đ D10S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20S D21S D22S D23S D24S D25S D26S D27S D28S D29S D30S D31S D32S D33S D34S D35S D36S D37S → R2
    test('5-7 không có fonts', () {
      final res = _run(() => sg(st0(fonts: '')));
      expect(res, '0.000|false|false|false|false|null|null|null|ff00ff00|true|center|top|true|2');
    });
    // Đường: D1S D2S D3S D4Đ D5Đ D6S D7S D8Đ D9S D10S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20S D21S D22S D23S D24S D25S D26S D27S D28S D29S D30S D31S D32S D33S D34S D35S D36S D37S → R2
    test('5-9 font không có sz', () {
      final res = _run(() => sg(st0(fonts: '<fonts><font><b/><i/><u/><strike/><color rgb="FFFF0000"/><name val="Arial"/></font></fonts>')));
      expect(res, '0.000|true|true|true|true|null|ffff0000|Arial|ff00ff00|true|center|top|true|2');
    });
    // Đường: D1S D2S D3S D4Đ D5Đ D6S D7S D8S D9Đ D10S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20S D21S D22S D23S D24S D25S D26S D27S D28S D29S D30S D31S D32S D33S D34S D35S D36S D37S → R2
    test('5-10 font không có name', () {
      final res = _run(() => sg(st0(fonts: '<fonts><font><b/><i/><u/><strike/><sz val="11"/><color rgb="FFFF0000"/></font></fonts>')));
      expect(res, '0.000|true|true|true|true|11.0|ffff0000|null|ff00ff00|true|center|top|true|2');
    });
    // Đường: D1S D2S D3S D4Đ D5Đ D6S D7S D8S D9S D10Đ D11Đ D12S D13S D14S D15S D16S D17S D18S D19S D20S D21S D22S D23S D24S D25S D26S D27S D28S D29S D30S D31S D32S D33S D34S D35S D36S D37S → R2
    test('5-11 không có fills', () {
      final res = _run(() => sg(st0(fills: '')));
      expect(res, '0.000|true|true|true|true|11.0|ffff0000|Arial|null|true|center|top|true|2');
    });
    // Đường: D1S D2S D3S D4Đ D5Đ D6S D7S D8S D9S D10S D11S D12Đ D13Đ D14S D15S D16S D17S D18S D19S D20S D21S D22S D23S D24S D25S D26S D27S D28S D29S D30S D31S D32S D33S D34S D35S D36S D37S → R2
    test('5-13 không có borders', () {
      final res = _run(() => sg(st0(borders: '')));
      expect(res, '0.000|true|true|true|true|11.0|ffff0000|Arial|ff00ff00|false|center|top|true|2');
    });
    // Đường: D1S D2S D3S D4Đ D5Đ D6S D7S D8S D9S D10S D11S D12S D13S D14Đ D15Đ → R2
    test('5-15 không có cellXfs', () {
      final res = _run(() => st0Count());
      expect(res, 0);
    });
    // Đường: D1S D2S D3S D4Đ D5Đ D6S D7S D8S D9S D10S D11S D12S D13S D14S D15S D16Đ D17S D18S D19S D20S D21S D22S D23S D24S D25S D26S D27S D28S D29S D30S D31S D32S D33S D34S D35S D36S D37S → R2
    test('5-17 xf không có numFmtId ⇒ 0 (General)', () {
      final res = _run(() => sg(st0(xf: xfDef.replaceFirst(' numFmtId="164"', ''))));
      expect(res, 'General|true|true|true|true|11.0|ffff0000|Arial|ff00ff00|true|center|top|true|2');
    });
    // Đường: D1S D2S D3S D4Đ D5Đ D6S D7S D8S D9S D10S D11S D12S D13S D14S D15S D16S D17Đ D18S D19S D20S D21S D22S D23S D24S D25S D26S D27S D28S D29S D30S D31S D32S D33S D34S D35S D36S D37S → R2
    test('5-18 xf không có fontId ⇒ 0', () {
      final res = _run(() => sg(st0(xf: xfDef.replaceFirst(' fontId="0"', ''))));
      expect(res, '0.000|true|true|true|true|11.0|ffff0000|Arial|ff00ff00|true|center|top|true|2');
    });
    // Đường: D1S D2S D3S D4Đ D5Đ D6S D7S D8S D9S D10S D11S D12S D13S D14S D15S D16S D17S D18Đ D19S D20S D21S D22S D23S D24S D25S D26S D27S D28S D29S D30S D31S D32S D33S D34S D35S D36S D37S → R2
    test('5-19 xf không có fillId ⇒ 0', () {
      final res = _run(() => sg(st0(xf: xfDef.replaceFirst(' fillId="0"', ''))));
      expect(res, '0.000|true|true|true|true|11.0|ffff0000|Arial|ff00ff00|true|center|top|true|2');
    });
    // Đường: D1S D2S D3S D4Đ D5Đ D6S D7S D8S D9S D10S D11S D12S D13S D14S D15S D16S D17S D18S D19Đ D20S D21S D22S D23S D24S D25S D26S D27S D28S D29S D30S D31S D32S D33S D34S D35S D36S D37S → R2
    test('5-20 xf không có borderId ⇒ 0', () {
      final res = _run(() => sg(st0(xf: xfDef.replaceFirst(' borderId="0"', ''))));
      expect(res, '0.000|true|true|true|true|11.0|ffff0000|Arial|ff00ff00|true|center|top|true|2');
    });
    // Đường: D1S D2S D3S D4Đ D5Đ D6S D7S D8S D9S D10S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20Đ D21S D22S D23S D24S D25S D26S D27S D28S D29S D30S D31S D32S D33S D34S D35S D36S D37S → R2
    test('5-21 borderId 5 (ngoài danh sách)', () {
      final res = _run(() => sg(st0(xf: xfDef.replaceFirst('borderId="0"', 'borderId="5"'))));
      expect(res, '0.000|true|true|true|true|11.0|ffff0000|Arial|ff00ff00|false|center|top|true|2');
    });
    // Đường: D1S D2S D3S D4Đ D5Đ D6S D7S D8S D9S D10S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20S D21Đ D22Đ D23Đ D24Đ D25Đ D26Đ D27Đ D28Đ D29Đ D30Đ D31Đ D32S D33S D34S D35S D36S D37S → R2
    test('5-22 fontId 5 (ngoài danh sách)', () {
      final res = _run(() => sg(st0(xf: xfDef.replaceFirst('fontId="0"', 'fontId="5"'))));
      expect(res, '0.000|false|false|false|false|null|null|null|ff00ff00|true|center|top|true|2');
    });
    // Đường: D1S D2S D3S D4Đ D5Đ D6S D7S D8S D9S D10S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20S D21S D22S D23S D24S D25S D26S D27S D28S D29S D30S D31S D32Đ D33Đ D34Đ D35Đ D36Đ D37S → R2
    test('5-33 xf không có alignment', () {
      final res = _run(() => sg(st0(xf: '<xf numFmtId="164" fontId="0" fillId="0" borderId="0"/>')));
      expect(res, '0.000|true|true|true|true|11.0|ffff0000|Arial|ff00ff00|true|general|bottom|false|0');
    });
    // Đường: D1S D2S D3S D4Đ D5Đ D6S D7S D8S D9S D10S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20S D21S D22S D23S D24S D25S D26S D27S D28S D29S D30S D31S D32S D33S D34S D35S D36Đ D37S → R2
    test('5-37 alignment không có indent', () {
      final res = _run(() => sg(st0(xf: xfDef.replaceFirst(' indent="2"', ''))));
      expect(res, '0.000|true|true|true|true|11.0|ffff0000|Arial|ff00ff00|true|center|top|true|0');
    });
    // Đường: D1S D2S D3S D4Đ D5Đ D6S D7S D8S D9S D10S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20S D21S D22S D23S D24S D25S D26S D27S D28S D29S D30S D31S D32S D33S D34S D35S D36S D37Đ → R2
    test('5-38 numFmtId 2 (dựng sẵn, không có trong numFmts)', () {
      final res = _run(() => sg(st0(xf: xfDef.replaceFirst('numFmtId="164"', 'numFmtId="2"'))));
      expect(res, '0.00|true|true|true|true|11.0|ffff0000|Arial|ff00ff00|true|center|top|true|2');
    });
  });
  group('Đơn vị 6 — XlsxStyles — flag (hàm cục bộ)', () {
    // Đường: D1S D2S → R3
    test('6-1 font <b val="0"/>', () {
      final res = _run(() => st0(fonts: '<fonts><font><b val="0"/></font></fonts>').bold);
      expect(res, isFalse);
    });
    // Đường: D1Đ → R1
    test('6-2 font không có <b/>', () {
      final res = _run(() => st0(fonts: '<fonts><font/></fonts>').bold);
      expect(res, isFalse);
    });
    // Đường: D1S D2Đ D3S → R2
    test('6-3 font <u val="none"/>', () {
      final res = _run(() => st0(fonts: '<fonts><font><u val="none"/></font></fonts>').underline);
      expect(res, isFalse);
    });
    // Đường: D1S D2Đ D3Đ → R2
    test('6-4 font <u/> không val', () {
      final res = _run(() => st0(fonts: '<fonts><font><u/></font></fonts>').underline);
      expect(res, isTrue);
    });
  });
  group('Đơn vị 7 — XlsxStyles — viền (lambda any)', () {
    // Đường: D1S D2Đ D3Đ → R2
    test('7-1 border left style thin', () {
      final res = _run(() => st0().hasBorder);
      expect(res, isTrue);
    });
    // Đường: D1Đ D2S → R1
    test('7-2 border rỗng', () {
      final res = _run(() => st0(borders: '<borders><border/></borders>').hasBorder);
      expect(res, isFalse);
    });
    // Đường: D1S D2S → R1
    test('7-3 left không có style', () {
      final res = _run(() => st0(borders: '<borders><border><left/></border></borders>').hasBorder);
      expect(res, isFalse);
    });
    // Đường: D1S D2Đ D3S → R1
    test('7-4 left style none', () {
      final res = _run(() => st0(borders: '<borders><border><left style="none"/></border></borders>').hasBorder);
      expect(res, isFalse);
    });
  });
  group('Đơn vị 8 — XlsxStyles._at', () {
    // Đường: D1Đ D2Đ → R2
    test('8-1 fontId 0 (có)', () {
      final res = _run(() => st0().fontFamily);
      expect(res, 'Arial');
    });
    // Đường: D1S → R1
    test('8-2 fontId -1', () {
      final res = _run(() => st0(xf: '<xf fontId="-1"/>').fontFamily);
      expect(res, isNull);
    });
    // Đường: D1Đ D2S → R1
    test('8-3 fontId 5 (ngoài danh sách)', () {
      final res = _run(() => st0(xf: '<xf fontId="5"/>').fontFamily);
      expect(res, isNull);
    });
  });
  group('Đơn vị 9 — XlsxStyles._fill', () {
    // Đường: D1Đ D2S D4S D5S D6S D7S → R2
    test('9-1 patternFill solid fg 00FF00', () {
      final res = _run(() => fill('<patternFill patternType="solid"><fgColor rgb="FF00FF00"/></patternFill>'));
      expect(res, 'ff00ff00');
    });
    // Đường: D1S D8S → R1
    test('9-2 không có patternFill, không gradient', () {
      final res = _run(() => fill(''));
      expect(res, 'null');
    });
    // Đường: D1Đ D2Đ D3S D4Đ → R1
    test('9-3 patternFill không patternType, không fgColor', () {
      final res = _run(() => fill('<patternFill/>'));
      expect(res, 'null');
    });
    // Đường: D1Đ D2S D4Đ → R1
    test('9-4 patternType none', () {
      final res = _run(() => fill('<patternFill patternType="none"/>'));
      expect(res, 'null');
    });
    // Đường: D1Đ D2S D4S D5Đ → R1
    test('9-5 patternType gray125', () {
      final res = _run(() => fill('<patternFill patternType="gray125"/>'));
      expect(res, 'null');
    });
    // Đường: D1Đ D2S D4S D5S D6Đ → R1
    test('9-6 patternType gray0625', () {
      final res = _run(() => fill('<patternFill patternType="gray0625"><fgColor rgb="FF00FF00"/></patternFill>'));
      expect(res, 'null');
    });
    // Đường: D1Đ D2S D4S D5S D6S D7Đ → R2
    test('9-7 solid chỉ có bgColor', () {
      final res = _run(() => fill('<patternFill patternType="solid"><bgColor rgb="FF123456"/></patternFill>'));
      expect(res, 'ff123456');
    });
    // Đường: D1S D8Đ → R3
    test('9-8 gradientFill stop đầu FF0000', () {
      final res = _run(() => fill('<gradientFill><stop position="0"><color rgb="FFFF0000"/></stop><stop position="1"><color rgb="FF0000FF"/></stop></gradientFill>'));
      expect(res, 'ffff0000');
    });
    // Đường: D1Đ D2Đ D3Đ D4S D5S D6S D7S → R2
    test('9-9 patternFill không patternType, có fgColor', () {
      final res = _run(() => fill('<patternFill><fgColor rgb="FF0000FF"/></patternFill>'));
      expect(res, 'ff0000ff');
    });
  });
  group('Đơn vị 10 — XlsxStyles._h', () {
    // Đường: D1S D2S D3S D4S D5S D6S D7S → R8
    test('10-1 horizontal general', () {
      final res = _run(() => st0(xf: '<xf><alignment horizontal="general"/></xf>').hAlign);
      expect(res, XlsxHAlign.general);
    });
    // Đường: D1Đ → R1
    test('10-2 horizontal left', () {
      final res = _run(() => st0(xf: '<xf><alignment horizontal="left"/></xf>').hAlign);
      expect(res, XlsxHAlign.left);
    });
    // Đường: D1S D2Đ → R2
    test('10-3 horizontal center', () {
      final res = _run(() => st0(xf: '<xf><alignment horizontal="center"/></xf>').hAlign);
      expect(res, XlsxHAlign.center);
    });
    // Đường: D1S D2S D3Đ → R3
    test('10-4 horizontal right', () {
      final res = _run(() => st0(xf: '<xf><alignment horizontal="right"/></xf>').hAlign);
      expect(res, XlsxHAlign.right);
    });
    // Đường: D1S D2S D3S D4Đ → R4
    test('10-5 horizontal justify', () {
      final res = _run(() => st0(xf: '<xf><alignment horizontal="justify"/></xf>').hAlign);
      expect(res, XlsxHAlign.justify);
    });
    // Đường: D1S D2S D3S D4S D5Đ → R5
    test('10-6 horizontal fill', () {
      final res = _run(() => st0(xf: '<xf><alignment horizontal="fill"/></xf>').hAlign);
      expect(res, XlsxHAlign.fill);
    });
    // Đường: D1S D2S D3S D4S D5S D6Đ → R6
    test('10-7 horizontal centerContinuous', () {
      final res = _run(() => st0(xf: '<xf><alignment horizontal="centerContinuous"/></xf>').hAlign);
      expect(res, XlsxHAlign.centerContinuous);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7Đ → R7
    test('10-8 horizontal distributed', () {
      final res = _run(() => st0(xf: '<xf><alignment horizontal="distributed"/></xf>').hAlign);
      expect(res, XlsxHAlign.distributed);
    });
  });
  group('Đơn vị 11 — XlsxStyles._v', () {
    // Đường: D1S D2S D3S D4S → R5
    test('11-1 vertical bottom', () {
      final res = _run(() => st0(xf: '<xf><alignment vertical="bottom"/></xf>').vAlign);
      expect(res, XlsxVAlign.bottom);
    });
    // Đường: D1Đ → R1
    test('11-2 vertical top', () {
      final res = _run(() => st0(xf: '<xf><alignment vertical="top"/></xf>').vAlign);
      expect(res, XlsxVAlign.top);
    });
    // Đường: D1S D2Đ → R2
    test('11-3 vertical center', () {
      final res = _run(() => st0(xf: '<xf><alignment vertical="center"/></xf>').vAlign);
      expect(res, XlsxVAlign.center);
    });
    // Đường: D1S D2S D3Đ → R3
    test('11-4 vertical justify', () {
      final res = _run(() => st0(xf: '<xf><alignment vertical="justify"/></xf>').vAlign);
      expect(res, XlsxVAlign.justify);
    });
    // Đường: D1S D2S D3S D4Đ → R4
    test('11-5 vertical distributed', () {
      final res = _run(() => st0(xf: '<xf><alignment vertical="distributed"/></xf>').vAlign);
      expect(res, XlsxVAlign.distributed);
    });
  });
  group('Đơn vị 12 — XlsxStyles.at', () {
    // Đường: D1S D2S D3S → R1
    test('12-1 at(1) với 2 xf (xf 1 đậm)', () {
      final res = _run(() => sty('<fonts><font/><font><b/></font></fonts>' + xfs('<xf fontId="0"/><xf fontId="1"/>')).at(1).bold);
      expect(res, isTrue);
    });
    // Đường: D1Đ D4Đ → R2
    test('12-2 at(null) ⇒ xf đầu', () {
      final res = _run(() => sty('<fonts><font><b/></font></fonts>' + xfs('<xf fontId="0"/>')).at(null).bold);
      expect(res, isTrue);
    });
    // Đường: D1S D2Đ D4Đ → R2
    test('12-3 at(-1)', () {
      final res = _run(() => sty('<fonts><font><b/></font></fonts>' + xfs('<xf fontId="0"/>')).at(-1).bold);
      expect(res, isTrue);
    });
    // Đường: D1S D2S D3Đ D4Đ → R2
    test('12-4 at(9) ngoài danh sách', () {
      final res = _run(() => sty('<fonts><font><b/></font></fonts>' + xfs('<xf fontId="0"/>')).at(9).bold);
      expect(res, isTrue);
    });
    // Đường: D1Đ D4S → R3
    test('12-5 xfs rỗng ⇒ plain', () {
      final res = _run(() => XlsxStyles(null, dc).at(null).numberFormat);
      expect(res, 'General');
    });
  });
}
