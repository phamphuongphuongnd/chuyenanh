// Kiểm thử hộp trắng (agent A17) cho lib/src/docx/docx_styles.dart.
// Sinh từ Bước 5 (test-output/whitebox/office-reader/docx_styles/buoc-5-du-lieu-thu.md).
// Expected chép từ Bước 5 — KHÔNG chỉnh cho khớp code. Tên test bắt đầu bằng mã bộ.
import 'package:office_reader/src/docx/docx_styles.dart';
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
const th = ThemeFonts(major: 'Cambria', minor: 'Calibri');
RunProps rp(String inner) => RunProps.parse(el('<w:rPr xmlns:w="u">$inner</w:rPr>'), th);
ParaProps pp(String inner) => ParaProps.parse(el('<w:pPr xmlns:w="u">$inner</w:pPr>'));
XmlDocument stylesDoc(String inner) => XmlDocument.parse('<w:styles xmlns:w="u">$inner</w:styles>');
DocxStyles st(String inner) => DocxStyles(stylesDoc(inner), th);
const rpA = RunProps(bold: false, italic: false, underline: false, strike: false, superscript: false, subscript: false, hidden: false, caps: false, smallCaps: false, sizePt: 10, color: 1, highlight: 2, font: 'A', charStyle: 'cA');
Map<String, Object?> rpMap(RunProps r) => {'bold': r.bold, 'italic': r.italic, 'underline': r.underline, 'strike': r.strike, 'superscript': r.superscript, 'subscript': r.subscript, 'hidden': r.hidden, 'caps': r.caps, 'smallCaps': r.smallCaps, 'sizePt': r.sizePt, 'color': r.color, 'highlight': r.highlight, 'font': r.font, 'charStyle': r.charStyle};
/// o = mọi trường khác null (giá trị khác rpA); [nul] = các trường để null; [clear] = clearHighlight.
RunProps rpO({Set<String> nul = const {}, bool clear = false}) {
  T? v<T>(String k, T x) => nul.contains(k) ? null : x;
  return RunProps(bold: v('bold', true), italic: v('italic', true), underline: v('underline', true), strike: v('strike', true), superscript: v('superscript', true), subscript: v('subscript', true), hidden: v('hidden', true), caps: v('caps', true), smallCaps: v('smallCaps', true), sizePt: v('sizePt', 20.0), color: v('color', 9), highlight: v('highlight', 8), clearHighlight: clear, font: v('font', 'B'), charStyle: v('charStyle', 'cB'));
}
const ppA = ParaProps(jc: 'left', indLeft: 1, indRight: 1, firstLine: 1, before: 1, after: 1, line: 1, numId: 1, ilvl: 1, outlineLvl: 1, pageBreakBefore: false);
Map<String, Object?> ppMap(ParaProps p) => {'jc': p.jc, 'indLeft': p.indLeft, 'indRight': p.indRight, 'firstLine': p.firstLine, 'before': p.before, 'after': p.after, 'line': p.line, 'numId': p.numId, 'ilvl': p.ilvl, 'outlineLvl': p.outlineLvl, 'pageBreakBefore': p.pageBreakBefore};
ParaProps ppO({Set<String> nul = const {}}) {
  T? v<T>(String k, T x) => nul.contains(k) ? null : x;
  return ParaProps(jc: v('jc', 'center'), indLeft: v('indLeft', 2.0), indRight: v('indRight', 2.0), firstLine: v('firstLine', 2.0), before: v('before', 2.0), after: v('after', 2.0), line: v('line', 2.0), numId: v('numId', 2), ilvl: v('ilvl', 2), outlineLvl: v('outlineLvl', 2), pageBreakBefore: v('pageBreakBefore', true));
}

