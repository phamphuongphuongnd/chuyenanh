// Kiểm thử hộp trắng A19 — lib/src/text.dart (mã bộ T*, xem
// test-output/whitebox/pptx-reader/text/buoc-5-du-lieu-thu.md).
// Không mock: TextContext dựng thật, XML viết tay (tên không prefix — reader so theo local name).
// Hàm private (_alignOf, _ParaProps, _spacing, _font, _size, _run, closure) kiểm qua
// TextContext.paragraph / runProps; nhánh khẳng định qua giá trị phân biệt theo nhánh.
import 'package:pptx_reader/src/color.dart';
import 'package:pptx_reader/src/model.dart';
import 'package:pptx_reader/src/package.dart';
import 'package:pptx_reader/src/text.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

XmlElement el(String xml) => XmlDocument.parse(xml).rootElement;
const rNs = 'xmlns:r="urn:r"';

final cc = ColorContext(themeColors: {'accent1': 0x4472C4}, clrMap: {});
TextContext tc({
  List<XmlElement?> levels = const [],
  RunProps? styleRun,
  XmlElement? own,
  double fontScale = 1,
  double lnRed = 0,
  Map<String, Rel> rels = const {},
}) => TextContext(
  levels: levels,
  styleRun: styleRun,
  own: own,
  colors: cc,
  majorFont: 'Major',
  minorFont: 'Minor',
  rels: rels,
  fontScale: fontScale,
  lineSpacingReductionPct: lnRed,
  slideNumber: 3,
);
PptxParagraph para(String pPr, {String runs = '<r><t>Hi</t></r>', TextContext? ctx}) =>
    (ctx ?? tc()).paragraph(el('<p>$pPr$runs</p>'));
RunProps rp(String? rPr, {Map<String, Rel> rels = const {}}) =>
    tc(rels: rels).runProps(rPr == null ? null : el(rPr.replaceFirst('<rPr', '<rPr $rNs')));