void main() {
  group('Đơn vị 1 — RunProps.merge', () {
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10S D11S D12S D13S D14S D15S → R1
    test('1-1 rpA.merge(o) — o có mọi trường', () {
      final res = _run(() => rpMap(rpA.merge(rpO())));
      expect(res, equals(rpMap(rpO())));
    });
    // Đường: D1Đ D2S D3S D4S D5S D6S D7S D8S D9S D10S D11S D12S D13S D14S D15S → R1
    test('1-2 o.bold = null', () {
      final res = _run(() => rpMap(rpA.merge(rpO(nul: {'bold'})))['bold']);
      expect(res, false);
    });
    // Đường: D1S D2Đ D3S D4S D5S D6S D7S D8S D9S D10S D11S D12S D13S D14S D15S → R1
    test('1-3 o.italic = null', () {
      final res = _run(() => rpMap(rpA.merge(rpO(nul: {'italic'})))['italic']);
      expect(res, false);
    });
    // Đường: D1S D2S D3Đ D4S D5S D6S D7S D8S D9S D10S D11S D12S D13S D14S D15S → R1
    test('1-4 o.underline = null', () {
      final res = _run(() => rpMap(rpA.merge(rpO(nul: {'underline'})))['underline']);
      expect(res, false);
    });
    // Đường: D1S D2S D3S D4Đ D5S D6S D7S D8S D9S D10S D11S D12S D13S D14S D15S → R1
    test('1-5 o.strike = null', () {
      final res = _run(() => rpMap(rpA.merge(rpO(nul: {'strike'})))['strike']);
      expect(res, false);
    });
    // Đường: D1S D2S D3S D4S D5Đ D6S D7S D8S D9S D10S D11S D12S D13S D14S D15S → R1
    test('1-6 o.superscript = null', () {
      final res = _run(() => rpMap(rpA.merge(rpO(nul: {'superscript'})))['superscript']);
      expect(res, false);
    });
    // Đường: D1S D2S D3S D4S D5S D6Đ D7S D8S D9S D10S D11S D12S D13S D14S D15S → R1
    test('1-7 o.subscript = null', () {
      final res = _run(() => rpMap(rpA.merge(rpO(nul: {'subscript'})))['subscript']);
      expect(res, false);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7Đ D8S D9S D10S D11S D12S D13S D14S D15S → R1
    test('1-8 o.hidden = null', () {
      final res = _run(() => rpMap(rpA.merge(rpO(nul: {'hidden'})))['hidden']);
      expect(res, false);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8Đ D9S D10S D11S D12S D13S D14S D15S → R1
    test('1-9 o.caps = null', () {
      final res = _run(() => rpMap(rpA.merge(rpO(nul: {'caps'})))['caps']);
      expect(res, false);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9Đ D10S D11S D12S D13S D14S D15S → R1
    test('1-10 o.smallCaps = null', () {
      final res = _run(() => rpMap(rpA.merge(rpO(nul: {'smallCaps'})))['smallCaps']);
      expect(res, false);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10Đ D11S D12S D13S D14S D15S → R1
    test('1-11 o.sizePt = null', () {
      final res = _run(() => rpMap(rpA.merge(rpO(nul: {'sizePt'})))['sizePt']);
      expect(res, 10.0);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10S D11Đ D12S D13S D14S D15S → R1
    test('1-12 o.color = null', () {
      final res = _run(() => rpMap(rpA.merge(rpO(nul: {'color'})))['color']);
      expect(res, 1);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10S D11S D12Đ D14S D15S → R1
    test('1-13 o.clearHighlight = true', () {
      final res = _run(() => rpA.merge(rpO(clear: true)).highlight);
      expect(res, isNull);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10S D11S D12S D13Đ D14S D15S → R1
    test('1-14 o.highlight = null', () {
      final res = _run(() => rpA.merge(rpO(nul: {'highlight'})).highlight);
      expect(res, 2);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10S D11S D12S D13S D14Đ D15S → R1
    test('1-15 o.font = null', () {
      final res = _run(() => rpA.merge(rpO(nul: {'font'})).font);
      expect(res, 'A');
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10S D11S D12S D13S D14S D15Đ → R1
    test('1-16 o.charStyle = null', () {
      final res = _run(() => rpA.merge(rpO(nul: {'charStyle'})).charStyle);
      expect(res, 'cA');
    });
  });
  group('Đơn vị 2 — RunProps.parse', () {
    // Đường: D1S D2S D3S D5S D6S D8S D9S D10S D11S D12S D13S D14S → R2
    test('2-1 rPr: shd không fill, u double, vertAlign superscript, sz 24, color FF0000', () {
      final res = _run(() => (() { final r = rp('<w:shd w:val="clear"/><w:u w:val="double"/><w:vertAlign w:val="superscript"/><w:sz w:val="24"/><w:color w:val="FF0000"/>'); return (r.strike, r.highlight, r.underline, r.superscript, r.subscript, r.sizePt, r.color); })());
      expect(res, equals((null, null, true, true, false, 12.0, 0xFFFF0000)));
    });
    // Đường: D1Đ → R1
    test('2-2 rPr = null', () {
      final res = _run(() => rpMap(RunProps.parse(null, th)).values.whereType<Object>().isEmpty);
      expect(res, isTrue);
    });
    // Đường: D1S D2Đ D3S D5S D6S D8S D9S D10S D11S D12S D13S D14S → R2
    test('2-3 + <w:dstrike/>', () {
      final res = _run(() => rp('<w:dstrike/><w:shd w:val="clear"/><w:u w:val="double"/><w:vertAlign w:val="superscript"/><w:sz w:val="24"/><w:color w:val="FF0000"/>').strike);
      expect(res, isTrue);
    });
    // Đường: D1S D2S D3Đ D4S D8S D9S D10S D11S D12S D13S D14S → R2
    test('2-4 highlight yellow', () {
      final res = _run(() => rp('<w:highlight w:val="yellow"/>').highlight);
      expect(res, 0xFFFFFF00);
    });
    // Đường: D1S D2S D3S D5Đ D6S D8S D9S D10S D11S D12S D13S D14S → R2
    test('2-5 không có shd, không highlight', () {
      final res = _run(() => rp('<w:b/>').highlight);
      expect(res, isNull);
    });
    // Đường: D1S D2S D3S D5S D6Đ D7Đ D8S D9S D10S D11S D12S D13S D14S → R2
    test('2-6 shd fill 00FF00', () {
      final res = _run(() => rp('<w:shd w:val="clear" w:fill="00FF00"/>').highlight);
      expect(res, 0xFF00FF00);
    });
    // Đường: D1S D2S D3S D5S D6S D8Đ D10S D11S D12S D13S D14S → R2
    test('2-7 không có w:u', () {
      final res = _run(() => rp('<w:b/>').underline);
      expect(res, isNull);
    });
    // Đường: D1S D2S D3S D5S D6S D8S D9Đ D10S D11S D12S D13S D14S → R2
    test('2-8 <w:u/> không có val', () {
      final res = _run(() => rp('<w:u/>').underline);
      expect(res, isTrue);
    });
    // Đường: D1S D2S D3S D5S D6S D8S D9S D10Đ D11Đ D12S D13S D14S → R2
    test('2-9 không có vertAlign', () {
      final res = _run(() => (() { final r = rp('<w:b/>'); return (r.superscript, r.subscript); })());
      expect(res, equals((null, null)));
    });
    // Đường: D1S D2S D3S D5S D6S D8S D9S D10S D11S D12Đ D13S D14S → R2
    test('2-11 không có sz', () {
      final res = _run(() => rp('<w:b/>').sizePt);
      expect(res, isNull);
    });
    // Đường: D1S D2S D3S D5S D6S D8S D9S D10S D11S D12S D13Đ → R2
    test('2-12 không có color', () {
      final res = _run(() => rp('<w:b/>').color);
      expect(res, isNull);
    });
    // Đường: D1S D2S D3S D5S D6S D8S D9S D10S D11S D12S D13S D14Đ → R2
    test('2-13 color auto', () {
      final res = _run(() => rp('<w:color w:val="auto"/>').color);
      expect(res, isNull);
    });
    // Đường: D1S D2S D3Đ D4Đ D8S D9S D10S D11S D12S D13S D14S → R2
    test('2-14 highlight none', () {
      final res = _run(() => (() { final r = rp('<w:highlight w:val="none"/>'); return (r.highlight, r.clearHighlight); })());
      expect(res, equals((null, true)));
    });
    // Đường: D1S D2S D3S D5S D6Đ D7S D8S D9S D10S D11S D12S D13S D14S → R2
    test('2-15 shd fill auto', () {
      final res = _run(() => rp('<w:shd w:val="clear" w:fill="auto"/>').highlight);
      expect(res, isNull);
    });
  });
  group('Đơn vị 3 — RunProps.parse — toggle (hàm cục bộ)', () {
    // Đường: D1S → R2
    test('3-1 <w:b w:val="0"/>', () {
      final res = _run(() => rp('<w:b w:val="0"/>').bold);
      expect(res, isFalse);
    });
    // Đường: D1Đ → R1
    test('3-2 không có w:b', () {
      final res = _run(() => rp('<w:i/>').bold);
      expect(res, isNull);
    });
  });
  group('Đơn vị 4 — RunProps._font', () {
    // Đường: D1S D2Đ D3Đ → R2
    test('4-1 rFonts ascii Arial', () {
      final res = _run(() => rp('<w:rFonts w:ascii="Arial"/>').font);
      expect(res, 'Arial');
    });
    // Đường: D1Đ → R1
    test('4-2 không có rFonts', () {
      final res = _run(() => rp('<w:b/>').font);
      expect(res, isNull);
    });
    // Đường: D1S D2S D4S D5S D6Đ → R4
    test('4-3 rFonts asciiTheme minorHAnsi', () {
      final res = _run(() => rp('<w:rFonts w:asciiTheme="minorHAnsi"/>').font);
      expect(res, 'Calibri');
    });
    // Đường: D1S D2Đ D3S D4S D5S D6Đ → R4
    test('4-4 rFonts ascii="" + asciiTheme minorHAnsi', () {
      final res = _run(() => rp('<w:rFonts w:ascii="" w:asciiTheme="minorHAnsi"/>').font);
      expect(res, 'Calibri');
    });
    // Đường: D1S D2S D4Đ → R3
    test('4-5 rFonts chỉ có w:hint', () {
      final res = _run(() => rp('<w:rFonts w:hint="eastAsia"/>').font);
      expect(res, isNull);
    });
    // Đường: D1S D2S D4S D5Đ D6Đ → R4
    test('4-6 rFonts asciiTheme majorHAnsi', () {
      final res = _run(() => rp('<w:rFonts w:asciiTheme="majorHAnsi"/>').font);
      expect(res, 'Cambria');
    });
    // Đường: D1S D2S D4S D5S D6S → R3
    test('4-7 asciiTheme minorHAnsi nhưng theme không có font', () {
      final res = _run(() => RunProps.parse(el('<w:rPr xmlns:w="u"><w:rFonts w:asciiTheme="minorHAnsi"/></w:rPr>'), const ThemeFonts()).font);
      expect(res, isNull);
    });
  });
  group('Đơn vị 5 — ParaProps.merge', () {
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10S D11S → R1
    test('5-1 ppA.merge(o) — o có mọi trường', () {
      final res = _run(() => ppMap(ppA.merge(ppO())));
      expect(res, equals(ppMap(ppO())));
    });
    // Đường: D1Đ D2S D3S D4S D5S D6S D7S D8S D9S D10S D11S → R1
    test('5-2 o.jc = null', () {
      final res = _run(() => ppMap(ppA.merge(ppO(nul: {'jc'})))['jc']);
      expect(res, 'left');
    });
    // Đường: D1S D2Đ D3S D4S D5S D6S D7S D8S D9S D10S D11S → R1
    test('5-3 o.indLeft = null', () {
      final res = _run(() => ppMap(ppA.merge(ppO(nul: {'indLeft'})))['indLeft']);
      expect(res, 1.0);
    });
    // Đường: D1S D2S D3Đ D4S D5S D6S D7S D8S D9S D10S D11S → R1
    test('5-4 o.indRight = null', () {
      final res = _run(() => ppMap(ppA.merge(ppO(nul: {'indRight'})))['indRight']);
      expect(res, 1.0);
    });
    // Đường: D1S D2S D3S D4Đ D5S D6S D7S D8S D9S D10S D11S → R1
    test('5-5 o.firstLine = null', () {
      final res = _run(() => ppMap(ppA.merge(ppO(nul: {'firstLine'})))['firstLine']);
      expect(res, 1.0);
    });
    // Đường: D1S D2S D3S D4S D5Đ D6S D7S D8S D9S D10S D11S → R1
    test('5-6 o.before = null', () {
      final res = _run(() => ppMap(ppA.merge(ppO(nul: {'before'})))['before']);
      expect(res, 1.0);
    });
    // Đường: D1S D2S D3S D4S D5S D6Đ D7S D8S D9S D10S D11S → R1
    test('5-7 o.after = null', () {
      final res = _run(() => ppMap(ppA.merge(ppO(nul: {'after'})))['after']);
      expect(res, 1.0);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7Đ D8S D9S D10S D11S → R1
    test('5-8 o.line = null', () {
      final res = _run(() => ppMap(ppA.merge(ppO(nul: {'line'})))['line']);
      expect(res, 1.0);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8Đ D9S D10S D11S → R1
    test('5-9 o.numId = null', () {
      final res = _run(() => ppMap(ppA.merge(ppO(nul: {'numId'})))['numId']);
      expect(res, 1);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9Đ D10S D11S → R1
    test('5-10 o.ilvl = null', () {
      final res = _run(() => ppMap(ppA.merge(ppO(nul: {'ilvl'})))['ilvl']);
      expect(res, 1);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10Đ D11S → R1
    test('5-11 o.outlineLvl = null', () {
      final res = _run(() => ppMap(ppA.merge(ppO(nul: {'outlineLvl'})))['outlineLvl']);
      expect(res, 1);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10S D11Đ → R1
    test('5-12 o.pageBreakBefore = null', () {
      final res = _run(() => ppMap(ppA.merge(ppO(nul: {'pageBreakBefore'})))['pageBreakBefore']);
      expect(res, false);
    });
  });
  group('Đơn vị 6 — ParaProps.parse', () {
    // Đường: D1S D2Đ D3S D4Đ D5S D6Đ D7Đ D8S D9S D10S D11S D12S D13S D14S D15S D16S → R2
    test('6-1 pPr đủ: jc center, ind 720/360/firstLine 240, spacing 120/240/line 360 auto, numPr 3/1, outlineLvl 2, pageBreakBefore', () {
      final res = _run(() => ppMap(pp('<w:jc w:val="center"/><w:ind w:left="720" w:right="360" w:firstLine="240"/><w:spacing w:before="120" w:after="240" w:line="360" w:lineRule="auto"/><w:numPr><w:ilvl w:val="1"/><w:numId w:val="3"/></w:numPr><w:outlineLvl w:val="2"/><w:pageBreakBefore/>')));
      expect(res, equals({'jc': 'center', 'indLeft': 36.0, 'indRight': 18.0, 'firstLine': 12.0, 'before': 6.0, 'after': 12.0, 'line': 1.5, 'numId': 3, 'ilvl': 1, 'outlineLvl': 2, 'pageBreakBefore': true}));
    });
    // Đường: D1Đ → R1
    test('6-2 pPr = null', () {
      final res = _run(() => ppMap(ParaProps.parse(null)).values.whereType<Object>().isEmpty);
      expect(res, isTrue);
    });
    // Đường: D1S D2S D4Đ D5S D6Đ D7Đ D8Đ D10Đ D12S D13S D14S D15S D16S → R2
    test('6-3 như 6-1 nhưng không có w:ind', () {
      final res = _run(() => (() { final m = ppMap(pp('<w:jc w:val="center"/><w:spacing w:before="120" w:after="240" w:line="360" w:lineRule="auto"/><w:numPr><w:ilvl w:val="1"/><w:numId w:val="3"/></w:numPr><w:outlineLvl w:val="2"/><w:pageBreakBefore/>')); return (m['indLeft'], m['indRight'], m['firstLine'], m['before']); })());
      expect(res, equals((null, null, null, 6.0)));
    });
    // Đường: D1S D2Đ D3Đ D4Đ D5S D6Đ D7Đ D8S D9S D10S D11S D12S D13S D14S D15S D16S → R2
    test('6-4 ind hanging 360', () {
      final res = _run(() => ppMap(pp('<w:ind w:left="720" w:hanging="360"/>'))['firstLine']);
      expect(res, -18.0);
    });
    // Đường: D1S D2Đ D3S D4S D8S D9S D10S D11S D12Đ D13Đ D14S D15S D16S → R2
    test('6-5 không có w:spacing', () {
      final res = _run(() => (() { final m = ppMap(pp('<w:ind w:left="720"/>')); return (m['before'], m['after'], m['line']); })());
      expect(res, equals((null, null, null)));
    });
    // Đường: D1S D2Đ D3S D4Đ D5Đ D6Đ D7Đ D8S D9S D10S D11S D12S D13S D14S D15S D16S → R2
    test('6-6 spacing line 480 không lineRule', () {
      final res = _run(() => ppMap(pp('<w:spacing w:line="480"/>'))['line']);
      expect(res, 2.0);
    });
    // Đường: D1S D2Đ D3S D4Đ D5S D6S D8S D9S D10S D11S D12S D13S D14S D15S D16S → R2
    test('6-7 spacing không có line', () {
      final res = _run(() => ppMap(pp('<w:spacing w:before="20"/>'))['line']);
      expect(res, isNull);
    });
    // Đường: D1S D2Đ D3S D4Đ D5S D6Đ D7S D8S D9S D10S D11S D12S D13S D14S D15S D16S → R2
    test('6-8 spacing line 300 lineRule exact', () {
      final res = _run(() => ppMap(pp('<w:spacing w:line="300" w:lineRule="exact"/>'))['line']);
      expect(res, isNull);
    });
    // Đường: D1S D2Đ D3S D4Đ D5S D6Đ D7Đ D8S D9Đ D10S D11S D12S D13S D14S D15S D16S → R2
    test('6-10 ind dùng w:start thay left', () {
      final res = _run(() => ppMap(pp('<w:ind w:start="720"/>'))['indLeft']);
      expect(res, 36.0);
    });
    // Đường: D1S D2Đ D3S D4Đ D5S D6Đ D7Đ D8S D9S D10S D11Đ D12S D13S D14S D15S D16S → R2
    test('6-12 ind dùng w:end thay right', () {
      final res = _run(() => ppMap(pp('<w:ind w:end="360"/>'))['indRight']);
      expect(res, 18.0);
    });
    // Đường: D1S D2Đ D3S D4Đ D5S D6Đ D7Đ D8S D9S D10S D11S D12S D13S D14Đ D15Đ D16S → R2
    test('6-15 không có numPr', () {
      final res = _run(() => (() { final m = ppMap(pp('<w:jc w:val="left"/>')); return (m['numId'], m['ilvl']); })());
      expect(res, equals((null, null)));
    });
    // Đường: D1S D2Đ D3S D4Đ D5S D6Đ D7Đ D8S D9S D10S D11S D12S D13S D14S D15S D16Đ → R2
    test('6-17 không có pageBreakBefore', () {
      final res = _run(() => ppMap(pp('<w:jc w:val="left"/>'))['pageBreakBefore']);
      expect(res, isNull);
    });
  });
  group('Đơn vị 7 — ParaProps.parse — tw (hàm cục bộ)', () {
    // Đường: D1S → R2
    test('7-1 spacing before 200', () {
      final res = _run(() => ppMap(pp('<w:spacing w:before="200"/>'))['before']);
      expect(res, 10.0);
    });
    // Đường: D1Đ → R1
    test('7-2 spacing không có before', () {
      final res = _run(() => ppMap(pp('<w:spacing w:after="20"/>'))['before']);
      expect(res, isNull);
    });
  });
  group('Đơn vị 8 — ThemeFonts.parse', () {
    // Đường: D1S → R2
    test('8-1 theme có majorFont/minorFont latin', () {
      final res = _run(() => (() { final t = ThemeFonts.parse(XmlDocument.parse('<a:theme xmlns:a="u"><a:themeElements><a:fontScheme><a:majorFont><a:latin typeface="Cambria"/></a:majorFont><a:minorFont><a:latin typeface="Calibri"/></a:minorFont></a:fontScheme></a:themeElements></a:theme>')); return (t.major, t.minor); })());
      expect(res, equals(('Cambria', 'Calibri')));
    });
    // Đường: D1Đ → R1
    test('8-2 theme = null', () {
      final res = _run(() => (() { final t = ThemeFonts.parse(null); return (t.major, t.minor); })());
      expect(res, equals((null, null)));
    });
  });
  group('Đơn vị 9 — ThemeFonts.parse — latin (lambda)', () {
    // Đường: D1S D2S → R2
    test('9-1 như 8-1 (major)', () {
      final res = _run(() => ThemeFonts.parse(XmlDocument.parse('<a:theme xmlns:a="u"><a:themeElements><a:fontScheme><a:majorFont><a:latin typeface="Cambria"/></a:majorFont><a:minorFont><a:latin typeface="Calibri"/></a:minorFont></a:fontScheme></a:themeElements></a:theme>')).major);
      expect(res, 'Cambria');
    });
    // Đường: D1Đ → R1
    test('9-2 không có majorFont', () {
      final res = _run(() => ThemeFonts.parse(XmlDocument.parse('<a:theme xmlns:a="u"><a:themeElements><a:fontScheme><a:minorFont><a:latin typeface="Calibri"/></a:minorFont></a:fontScheme></a:themeElements></a:theme>')).major);
      expect(res, isNull);
    });
    // Đường: D1S D2Đ → R1
    test('9-3 majorFont không có latin', () {
      final res = _run(() => ThemeFonts.parse(XmlDocument.parse('<a:theme xmlns:a="u"><a:themeElements><a:fontScheme><a:majorFont><a:ea typeface="MS Mincho"/></a:majorFont></a:fontScheme></a:themeElements></a:theme>')).major);
      expect(res, isNull);
    });
  });
  group('Đơn vị 10 — DocxStyles (constructor)', () {
    // Đường: D1S D2Đ D3S D4S D5S D6S D7S D8S D9Đ D10S → R2
    test('10-1 docDefaults (sz 22, after 160) + style paragraph P1 có tblBorders', () {
      final res = _run(() => (() { final s = st('<w:docDefaults><w:rPrDefault><w:rPr><w:sz w:val="22"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after="160"/></w:pPr></w:pPrDefault></w:docDefaults><w:style w:type="paragraph" w:styleId="P1"><w:name w:val="Body"/><w:tblPr><w:tblBorders><w:top w:val="single"/></w:tblBorders></w:tblPr></w:style>'); return (s.paragraph('P1').$1.after, s.paragraph('P1').$2.sizePt, s.tableBorders('P1')); })());
      expect(res, equals((8.0, 11.0, true)));
    });
    // Đường: D1Đ → R1
    test('10-2 DocxStyles(null)', () {
      final res = _run(() => (() { final s = DocxStyles(null, th); return (s.defaultParagraphStyle, s.paragraph('X').$3); })());
      expect(res, equals((null, null)));
    });
    // Đường: D1S D2S D5S D6S D7S D8S D9Đ D10S → R2
    test('10-3 không có docDefaults', () {
      final res = _run(() => (() { final s = st('<w:style w:type="paragraph" w:styleId="P1"><w:name w:val="Body"/><w:tblPr><w:tblBorders><w:top w:val="single"/></w:tblBorders></w:tblPr></w:style>'); return (s.paragraph('P1').$1.after, s.paragraph('P1').$2.sizePt, s.tableBorders('P1')); })());
      expect(res, equals((null, null, true)));
    });
    // Đường: D1S D2Đ D3Đ D4S D5S D6S D7S D8S D9Đ D10S → R2
    test('10-4 docDefaults không có rPrDefault', () {
      final res = _run(() => (() { final s = st('<w:docDefaults><w:pPrDefault><w:pPr><w:spacing w:after="160"/></w:pPr></w:pPrDefault></w:docDefaults><w:style w:type="paragraph" w:styleId="P1"><w:name w:val="Body"/><w:tblPr><w:tblBorders><w:top w:val="single"/></w:tblBorders></w:tblPr></w:style>'); return (s.paragraph('P1').$1.after, s.paragraph('P1').$2.sizePt, s.tableBorders('P1')); })());
      expect(res, equals((8.0, null, true)));
    });
    // Đường: D1S D2Đ D3S D4Đ D5S D6S D7S D8S D9Đ D10S → R2
    test('10-5 docDefaults không có pPrDefault', () {
      final res = _run(() => (() { final s = st('<w:docDefaults><w:rPrDefault><w:rPr><w:sz w:val="22"/></w:rPr></w:rPrDefault></w:docDefaults><w:style w:type="paragraph" w:styleId="P1"><w:name w:val="Body"/><w:tblPr><w:tblBorders><w:top w:val="single"/></w:tblBorders></w:tblPr></w:style>'); return (s.paragraph('P1').$1.after, s.paragraph('P1').$2.sizePt, s.tableBorders('P1')); })());
      expect(res, equals((null, 11.0, true)));
    });
    // Đường: D1S D2Đ D3S D4S D5Đ → R2
    test('10-6 style thiếu styleId (có default="1")', () {
      final res = _run(() => (() { final s = st('<w:docDefaults><w:rPrDefault><w:rPr><w:sz w:val="22"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after="160"/></w:pPr></w:pPrDefault></w:docDefaults><w:style w:type="paragraph" w:default="1"><w:name w:val="Body"/></w:style>'); return s.defaultParagraphStyle; })());
      expect(res, isNull);
    });
    // Đường: D1S D2Đ D3S D4S D5S D6Đ D7S D8S D9Đ D10S → R2
    test('10-7 style Q không có w:type, tên "heading 2"', () {
      final res = _run(() => (() { final s = st('<w:docDefaults><w:rPrDefault><w:rPr><w:sz w:val="22"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after="160"/></w:pPr></w:pPrDefault></w:docDefaults><w:style w:styleId="Q"><w:name w:val="heading 2"/></w:style>'); return s.paragraph('Q').$3; })());
      expect(res, 2);
    });
    // Đường: D1S D2Đ D3S D4S D5S D6S D7Đ D8Đ D9Đ D10S → R2
    test('10-8 P1 không có tblPr', () {
      final res = _run(() => (() { final s = st('<w:docDefaults><w:rPrDefault><w:rPr><w:sz w:val="22"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after="160"/></w:pPr></w:pPrDefault></w:docDefaults><w:style w:type="paragraph" w:styleId="P1"><w:name w:val="Body"/></w:style>'); return (s.paragraph('P1').$1.after, s.paragraph('P1').$2.sizePt, s.tableBorders('P1')); })());
      expect(res, equals((8.0, 11.0, null)));
    });
    // Đường: D1S D2Đ D3S D4S D5S D6S D7S D8Đ D9Đ D10S → R2
    test('10-9 P1 có tblPr nhưng không tblBorders', () {
      final res = _run(() => (() { final s = st('<w:docDefaults><w:rPrDefault><w:rPr><w:sz w:val="22"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after="160"/></w:pPr></w:pPrDefault></w:docDefaults><w:style w:type="paragraph" w:styleId="P1"><w:name w:val="Body"/><w:tblPr/></w:style>'); return (s.paragraph('P1').$1.after, s.paragraph('P1').$2.sizePt, s.tableBorders('P1')); })());
      expect(res, equals((8.0, 11.0, null)));
    });
    // Đường: D1S D2Đ D3S D4S D5S D6S D7S D8S D9S → R2
    test('10-10 style type table T có viền single', () {
      final res = _run(() => (() { final s = st('<w:docDefaults><w:rPrDefault><w:rPr><w:sz w:val="22"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after="160"/></w:pPr></w:pPrDefault></w:docDefaults><w:style w:type="table" w:styleId="T"><w:name w:val="Body"/><w:tblPr><w:tblBorders><w:top w:val="single"/></w:tblBorders></w:tblPr></w:style>'); return s.tableBorders('T'); })());
      expect(res, isTrue);
    });
    // Đường: D1S D2Đ D3S D4S D5S D6S D7S D8S D9Đ D10Đ → R2
    test('10-11 P1 default="1"', () {
      final res = _run(() => (() { final s = st('<w:docDefaults><w:rPrDefault><w:rPr><w:sz w:val="22"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after="160"/></w:pPr></w:pPrDefault></w:docDefaults><w:style w:type="paragraph" w:styleId="P1" w:default="1"><w:name w:val="Body"/><w:tblPr><w:tblBorders><w:top w:val="single"/></w:tblBorders></w:tblPr></w:style>'); return s.defaultParagraphStyle; })());
      expect(res, 'P1');
    });
  });
  group('Đơn vị 11 — DocxStyles._chain', () {
    // Đường: D1Đ D2Đ D3S D1S → R1
    test('11-1 character style C (b) không basedOn', () {
      final res = _run(() => (() { final s = st('<w:style w:type="character" w:styleId="C"><w:name w:val="Body"/><w:rPr><w:b/></w:rPr></w:style>'); return s.character('C').bold; })());
      expect(res, isTrue);
    });
    // Đường: D1S → R1
    test('11-2 character(null)', () {
      final res = _run(() => (() { final s = st('<w:style w:type="character" w:styleId="C"><w:name w:val="Body"/><w:rPr><w:b/></w:rPr></w:style>'); return s.character(null).bold; })());
      expect(res, isNull);
    });
    // Đường: D1Đ D2S → R1
    test('11-3 vòng basedOn: A (b, basedOn B), B (i, basedOn A)', () {
      final res = _run(() => (() { final s = st('<w:style w:type="character" w:styleId="A"><w:name w:val="Body"/><w:basedOn w:val="B"/><w:rPr><w:b/></w:rPr></w:style><w:style w:type="character" w:styleId="B"><w:name w:val="Body"/><w:basedOn w:val="A"/><w:rPr><w:i/></w:rPr></w:style>'); return (s.character('A').bold, s.character('A').italic); })());
      expect(res, equals((true, true)));
    });
    // Đường: D1Đ D2Đ D3Đ → R1
    test('11-4 basedOn trỏ style không tồn tại', () {
      final res = _run(() => (() { final s = st('<w:style w:type="character" w:styleId="A"><w:name w:val="Body"/><w:basedOn w:val="ZZ"/><w:rPr><w:b/></w:rPr></w:style>'); return s.character('A').bold; })());
      expect(res, isTrue);
    });
  });
  group('Đơn vị 12 — DocxStyles.paragraph', () {
    // Đường: D1S D2S D3S D4Đ D5S → R2
    test('12-1 P1 tên Body, không outline', () {
      final res = _run(() => (() { final s = st('<w:style w:type="paragraph" w:styleId="P1"><w:name w:val="Body"/></w:style>'); return s.paragraph('P1').$3; })());
      expect(res, isNull);
    });
    // Đường: D1Đ D2S D3S D4Đ D5S → R2
    test('12-2 paragraph(null) với docDefaults after 160', () {
      final res = _run(() => (() { final s = st('<w:docDefaults><w:rPrDefault><w:rPr><w:sz w:val="22"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after="160"/></w:pPr></w:pPrDefault></w:docDefaults><w:style w:type="paragraph" w:styleId="P1"><w:name w:val="Body"/></w:style>'); return s.paragraph(null).$1.after; })());
      expect(res, 8.0);
    });
    // Đường: D1S D2Đ → R1
    test('12-3 gọi paragraph(P1) 2 lần', () {
      final res = _run(() => (() { final s = st('<w:style w:type="paragraph" w:styleId="P1"><w:name w:val="Body"/></w:style>'); return identical(s.paragraph('P1'), s.paragraph('P1')); })());
      expect(res, isTrue);
    });
    // Đường: D1S D2S D3Đ D4Đ D5S → R2
    test('12-4 P1 tên "heading 2"', () {
      final res = _run(() => (() { final s = st('<w:style w:type="paragraph" w:styleId="P1"><w:name w:val="heading 2"/></w:style>'); return s.paragraph('P1').$3; })());
      expect(res, 2);
    });
    // Đường: D1S D2S D3S D4S → R2
    test('12-5 H basedOn Heading1 (tên MyHead)', () {
      final res = _run(() => (() { final s = st('<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/></w:style><w:style w:type="paragraph" w:styleId="H"><w:name w:val="MyHead"/><w:basedOn w:val="Heading1"/></w:style>'); return s.paragraph('H').$3; })());
      expect(res, 1);
    });
    // Đường: D1S D2S D3S D4Đ D5Đ D6Đ → R2
    test('12-6 P1 pPr outlineLvl 1', () {
      final res = _run(() => (() { final s = st('<w:style w:type="paragraph" w:styleId="P1"><w:name w:val="Body"/><w:pPr><w:outlineLvl w:val="1"/></w:pPr></w:style>'); return s.paragraph('P1').$3; })());
      expect(res, 2);
    });
    // Đường: D1S D2S D3S D4Đ D5Đ D6S → R2
    test('12-7 P1 pPr outlineLvl 7', () {
      final res = _run(() => (() { final s = st('<w:style w:type="paragraph" w:styleId="P1"><w:name w:val="Body"/><w:pPr><w:outlineLvl w:val="7"/></w:pPr></w:style>'); return s.paragraph('P1').$3; })());
      expect(res, isNull);
    });
  });
  group('Đơn vị 13 — DocxStyles.tableBorders', () {
    // Đường: D1S → R1
    test('13-1 style T không có tblBorders', () {
      final res = _run(() => (() { final s = st('<w:style w:type="table" w:styleId="T"><w:name w:val="Body"/></w:style>'); return s.tableBorders('T'); })());
      expect(res, isNull);
    });
    // Đường: D1Đ → R1
    test('13-2 style T có viền', () {
      final res = _run(() => (() { final s = st('<w:style w:type="table" w:styleId="T"><w:name w:val="Body"/><w:tblPr><w:tblBorders><w:top w:val="single"/></w:tblBorders></w:tblPr></w:style>'); return s.tableBorders('T'); })());
      expect(res, isTrue);
    });
  });
  group('Đơn vị 14 — DocxStyles._headingFromName', () {
    // Đường: D1S D2Đ D3Đ → R2
    test('14-1 tên "Heading 3"', () {
      final res = _run(() => (() { final s = st('<w:style w:type="paragraph" w:styleId="X"><w:name w:val="Heading 3"/></w:style>'); return s.paragraph('X').$3; })());
      expect(res, 3);
    });
    // Đường: D1Đ → R1
    test('14-2 không có w:name, id Body', () {
      final res = _run(() => (() { final s = st('<w:style w:type="paragraph" w:styleId="Body"></w:style>'); return s.paragraph('Body').$3; })());
      expect(res, isNull);
    });
    // Đường: D1S D2S → R1
    test('14-3 tên "Title"', () {
      final res = _run(() => (() { final s = st('<w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/></w:style>'); return s.paragraph('Title').$3; })());
      expect(res, isNull);
    });
    // Đường: D1S D2Đ D3S → R3
    test('14-4 tên "heading 7"', () {
      final res = _run(() => (() { final s = st('<w:style w:type="paragraph" w:styleId="H7"><w:name w:val="heading 7"/></w:style>'); return s.paragraph('H7').$3; })());
      expect(res, isNull);
    });
  });
  group('Đơn vị 15 — hasVisibleBorder', () {
    // Đường: D1Đ D2Đ D3Đ → R2
    test('15-1 <b><w:top w:val="single"/></b>', () {
      final res = _run(() => hasVisibleBorder(el('<b xmlns:w="u"><w:top w:val="single"/></b>')));
      expect(res, isTrue);
    });
    // Đường: D1S → R1
    test('15-2 cạnh không có val', () {
      final res = _run(() => hasVisibleBorder(el('<b xmlns:w="u"><w:top/></b>')));
      expect(res, isFalse);
    });
    // Đường: D1Đ D2S → R1
    test('15-3 val none', () {
      final res = _run(() => hasVisibleBorder(el('<b xmlns:w="u"><w:top w:val="none"/></b>')));
      expect(res, isFalse);
    });
    // Đường: D1Đ D2Đ D3S → R1
    test('15-4 val nil', () {
      final res = _run(() => hasVisibleBorder(el('<b xmlns:w="u"><w:top w:val="nil"/></b>')));
      expect(res, isFalse);
    });
  });
}