void main() {
  group('T1 anchorOf', () {
    test("T1.1 'ctr' ⇒ middle", () => expect(anchorOf('ctr'), PptxAnchor.middle));
    test("T1.2 'b' ⇒ bottom", () => expect(anchorOf('b'), PptxAnchor.bottom));
    test("T1.3 khác/null ⇒ top", () {
      expect(anchorOf('t'), PptxAnchor.top);
      expect(anchorOf(null), PptxAnchor.top);
    });
  });

  group('T2 _alignOf (qua pPr algn)', () {
    PptxAlign a(String v) => para('<pPr algn="$v"/>').align;
    test("T2.1 'ctr' ⇒ center", () => expect(a('ctr'), PptxAlign.center));
    test("T2.2 'r' ⇒ right", () => expect(a('r'), PptxAlign.right));
    test("T2.3 'just' ⇒ justify", () => expect(a('just'), PptxAlign.justify));
    test("T2.4 'dist' ⇒ justify", () => expect(a('dist'), PptxAlign.justify));
    test("T2.5 'justLow' ⇒ justify", () => expect(a('justLow'), PptxAlign.justify));
    test("T2.6 'thaiDist' ⇒ justify", () => expect(a('thaiDist'), PptxAlign.justify));
    test("T2.7 'l' ⇒ left", () => expect(a('l'), PptxAlign.left));
  });

  group('T3 plainText', () {
    String pt(String inner) => plainText(el('<p>$inner</p>'));
    test('T3.1 run có t', () => expect(pt('<r><t>a</t></r>'), 'a'));
    test('T3.2 đoạn rỗng', () => expect(pt(''), ''));
    test('T3.3 fld', () => expect(pt('<fld><t>5</t></fld>'), '5'));
    test('T3.4 br ⇒ xuống dòng', () => expect(pt('<r><t>a</t></r><br/><r><t>b</t></r>'), 'a\nb'));
    test('T3.5 phần tử khác bị bỏ', () => expect(pt('<pPr/><endParaRPr/>'), ''));
    test('T3.6 run không có t ⇒ rỗng', () => expect(pt('<r/>'), ''));
  });

  group('T4 RunProps.merge', () {
    RunProps full() => RunProps()
      ..bold = true
      ..italic = true
      ..underline = true
      ..strike = true
      ..sizePt = 10
      ..color = 1
      ..font = 'F'
      ..baseline = 5
      ..link = 'L';
    List<Object?> v(RunProps r) =>
        [r.bold, r.italic, r.underline, r.strike, r.sizePt, r.color, r.font, r.baseline, r.link];
    test('T4.1 o rỗng ⇒ giữ nguyên mọi trường', () {
      expect(v(full()..merge(RunProps())), v(full()));
    });
    final over = <String, void Function(RunProps)>{
      'T4.2 bold': (o) => o.bold = false,
      'T4.3 italic': (o) => o.italic = false,
      'T4.4 underline': (o) => o.underline = false,
      'T4.5 strike': (o) => o.strike = false,
      'T4.6 sizePt': (o) => o.sizePt = 99,
      'T4.7 color': (o) => o.color = 99,
      'T4.8 font': (o) => o.font = 'X',
      'T4.9 baseline': (o) => o.baseline = 99,
      'T4.10 link': (o) => o.link = 'Y',
    };
    var i = 0;
    over.forEach((name, set) {
      final idx = i++;
      test('$name đặt ở o ⇒ ghi đè đúng trường đó', () {
        final o = RunProps();
        set(o);
        final got = v(full()..merge(o));
        final want = v(full());
        want[idx] = v(o)[idx];
        expect(got, want);
      });
    });
  });

  group('T5 _ParaProps.apply (qua paragraph)', () {
    final buChar = '<buChar char="x"/>';
    test('T5.1 algn/marL/indent + buNone', () {
      final p = para('<pPr algn="ctr" marL="100" indent="-50"><buNone/></pPr>');
      expect([p.align, p.marginLeftEmu, p.indentEmu, p.bulletChar, p.numbered],
          [PptxAlign.center, 100, -50, null, false]);
    });
    test('T5.2 không có pPr ⇒ mặc định', () {
      final p = para('');
      expect([p.align, p.marginLeftEmu, p.indentEmu, p.bulletChar], [PptxAlign.left, 0, 0, null]);
    });
    test('T5.3 thiếu algn ⇒ giữ (mặc định left)', () {
      expect(para('<pPr marL="100"/>').align, PptxAlign.left);
    });
    test('T5.4 thiếu marL ⇒ giữ mức trước', () {
      final own = el('<lstStyle><lvl1pPr marL="7"/></lstStyle>');
      expect(para('<pPr indent="1"/>', ctx: tc(own: own)).marginLeftEmu, 7);
    });
    test('T5.5 thiếu indent ⇒ giữ mức trước', () {
      final own = el('<lstStyle><lvl1pPr indent="-9"/></lstStyle>');
      expect(para('<pPr marL="1"/>', ctx: tc(own: own)).indentEmu, -9);
    });
    test('T5.6 pPr không có con ⇒ không bullet', () {
      expect(para('<pPr algn="ctr"/>').bulletChar, isNull);
    });
    test('T5.7 buChar', () => expect(para('<pPr>$buChar</pPr>').bulletChar, 'x'));
    test('T5.8 buAutoNum', () {
      final p = para('<pPr><buAutoNum type="arabicPeriod"/></pPr>');
      expect([p.numbered, p.numberingScheme], [true, 'arabicPeriod']);
    });
    test('T5.9 buFont typeface thường', () {
      expect(para('<pPr><buFont typeface="Wingdings"/>$buChar</pPr>').bulletFontFamily, 'Wingdings');
    });
    test('T5.10 buFont thiếu typeface ⇒ null', () {
      expect(para('<pPr><buFont/>$buChar</pPr>').bulletFontFamily, isNull);
    });
    test("T5.11 buFont '+mj-sym' (font theme) ⇒ null", () {
      expect(para('<pPr><buFont typeface="+mj-sym"/>$buChar</pPr>').bulletFontFamily, isNull);
    });
    test('T5.12 buClrTx ⇒ bỏ màu bullet của mức trước', () {
      final own = el('<lstStyle><lvl1pPr><buClr><srgbClr val="FF0000"/></buClr></lvl1pPr></lstStyle>');
      expect(para('<pPr><buClrTx/></pPr>', ctx: tc(own: own)).bulletColorArgb, isNull);
    });
    test('T5.13 buClr ⇒ màu bullet', () {
      expect(para('<pPr><buClr><srgbClr val="FF0000"/></buClr></pPr>').bulletColorArgb, 0xFFFF0000);
    });
    test('T5.15 buSzPct 50%', () => expect(para('<pPr><buSzPct val="50000"/></pPr>').bulletSizePct, 50.0));
    test('T5.16 buSzPct thiếu val ⇒ 100', () => expect(para('<pPr><buSzPct/></pPr>').bulletSizePct, 100.0));
    test('T5.17 spcBef 12pt', () {
      expect(para('<pPr><spcBef><spcPts val="1200"/></spcBef></pPr>').spaceBeforePt, 12.0);
    });
    test('T5.18 spcAft 6pt', () {
      expect(para('<pPr><spcAft><spcPts val="600"/></spcAft></pPr>').spaceAfterPt, 6.0);
    });
    test('T5.19 lnSpc spcPct 90%', () {
      final p = para('<pPr><lnSpc><spcPct val="90000"/></lnSpc></pPr>');
      expect([p.lineSpacingPct, p.lineSpacingPt], [90.0, null]);
    });
    test('T5.20 lnSpc spcPts 18pt', () {
      final p = para('<pPr><lnSpc><spcPts val="1800"/></lnSpc></pPr>');
      expect([p.lineSpacingPct, p.lineSpacingPt], [null, 18.0]);
    });
    test('T5.21 lnSpc có cả spcPct và spcPts ⇒ spcPct thắng', () {
      final p = para('<pPr><lnSpc><spcPct val="90000"/><spcPts val="1800"/></lnSpc></pPr>');
      expect([p.lineSpacingPct, p.lineSpacingPt], [90.0, null]);
    });
    test('T5.22 lnSpc spcPct thiếu val ⇒ không đổi', () {
      final p = para('<pPr><lnSpc><spcPct/></lnSpc></pPr>');
      expect([p.lineSpacingPct, p.lineSpacingPt], [null, null]);
    });
    test('T5.23 lnSpc spcPts thiếu val ⇒ không đổi', () {
      final p = para('<pPr><lnSpc><spcPts/></lnSpc></pPr>');
      expect([p.lineSpacingPct, p.lineSpacingPt], [null, null]);
    });
    test('T5.24 phần tử lạ trong pPr bị bỏ', () {
      final p = para('<pPr><extLst/></pPr>');
      expect([p.bulletChar, p.lineSpacingPct, p.spaceBeforePt], [null, null, null]);
    });
  });

  group('T6 _spacing (qua spcBef)', () {
    final lvl600 = el('<lstStyle><lvl1pPr><spcBef><spcPts val="600"/></spcBef></lvl1pPr></lstStyle>');
    test('T6.1 spcPts ⇒ pt', () {
      expect(para('<pPr><spcBef><spcPts val="1200"/></spcBef></pPr>').spaceBeforePt, 12.0);
    });
    test('T6.2 spcPct 50% ⇒ 50% cỡ chữ run đầu (18pt) = 9pt', () {
      expect(para('<pPr><spcBef><spcPct val="50000"/></spcBef></pPr>').spaceBeforePt, 9.0);
    });
    test('T6.3 spcPts thiếu val, không spcPct ⇒ giữ mức trước', () {
      expect(para('<pPr><spcBef><spcPts/></spcBef></pPr>', ctx: tc(own: lvl600)).spaceBeforePt, 6.0);
    });
    test('T6.4 spcBef rỗng ⇒ giữ mức trước', () {
      expect(para('<pPr><spcBef/></pPr>', ctx: tc(own: lvl600)).spaceBeforePt, 6.0);
    });
    test('T6.5 spcPct thiếu val ⇒ giữ mức trước', () {
      expect(para('<pPr><spcBef><spcPct/></spcBef></pPr>', ctx: tc(own: lvl600)).spaceBeforePt, 6.0);
    });
  });

  group('T7 _font (qua rPr latin)', () {
    String? f(String? tf) => rp(tf == null ? '<rPr/>' : '<rPr><latin typeface="$tf"/></rPr>').font;
    test('T7.1 tên font thường', () => expect(f('Arial'), 'Arial'));
    test('T7.2 không có typeface ⇒ null', () => expect(f(null), isNull));
    test("T7.3 typeface '' ⇒ null", () => expect(f(''), isNull));
    test("T7.4 '+mj-lt' ⇒ font major của theme", () => expect(f('+mj-lt'), 'Major'));
    test("T7.5 '+mn-lt' ⇒ font minor của theme", () => expect(f('+mn-lt'), 'Minor'));
  });

  group('T8 runProps', () {
    final ext = {'rId1': const Rel('t', 'https://x.test/', true)};
    const base = '<rPr b="1" u="sng" strike="sngStrike" sz="2400" baseline="30000">'
        '<solidFill><srgbClr val="FF0000"/></solidFill><latin typeface="Arial"/>'
        '<hlinkClick r:id="rId1"/></rPr>';
    List<Object?> v(RunProps r) =>
        [r.bold, r.underline, r.strike, r.sizePt, r.baseline, r.color, r.font, r.link];
    test('T8.1 rPr đầy đủ', () {
      expect(v(rp(base, rels: ext)), [true, true, true, 24.0, 30.0, 0xFFFF0000, 'Arial', 'https://x.test/']);
    });
    test('T8.2 rPr null ⇒ mọi trường null', () {
      expect(v(rp(null)), List.filled(8, null));
    });
    test('T8.3 thiếu u ⇒ underline null', () => expect(rp('<rPr/>').underline, isNull));
    test("T8.3b u='none' ⇒ false", () => expect(rp('<rPr u="none"/>').underline, isFalse));
    test('T8.4 thiếu strike ⇒ null; noStrike ⇒ false', () {
      expect(rp('<rPr/>').strike, isNull);
      expect(rp('<rPr strike="noStrike"/>').strike, isFalse);
    });
    test('T8.5 thiếu sz ⇒ null', () => expect(rp('<rPr/>').sizePt, isNull));
    test('T8.6 thiếu baseline ⇒ null; -25000 ⇒ -25', () {
      expect(rp('<rPr/>').baseline, isNull);
      expect(rp('<rPr baseline="-25000"/>').baseline, -25.0);
    });
    test('T8.7 không fill ⇒ color null', () => expect(rp('<rPr/>').color, isNull));
    test('T8.8 gradFill ⇒ màu stop đầu', () {
      final r = rp('<rPr><gradFill><gsLst><gs pos="0"><srgbClr val="00FF00"/></gs>'
          '<gs pos="100000"><srgbClr val="0000FF"/></gs></gsLst></gradFill></rPr>');
      expect(r.color, 0xFF00FF00);
    });
    test('T8.9 gradFill không gsLst ⇒ null', () => expect(rp('<rPr><gradFill/></rPr>').color, isNull));
    test('T8.10 gsLst không gs ⇒ null', () {
      expect(rp('<rPr><gradFill><gsLst/></gradFill></rPr>').color, isNull);
    });
    test('T8.11 không latin, có ea ⇒ font ea', () {
      expect(rp('<rPr><ea typeface="MS Gothic"/></rPr>').font, 'MS Gothic');
    });
    test("T8.12 latin '' và không ea ⇒ null", () {
      expect(rp('<rPr><latin typeface=""/></rPr>').font, isNull);
    });
    test('T8.13 không latin, không ea ⇒ null', () => expect(rp('<rPr/>').font, isNull));
    test('T8.14 không hlinkClick ⇒ link null', () => expect(rp('<rPr/>', rels: ext).link, isNull));
    test('T8.15 hlinkClick thiếu r:id ⇒ null', () {
      expect(rp('<rPr><hlinkClick/></rPr>', rels: ext).link, isNull);
    });
    test('T8.16 r:id không có trong rels ⇒ null', () {
      expect(rp('<rPr><hlinkClick r:id="rId9"/></rPr>', rels: ext).link, isNull);
    });
    test('T8.17 rel nội bộ (không External) ⇒ null', () {
      final rels = {'rId1': const Rel('t', 'ppt/slides/slide2.xml', false)};
      expect(rp('<rPr><hlinkClick r:id="rId1"/></rPr>', rels: rels).link, isNull);
    });
  });

  group('T9 paragraph', () {
    final style = RunProps()..color = 0xFF00FF00;
    const basePPr = '<pPr lvl="1" algn="r" marL="10" indent="5"><buChar char="•"/></pPr>';
    const baseRun = '<r><rPr sz="2000"/><t>Hi</t></r>';
    TextContext ctx({RunProps? s, double lnRed = 0}) => tc(styleRun: s, lnRed: lnRed);
    test('T9.1 đường gốc', () {
      final p = para(basePPr, runs: baseRun, ctx: ctx(s: style));
      expect([p.level, p.align, p.bulletChar, p.numbered, p.numberingScheme, p.bulletFontFamily,
          p.marginLeftEmu, p.indentEmu], [1, PptxAlign.right, '•', false, null, null, 10, 5]);
      expect([p.runs.single.text, p.runs.single.fontSizePt, p.runs.single.colorArgb],
          ['Hi', 20.0, 0xFF00FF00]);
    });
    test('T9.2 không pPr ⇒ level 0, left, không bullet, lề 0', () {
      final p = para('', runs: baseRun, ctx: ctx(s: style));
      expect([p.level, p.align, p.bulletChar, p.marginLeftEmu, p.indentEmu], [0, PptxAlign.left, null, 0, 0]);
    });
    test('T9.3 pPr không lvl ⇒ level 0', () {
      expect(para('<pPr algn="r"/>', runs: baseRun).level, 0);
    });
    test('T9.4 không styleRun ⇒ màu null', () {
      expect(para(basePPr, runs: baseRun, ctx: ctx()).runs.single.colorArgb, isNull);
    });
    test('T9.5 không có run ⇒ runs rỗng, không bullet, cỡ dấu cuối đoạn', () {
      final p = para(basePPr, runs: '<endParaRPr sz="1000"/>');
      expect([p.runs.length, p.bulletChar, p.endFontSizePt], [0, null, 10.0]);
    });
    test('T9.6 br ⇒ run xuống dòng', () {
      final p = para('', runs: '<r><t>a</t></r><br/><r><t>b</t></r>');
      expect(p.runs.map((r) => [r.text, r.isLineBreak]).toList(), [
        ['a', false],
        ['\n', true],
        ['b', false],
      ]);
    });
    test('T9.7 fld kiểu khác ⇒ text của t', () {
      expect(para('', runs: '<fld type="datetime1"><t>30/10</t></fld>').runs.single.text, '30/10');
    });
    test('T9.8 phần tử lạ giữa các run bị bỏ', () {
      expect(para('', runs: '<extLst/>$baseRun').runs.single.text, 'Hi');
    });
    test('T9.11 fld slidenum ⇒ số slide', () {
      expect(para('', runs: '<fld type="slidenum"><t>‹#›</t></fld>').runs.single.text, '3');
    });
    test("T9.12 run không có t ⇒ ''", () => expect(para('', runs: '<r/>').runs.single.text, ''));
    test('T9.16 lnSpcReduction 20% ⇒ 100 - 20 = 80', () {
      expect(para('', runs: baseRun, ctx: ctx(lnRed: 20)).lineSpacingPct, 80.0);
    });
    test('T9.17 lnSpcReduction không áp khi giãn dòng theo pt', () {
      final p = para('<pPr><lnSpc><spcPts val="1800"/></lnSpc></pPr>', runs: baseRun, ctx: ctx(lnRed: 20));
      expect([p.lineSpacingPct, p.lineSpacingPt], [null, 18.0]);
    });
    test('T9.18 lnSpcReduction trừ vào spcPct có sẵn (90 - 20 = 70)', () {
      final p = para('<pPr><lnSpc><spcPct val="90000"/></lnSpc></pPr>', runs: baseRun, ctx: ctx(lnRed: 20));
      expect(p.lineSpacingPct, 70.0);
    });
    test('T9.19 thiếu algn ⇒ left', () => expect(para('<pPr lvl="1"/>', runs: baseRun).align, PptxAlign.left));
    test('T9.20 bullet char nhưng đoạn rỗng ⇒ không hiện bullet', () {
      final p = para(basePPr, runs: '<r><t></t></r>');
      expect(p.bulletChar, isNull);
    });
    test('T9.21 buAutoNum + buFont ⇒ numbered, scheme, font', () {
      final p = para('<pPr><buFont typeface="Arial"/><buAutoNum type="alphaLcParenR"/></pPr>', runs: baseRun);
      expect([p.bulletChar, p.numbered, p.numberingScheme, p.bulletFontFamily],
          [null, true, 'alphaLcParenR', 'Arial']);
    });
    test('T9.23 buNone + buFont ⇒ không bullet, không font', () {
      final p = para('<pPr><buFont typeface="Arial"/><buNone/></pPr>', runs: baseRun);
      expect([p.bulletChar, p.numbered, p.numberingScheme, p.bulletFontFamily], [null, false, null, null]);
    });
    test('T9.27 thiếu marL ⇒ 0', () => expect(para('<pPr indent="5"/>', runs: baseRun).marginLeftEmu, 0));
    test('T9.28 thiếu indent ⇒ 0', () => expect(para('<pPr marL="10"/>', runs: baseRun).indentEmu, 0));
  });

  group('T10 applyList (closure)', () {
    test('T10.1 lstStyle có lvl2pPr cho lvl=1', () {
      final l = el('<lstStyle><lvl2pPr algn="ctr"/></lstStyle>');
      expect(para('<pPr lvl="1"/>', ctx: tc(levels: [l])).align, PptxAlign.center);
    });
    test('T10.2 mức null bị bỏ', () {
      expect(para('<pPr lvl="1"/>', ctx: tc(levels: [null])).align, PptxAlign.left);
    });
    test('T10.4 defPPr áp cho mọi mức', () {
      final l = el('<lstStyle><defPPr algn="r"/></lstStyle>');
      expect(para('<pPr lvl="1"/>', ctx: tc(levels: [l])).align, PptxAlign.right);
    });
  });

  group('T11 spacing (closure)', () {
    test('T11.1 có pt', () => expect(para('<pPr><spcAft><spcPts val="600"/></spcAft></pPr>').spaceAfterPt, 6.0));
    test('T11.2 chỉ có pct ⇒ pct% × cỡ run đầu (20pt × 50% = 10)', () {
      expect(para('<pPr><spcAft><spcPct val="50000"/></spcAft></pPr>',
          runs: '<r><rPr sz="2000"/><t>x</t></r>').spaceAfterPt, 10.0);
    });
    test('T11.3 không có ⇒ null', () => expect(para('').spaceAfterPt, isNull));
  });

  group('T12 _size', () {
    test('T12.1 sz 20pt × fontScale 0.5 = 10', () {
      expect(para('', runs: '<r><rPr sz="2000"/><t>x</t></r>', ctx: tc(fontScale: 0.5)).runs.single.fontSizePt, 10.0);
    });
    test('T12.2 không sz ⇒ 18pt × fontScale 0.5 = 9', () {
      expect(para('', ctx: tc(fontScale: 0.5)).runs.single.fontSizePt, 9.0);
    });
  });

  group('T13 _run', () {
    PptxRun run(String rPr) => para('', runs: '<r>$rPr<t>x</t></r>').runs.single;
    test('T13.1 đủ thuộc tính', () {
      final r = run('<rPr b="1" i="1" u="sng" strike="sngStrike" baseline="30000"/>');
      expect([r.bold, r.italic, r.underline, r.strike, r.baselineOffsetPct], [true, true, true, true, 30.0]);
    });
    test('T13.2 thiếu b ⇒ bold false', () => expect(run('<rPr i="1"/>').bold, isFalse));
    test('T13.3 thiếu i ⇒ italic false', () => expect(run('<rPr b="1"/>').italic, isFalse));
    test('T13.4 thiếu u ⇒ underline false', () => expect(run('<rPr/>').underline, isFalse));
    test('T13.5 thiếu strike ⇒ strike false', () => expect(run('<rPr/>').strike, isFalse));
    test('T13.6 thiếu baseline ⇒ 0', () => expect(run('<rPr/>').baselineOffsetPct, 0.0));
  });
}
