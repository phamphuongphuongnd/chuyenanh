// Kiểm thử hộp trắng (agent A17) cho lib/src/docx/docx_reader.dart.
// Sinh từ Bước 5 (test-output/whitebox/office-reader/docx_reader/buoc-5-du-lieu-thu.md).
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

const rNs = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
String rel(String id, String type, String target, {bool ext = false}) =>
    '<Relationship Id="$id" Type="$rNs/$type" Target="$target"${ext ? ' TargetMode="External"' : ''}/>';
List<DocxBlock> blocks(String body, {String? styles, String? numbering, String rels = '', Map<String, List<int>> media = const {}, Map<String, String> extra = const {}}) =>
    readDocx(buildDocx(body: body, styles: styles, numbering: numbering, rels: rels, media: media, extraParts: extra)).blocks;
DocxParagraph para(String body, {String? styles, String? numbering, String rels = '', Map<String, List<int>> media = const {}}) =>
    blocks(body, styles: styles, numbering: numbering, rels: rels, media: media).whereType<DocxParagraph>().first;
List<DocxInline> inl(String runs, {String rels = '', Map<String, List<int>> media = const {}, String? styles}) =>
    para('<w:p>$runs</w:p>', rels: rels, media: media, styles: styles).inlines;
String txt(String runs, {String rels = ''}) => para('<w:p>$runs</w:p>', rels: rels).plainText;
String r(String inner, [String rPr = '']) => '<w:r><w:rPr>$rPr</w:rPr>$inner</w:r>';
String t(String s) => '<w:t xml:space="preserve">$s</w:t>';
/// Kiểu khối dạng chuỗi ngắn: P(text) / B / T
String kinds(List<DocxBlock> bs) => bs.map((b) => switch (b) {
      DocxParagraph p => 'P(${p.plainText})',
      DocxPageBreak() => 'B',
      DocxTable() => 'T',
    }).join(' ');
const numXml = '<w:abstractNum w:abstractNumId="1"><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:lvlText w:val="%1."/></w:lvl></w:abstractNum><w:num w:numId="1"><w:abstractNumId w:val="1"/></w:num>';
String numPr(int id, [int? ilvl]) => '<w:numPr>${ilvl == null ? '' : '<w:ilvl w:val="$ilvl"/>'}<w:numId w:val="$id"/></w:numPr>';
String drawing(String holder, String inner) => '<w:drawing><wp:$holder>$inner</wp:$holder></w:drawing>';
String blip(String id) => '<a:graphic><a:graphicData><pic:pic><pic:blipFill><a:blip r:embed="$id"/></pic:blipFill></pic:pic></a:graphicData></a:graphic>';
const ext = '<wp:extent cx="914400" cy="457200"/>';
final imgRel = rel('rI', 'image', 'media/i.png');
final imgMedia = {'media/i.png': tinyPng};
String vml(String style, {String id = 'rI'}) => '<w:pict><v:shape xmlns:v="urn:schemas-microsoft-com:vml" style="$style"><v:imagedata r:id="$id"/></v:shape></w:pict>';
DocxImage? img1(String runs) => inl(runs, rels: imgRel, media: imgMedia).whereType<DocxImage>().firstOrNull;
DocxTable tbl(String inner, {String? styles}) => blocks('<w:tbl>$inner</w:tbl>', styles: styles).whereType<DocxTable>().first;
String tc(String text, [String tcPr = '']) => '<w:tc><w:tcPr>$tcPr</w:tcPr><w:p><w:r><w:t>$text</w:t></w:r></w:p></w:tc>';
String tcNoPr(String text) => '<w:tc><w:p><w:r><w:t>$text</w:t></w:r></w:p></w:tc>';
String tr(String cells, [String? trPr]) => '<w:tr>${trPr == null ? '' : '<w:trPr>$trPr</w:trPr>'}$cells</w:tr>';
const wNs = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';
String stylesPart(String inner) => '<w:styles $wNs>$inner</w:styles>';
const h1Style = '<w:style w:type="paragraph" w:styleId="H1"><w:name w:val="heading 1"/></w:style>';
const normalPbb = '<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:pPr><w:pageBreakBefore/></w:pPr></w:style>';
String docPart(String body) => '<w:document $wNs xmlns:r="$rNs"><w:body>$body</w:body></w:document>';
String rootRels(String inner) => '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">$inner</Relationships>';
String math(String tag, String text) => '<m:$tag xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"><m:r><m:t>$text</m:t></m:r></m:$tag>';
final fb = r('<w:fldChar w:fldCharType="begin"/>');
final fs = r('<w:fldChar w:fldCharType="separate"/>');
final fe = r('<w:fldChar w:fldCharType="end"/>');
const plainStyle = '<w:style w:type="table" w:styleId="Plain"><w:name w:val="Plain"/><w:tblPr><w:tblBorders><w:top w:val="none"/></w:tblBorders></w:tblPr></w:style>';
const gridDef = '<w:gridCol w:w="2000"/><w:gridCol w:w="3000"/>';
const trPrDef = '<w:gridBefore w:val="0"/><w:trHeight w:val="400"/>';
const tcPrDef = '<w:gridSpan w:val="2"/><w:shd w:val="clear" w:fill="FF0000"/><w:tcW w:w="5000" w:type="dxa"/>';
const row2Def = '<w:tr><w:trPr><w:gridBefore w:val="0"/></w:trPr><w:tc><w:tcPr><w:gridSpan w:val="2"/><w:vMerge/></w:tcPr><w:p/></w:tc></w:tr>';
DocxTable tb0({String? tblPr = '<w:tblStyle w:val="Plain"/>', String? grid = gridDef, String? trPr = trPrDef, String? tcPr = tcPrDef, String row2 = row2Def, String styleDefs = plainStyle, String? rows}) {
  final pr = tblPr == null ? '' : '<w:tblPr>$tblPr</w:tblPr>';
  final g = grid == null ? '' : '<w:tblGrid>$grid</w:tblGrid>';
  final tr1 = '<w:tr>${trPr == null ? '' : '<w:trPr>$trPr</w:trPr>'}<w:tc>${tcPr == null ? '' : '<w:tcPr>$tcPr</w:tcPr>'}<w:p><w:r><w:t>A</w:t></w:r></w:p></w:tc></w:tr>';
  return blocks('<w:tbl>$pr$g${rows ?? tr1 + row2}</w:tbl>', styles: styleDefs).whereType<DocxTable>().first;
}

void main() {
  group('Đơn vị 1 — _DocxReader.read', () {
    // Đường: D1S D2S D3S → R3
    test('1-1 tài liệu có w:body chứa 1 đoạn và sectPr ngay trong body (pgSz w 12240)', () {
      final res = _run(() => (() { final d = readDocx(buildDocx(body: p('x') + '<w:sectPr><w:pgSz w:w="12240" w:h="15840"/></w:sectPr>')); return (kinds(d.blocks), d.page.widthTwips); })());
      expect(res, equals(('P(x)', 12240)));
    });
    // Đường: D1Đ → R1
    test('1-2 zip không có word/document.xml', () {
      final res = _run(() => readDocx(buildZip({'a.xml': '<a/>'})));
      expect(res, isA<OfficeFormatException>());
    });
    // Đường: D1S D2Đ → R2
    test('1-3 document.xml không có w:body', () {
      final res = _run(() => readDocx(buildZip({'word/document.xml': '<w:document $wNs/>'})));
      expect(res, isA<OfficeFormatException>());
    });
    // Đường: D1S D2S D3Đ → R3
    test('1-4 sectPr chỉ nằm trong pPr của đoạn cuối (pgSz w 15840)', () {
      final res = _run(() => readDocx(buildDocx(body: '<w:p><w:pPr><w:sectPr><w:pgSz w:w="15840" w:h="12240"/></w:sectPr></w:pPr></w:p>')).page.widthTwips);
      expect(res, 15840);
    });
  });
  group('Đơn vị 2 — read — partOf (hàm cục bộ)', () {
    // Đường: D1Đ D2Đ → R1
    test('2-1 rels styles trỏ word/custom.xml (có style H1 = heading 1)', () {
      final res = _run(() => readDocx(buildDocx(body: p('t', pPr: '<w:pStyle w:val="H1"/>'), rels: rel('rS', 'styles', 'custom.xml'), extraParts: {'word/custom.xml': stylesPart(h1Style)})).blocks.whereType<DocxParagraph>().first.headingLevel);
      expect(res, 1);
    });
    // Đường: D1S → R2
    test('2-2 rels styles External ⇒ bỏ; styles ở word/styles.xml mặc định', () {
      final res = _run(() => readDocx(buildDocx(body: p('t', pPr: '<w:pStyle w:val="H1"/>'), styles: h1Style, rels: rel('rS', 'styles', 'http://x/s.xml', ext: true))).blocks.whereType<DocxParagraph>().first.headingLevel);
      expect(res, 1);
    });
    // Đường: D1Đ D2S → R2
    test('2-3 rels chỉ có image ⇒ fallback word/styles.xml', () {
      final res = _run(() => readDocx(buildDocx(body: p('t', pPr: '<w:pStyle w:val="H1"/>'), styles: h1Style, rels: imgRel)).blocks.whereType<DocxParagraph>().first.headingLevel);
      expect(res, 1);
    });
  });
  group('Đơn vị 3 — _DocxReader._findMainPart', () {
    // Đường: D1Đ D2Đ → R1
    test('3-1 _rels/.rels officeDocument → word/doc2.xml (có)', () {
      final res = _run(() => kinds(readDocx(buildZip({'_rels/.rels': rootRels(rel('r1', 'officeDocument', 'word/doc2.xml')), 'word/doc2.xml': docPart(p('main2'))})).blocks));
      expect(res, 'P(main2)');
    });
    // Đường: D1S → R2
    test('3-2 _rels/.rels chỉ có core-properties ⇒ word/document.xml', () {
      final res = _run(() => kinds(readDocx(buildZip({'_rels/.rels': rootRels(rel('r1', 'metadata/core-properties', 'docProps/core.xml')), 'word/document.xml': docPart(p('def'))})).blocks));
      expect(res, 'P(def)');
    });
    // Đường: D1Đ D2S → R2
    test('3-3 officeDocument trỏ part không có ⇒ word/document.xml', () {
      final res = _run(() => kinds(readDocx(buildZip({'_rels/.rels': rootRels(rel('r1', 'officeDocument', 'word/missing.xml')), 'word/document.xml': docPart(p('def'))})).blocks));
      expect(res, 'P(def)');
    });
  });
  group('Đơn vị 4 — _DocxReader._page', () {
    // Đường: D1S → R2
    test('4-1 sectPr pgSz w 12240 + pgMar top 720', () {
      final res = _run(() => (() { final pg = readDocx(buildDocx(body: p('x') + '<w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="720" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr>')).page; return (pg.widthTwips, pg.marginTopTwips); })());
      expect(res, equals((12240, 720)));
    });
    // Đường: D1Đ → R1
    test('4-2 không có sectPr', () {
      final res = _run(() => (() { final pg = readDocx(buildDocx(body: p('x'))).page; return (pg.widthTwips, pg.heightTwips, pg.marginLeftTwips); })());
      expect(res, equals((11906, 16838, 1440)));
    });
  });
  group('Đơn vị 5 — _page — v (hàm cục bộ)', () {
    // Đường: D1S D2S D3S → R1
    test('5-1 pgSz w="-12240"', () {
      final res = _run(() => readDocx(buildDocx(body: p('x') + '<w:sectPr><w:pgSz w:w="-12240" w:h="15840"/></w:sectPr>')).page.widthTwips);
      expect(res, 12240);
    });
    // Đường: D1Đ D2Đ D3Đ → R1
    test('5-2 sectPr không có pgMar', () {
      final res = _run(() => readDocx(buildDocx(body: p('x') + '<w:sectPr><w:pgSz w:w="12240" w:h="15840"/></w:sectPr>')).page.marginTopTwips);
      expect(res, 1440);
    });
    // Đường: D1S D2Đ D3Đ → R1
    test('5-3 pgSz w="abc"', () {
      final res = _run(() => readDocx(buildDocx(body: p('x') + '<w:sectPr><w:pgSz w:w="abc" w:h="15840"/></w:sectPr>')).page.widthTwips);
      expect(res, 11906);
    });
  });
  group('Đơn vị 6 — _DocxReader._blocks', () {
    // Đường: D1S D2S D3S D4S D5S D6S D7S → R1
    test('6-1 body chỉ có w:bookmarkStart', () {
      final res = _run(() => kinds(blocks('<w:bookmarkStart w:id="0" w:name="b"/>')));
      expect(res, '');
    });
    // Đường: D1Đ → R1
    test('6-2 body: 1 đoạn "x"', () {
      final res = _run(() => kinds(blocks('' + p('x') + '')));
      expect(res, 'P(x)');
    });
    // Đường: D1S D2Đ → R1
    test('6-3 body: 1 bảng', () {
      final res = _run(() => kinds(blocks('<w:tbl>' + tr(tc('a')) + '</w:tbl>')));
      expect(res, 'T');
    });
    // Đường: D1S D2S D3Đ D8Đ → R1
    test('6-4 sdt có sdtContent chứa đoạn "s"', () {
      final res = _run(() => kinds(blocks('<w:sdt><w:sdtContent>' + p('s') + '</w:sdtContent></w:sdt>')));
      expect(res, 'P(s)');
    });
    // Đường: D1S D2S D3S D4Đ → R1
    test('6-5 customXml bọc đoạn "c"', () {
      final res = _run(() => kinds(blocks('<w:customXml>' + p('c') + '</w:customXml>')));
      expect(res, 'P(c)');
    });
    // Đường: D1S D2S D3S D4S D5Đ → R1
    test('6-6 w:ins bọc đoạn "i"', () {
      final res = _run(() => kinds(blocks('<w:ins w:id="1">' + p('i') + '</w:ins>')));
      expect(res, 'P(i)');
    });
    // Đường: D1S D2S D3S D4S D5S D6Đ → R1
    test('6-7 w:moveTo bọc đoạn "m"', () {
      final res = _run(() => kinds(blocks('<w:moveTo w:id="1">' + p('m') + '</w:moveTo>')));
      expect(res, 'P(m)');
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7Đ D9Đ → R1
    test('6-8 AlternateContent: Choice (đoạn a) + Fallback (đoạn f)', () {
      final res = _run(() => kinds(blocks('<mc:AlternateContent><mc:Choice Requires="w14">' + p('a') + '</mc:Choice><mc:Fallback>' + p('f') + '</mc:Fallback></mc:AlternateContent>')));
      expect(res, 'P(a)');
    });
    // Đường: D1S D2S D3Đ D8S → R1
    test('6-9 sdt không có sdtContent', () {
      final res = _run(() => kinds(blocks('<w:sdt><w:sdtPr/></w:sdt>')));
      expect(res, '');
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7Đ D9S → R1
    test('6-10 AlternateContent rỗng', () {
      final res = _run(() => kinds(blocks('<mc:AlternateContent/>')));
      expect(res, '');
    });
  });
  group('Đơn vị 7 — _DocxReader._alternate', () {
    // Đường: D1S → R1
    test('7-1 AlternateContent có Choice', () {
      final res = _run(() => kinds(blocks('<mc:AlternateContent><mc:Choice Requires="w14">' + p('a') + '</mc:Choice></mc:AlternateContent>')));
      expect(res, 'P(a)');
    });
    // Đường: D1Đ → R2
    test('7-2 AlternateContent chỉ có Fallback', () {
      final res = _run(() => kinds(blocks('<mc:AlternateContent><mc:Fallback>' + p('f') + '</mc:Fallback></mc:AlternateContent>')));
      expect(res, 'P(f)');
    });
  });
  group('Đơn vị 8 — _DocxReader._paragraph', () {
    // Đường: D1S D2S D3S D8S D10S D11Đ → R1
    test('8-1 pPr có pStyle P1 và pageBreakBefore val=0', () {
      final res = _run(() => (() { final x = para(p('t', pPr: '<w:pStyle w:val="P1"/><w:pageBreakBefore w:val="0"/>')); return (x.styleId, x.pageBreakBefore, x.listLevel, x.headingLevel); })());
      expect(res, equals(('P1', false, null, null)));
    });
    // Đường: D1Đ D2Đ D3S D8S D10S D11Đ → R1
    test('8-2 đoạn không có pPr; style mặc định Normal (pageBreakBefore)', () {
      final res = _run(() => (() { final x = para('<w:p>' + r(t('t')) + '</w:p>', styles: normalPbb); return (x.styleId, x.pageBreakBefore); })());
      expect(res, equals(('Normal', true)));
    });
    // Đường: D1S D2Đ D3S D8S D10S D11Đ → R1
    test('8-3 pPr không có pStyle; style mặc định Normal', () {
      final res = _run(() => (() { final x = para(p('t', pPr: '<w:jc w:val="left"/>'), styles: normalPbb); return (x.styleId, x.pageBreakBefore); })());
      expect(res, equals(('Normal', true)));
    });
    // Đường: D1S D2S D3Đ D4Đ D5Đ D6S D7Đ D8S D10S D11Đ → R1
    test('8-4 numPr numId 1 ilvl 0 (list decimal)', () {
      final res = _run(() => (() { final x = para(p('t', pPr: numPr(1, 0)), numbering: numXml); return (x.listLevel, x.listLabel, x.listOrdered); })());
      expect(res, equals((0, '1.', true)));
    });
    // Đường: D1S D2S D3S D8Đ D9Đ D10S D11Đ → R1
    test('8-5 outlineLvl 0 trực tiếp', () {
      final res = _run(() => para(p('t', pPr: '<w:outlineLvl w:val="0"/>')).headingLevel);
      expect(res, 1);
    });
    // Đường: D1S D2S D3S D8S D10Đ D11Đ → R1
    test('8-6 không có pageBreakBefore ở đâu', () {
      final res = _run(() => para(p('t')).pageBreakBefore);
      expect(res, isFalse);
    });
    // Đường: D1S D2S D3S D8S D10S D11S D12S → R2
    test('8-7 run "a" + br page + "b"', () {
      final res = _run(() => kinds(blocks('<w:p>' + r(t('a') + '<w:br w:type="page"/>' + t('b')) + '</w:p>')));
      expect(res, 'P(a) B P(b)');
    });
    // Đường: D1S D2S D3Đ D4S D8S D10S D11Đ → R1
    test('8-8 numId 0 (tắt list)', () {
      final res = _run(() => para(p('t', pPr: numPr(0, 0)), numbering: numXml).listLevel);
      expect(res, isNull);
    });
    // Đường: D1S D2S D3Đ D4Đ D5S D8S D10S D11Đ → R1
    test('8-9 numId 5 không có trong numbering', () {
      final res = _run(() => para(p('t', pPr: numPr(5, 0)), numbering: numXml).listLevel);
      expect(res, isNull);
    });
    // Đường: D1S D2S D3Đ D4Đ D5Đ D6Đ D7Đ D8S D10S D11Đ → R1
    test('8-10 numPr thiếu ilvl', () {
      final res = _run(() => para(p('t', pPr: numPr(1)), numbering: numXml).listLevel);
      expect(res, 0);
    });
    // Đường: D1S D2S D3Đ D4Đ D5Đ D6S D7S D8S D10S D11Đ → R1
    test('8-11 numId 1 tồn tại nhưng ilvl 3 không định nghĩa', () {
      final res = _run(() => para(p('t', pPr: numPr(1, 3)), numbering: numXml).listLevel);
      expect(res, isNull);
    });
    // Đường: D1S D2S D3S D8Đ D9S D10S D11Đ → R1
    test('8-12 style heading 2 + outlineLvl 9 trực tiếp', () {
      final res = _run(() => para(p('t', pPr: '<w:pStyle w:val="H2"/><w:outlineLvl w:val="9"/>'), styles: '<w:style w:type="paragraph" w:styleId="H2"><w:name w:val="heading 2"/></w:style>').headingLevel);
      expect(res, isNull);
    });
    // Đường: D1S D2S D3S D8S D10S D11S D12Đ → R2
    test('8-13 run bắt đầu bằng br page rồi "b"', () {
      final res = _run(() => kinds(blocks('<w:p>' + r('<w:br w:type="page"/>' + t('b')) + '</w:p>')));
      expect(res, 'B P(b)');
    });
  });
  group('Đơn vị 9 — _paragraph — flush (hàm cục bộ)', () {
    // Đường: D1Đ D2Đ → R1
    test('9-1 đoạn list "a" br page "b" — đoạn đầu', () {
      final res = _run(() => (blocks('<w:p><w:pPr>' + numPr(1, 0) + '</w:pPr>' + r(t('a') + '<w:br w:type="page"/>' + t('b')) + '</w:p>', numbering: numXml).first as DocxParagraph).listLabel);
      expect(res, '1.');
    });
    // Đường: D1S → R1
    test('9-2 đoạn chỉ có br page ở đầu rồi "b"', () {
      final res = _run(() => kinds(blocks('<w:p>' + r('<w:br w:type="page"/>' + t('b')) + '</w:p>')));
      expect(res, 'B P(b)');
    });
    // Đường: D1Đ D2S → R1
    test('9-3 đoạn list + pageBreakBefore, "a" br page "b" — đoạn sau', () {
      final res = _run(() => (() { final x = blocks('<w:p><w:pPr>' + numPr(1, 0) + '<w:pageBreakBefore/></w:pPr>' + r(t('a') + '<w:br w:type="page"/>' + t('b')) + '</w:p>', numbering: numXml).last as DocxParagraph; return (x.plainText, x.listLabel, x.listLevel, x.pageBreakBefore); })());
      expect(res, equals(('b', null, null, false)));
    });
  });
  group('Đơn vị 10 — _DocxReader._align', () {
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10S → R1
    test('10-1 jc left', () {
      final res = _run(() => para(p('t', pPr: '<w:jc w:val="left"/>')).align);
      expect(res, DocxAlign.left);
    });
    // Đường: D1Đ → R2
    test('10-2 jc center', () {
      final res = _run(() => para(p('t', pPr: '<w:jc w:val="center"/>')).align);
      expect(res, DocxAlign.center);
    });
    // Đường: D1S D2Đ → R3
    test('10-3 jc right', () {
      final res = _run(() => para(p('t', pPr: '<w:jc w:val="right"/>')).align);
      expect(res, DocxAlign.right);
    });
    // Đường: D1S D2S D3Đ → R3
    test('10-4 jc end', () {
      final res = _run(() => para(p('t', pPr: '<w:jc w:val="end"/>')).align);
      expect(res, DocxAlign.right);
    });
    // Đường: D1S D2S D3S D4Đ → R4
    test('10-5 jc both', () {
      final res = _run(() => para(p('t', pPr: '<w:jc w:val="both"/>')).align);
      expect(res, DocxAlign.justify);
    });
    // Đường: D1S D2S D3S D4S D5Đ → R4
    test('10-6 jc distribute', () {
      final res = _run(() => para(p('t', pPr: '<w:jc w:val="distribute"/>')).align);
      expect(res, DocxAlign.justify);
    });
    // Đường: D1S D2S D3S D4S D5S D6Đ → R4
    test('10-7 jc justify', () {
      final res = _run(() => para(p('t', pPr: '<w:jc w:val="justify"/>')).align);
      expect(res, DocxAlign.justify);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7Đ → R4
    test('10-8 jc lowKashida', () {
      final res = _run(() => para(p('t', pPr: '<w:jc w:val="lowKashida"/>')).align);
      expect(res, DocxAlign.justify);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8Đ → R4
    test('10-9 jc highKashida', () {
      final res = _run(() => para(p('t', pPr: '<w:jc w:val="highKashida"/>')).align);
      expect(res, DocxAlign.justify);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9Đ → R4
    test('10-10 jc mediumKashida', () {
      final res = _run(() => para(p('t', pPr: '<w:jc w:val="mediumKashida"/>')).align);
      expect(res, DocxAlign.justify);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10Đ → R4
    test('10-11 jc thaiDistribute', () {
      final res = _run(() => para(p('t', pPr: '<w:jc w:val="thaiDistribute"/>')).align);
      expect(res, DocxAlign.justify);
    });
  });
  group('Đơn vị 11 — _DocxReader._inlines', () {
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10S D11S D12S D13S → R1
    test('11-1 đoạn chỉ có bookmarkStart', () {
      final res = _run(() => inl('<w:bookmarkStart w:id="0" w:name="b"/>'));
      expect(res, isEmpty);
    });
    // Đường: D1Đ → R1
    test('11-2 run "x"', () {
      final res = _run(() => txt(r(t('x'))));
      expect(res, 'x');
    });
    // Đường: D1S D2Đ D14S D16Đ D17S D18Đ → R1
    test('11-3 hyperlink không có r:id/anchor', () {
      final res = _run(() => (inl('<w:hyperlink>' + r(t('L')) + '</w:hyperlink>').single as DocxRun).hyperlink);
      expect(res, isNull);
    });
    // Đường: D1S D2S D3Đ → R1
    test('11-4 w:ins bọc run', () {
      final res = _run(() => txt('<w:ins w:id="1">' + r(t('i')) + '</w:ins>'));
      expect(res, 'i');
    });
    // Đường: D1S D2S D3S D4Đ → R1
    test('11-5 w:moveTo bọc run', () {
      final res = _run(() => txt('<w:moveTo w:id="1">' + r(t('m')) + '</w:moveTo>'));
      expect(res, 'm');
    });
    // Đường: D1S D2S D3S D4S D5Đ → R1
    test('11-6 smartTag bọc run', () {
      final res = _run(() => txt('<w:smartTag w:element="x">' + r(t('s')) + '</w:smartTag>'));
      expect(res, 's');
    });
    // Đường: D1S D2S D3S D4S D5S D6Đ → R1
    test('11-7 customXml bọc run', () {
      final res = _run(() => txt('<w:customXml>' + r(t('c')) + '</w:customXml>'));
      expect(res, 'c');
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7Đ → R1
    test('11-8 fldSimple PAGE có kết quả "3"', () {
      final res = _run(() => txt('<w:fldSimple w:instr="PAGE">' + r(t('3')) + '</w:fldSimple>'));
      expect(res, '3');
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8Đ → R1
    test('11-9 w:dir bọc run', () {
      final res = _run(() => txt('<w:dir w:val="rtl">' + r(t('d')) + '</w:dir>'));
      expect(res, 'd');
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9Đ → R1
    test('11-10 w:bdo bọc run', () {
      final res = _run(() => txt('<w:bdo w:val="rtl">' + r(t('b')) + '</w:bdo>'));
      expect(res, 'b');
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10Đ D19Đ → R1
    test('11-11 sdt có sdtContent chứa run', () {
      final res = _run(() => txt('<w:sdt><w:sdtContent>' + r(t('s')) + '</w:sdtContent></w:sdt>'));
      expect(res, 's');
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10S D11Đ D20Đ → R1
    test('11-12 AlternateContent Choice chứa run', () {
      final res = _run(() => txt('<mc:AlternateContent><mc:Choice Requires="w14">' + r(t('a')) + '</mc:Choice></mc:AlternateContent>'));
      expect(res, 'a');
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10S D11S D12Đ D21Đ D22Đ → R1
    test('11-13 m:oMath có m:t "x+1"', () {
      final res = _run(() => txt(math('oMath', 'x+1')));
      expect(res, 'x+1');
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10S D11S D12S D13Đ D21Đ D22Đ → R1
    test('11-14 m:oMathPara có m:t "y"', () {
      final res = _run(() => txt(math('oMathPara', 'y')));
      expect(res, 'y');
    });
    // Đường: D1S D2Đ D14Đ D15S D16S D18S → R1
    test('11-15 hyperlink r:id rH → https://x.vn', () {
      final res = _run(() => (inl('<w:hyperlink r:id="rH">' + r(t('L')) + '</w:hyperlink>', rels: rel('rH', 'hyperlink', 'https://x.vn', ext: true)).single as DocxRun).hyperlink);
      expect(res, 'https://x.vn');
    });
    // Đường: D1S D2Đ D14S D16Đ D17Đ D18S → R1
    test('11-17 hyperlink w:anchor muc1', () {
      final res = _run(() => (inl('<w:hyperlink w:anchor="muc1">' + r(t('L')) + '</w:hyperlink>').single as DocxRun).hyperlink);
      expect(res, '#muc1');
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10Đ D19S → R1
    test('11-19 sdt không có sdtContent', () {
      final res = _run(() => inl('<w:sdt><w:sdtPr/></w:sdt>'));
      expect(res, isEmpty);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10S D11Đ D20S → R1
    test('11-20 AlternateContent rỗng', () {
      final res = _run(() => inl('<mc:AlternateContent/>'));
      expect(res, isEmpty);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10S D11S D12Đ D21S → R1
    test('11-21 oMath không có chữ', () {
      final res = _run(() => inl(math('oMath', '')));
      expect(res, isEmpty);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10S D11S D12Đ D21Đ D22S → R1
    test('11-22 oMath nằm trong phần mã field', () {
      final res = _run(() => txt(fb + math('oMath', 'z') + fe));
      expect(res, '');
    });
    // Đường: D1S D2Đ D14Đ D15Đ D16Đ D17S D18Đ → R1
    test('11-23 hyperlink r:id không có trong rels, không anchor', () {
      final res = _run(() => (inl('<w:hyperlink r:id="rX">' + r(t('L')) + '</w:hyperlink>').single as DocxRun).hyperlink);
      expect(res, isNull);
    });
  });
  group('Đơn vị 12 — _DocxReader._runProps', () {
    // Đường: D1S → R1
    test('12-1 run b trực tiếp, không rStyle', () {
      final res = _run(() => (inl(r(t('x'), '<w:b/>')).single as DocxRun).bold);
      expect(res, isTrue);
    });
    // Đường: D1Đ → R1
    test('12-2 run rStyle Strong (style ký tự b)', () {
      final res = _run(() => (inl(r(t('x'), '<w:rStyle w:val="Strong"/>'), styles: '<w:style w:type="character" w:styleId="Strong"><w:rPr><w:b/></w:rPr></w:style>').single as DocxRun).bold);
      expect(res, isTrue);
    });
  });
  group('Đơn vị 13 — _DocxReader._run', () {
    // Đường: D1S → R1
    test('13-1 run w:vanish', () {
      final res = _run(() => txt(r(t('h'), '<w:vanish/>') + r(t('v'))));
      expect(res, 'v');
    });
    // Đường: D1Đ → R1
    test('13-2 run không có vanish', () {
      final res = _run(() => txt(r(t('v'))));
      expect(res, 'v');
    });
  });
  group('Đơn vị 14 — _run — flush (hàm cục bộ)', () {
    // Đường: D1Đ D2Đ → R1
    test('14-1 run "a"', () {
      final res = _run(() => inl(r(t('a'))).single);
      expect(res, isA<DocxRun>().having((x) => x.text, 'text', 'a'));
    });
    // Đường: D1S → R1
    test('14-2 run chỉ có <w:br/>', () {
      final res = _run(() => inl(r('<w:br/>')));
      expect(res, hasLength(1));
    });
    // Đường: D1Đ D2S → R1
    test('14-3 run w:vanish có chữ "h" và <w:br/>', () {
      final res = _run(() => inl(r(t('h') + '<w:br/>', '<w:vanish/>')));
      expect(res, isEmpty);
    });
  });
  group('Đơn vị 15 — _run — walk (hàm cục bộ)', () {
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10S D11S D12S → R1
    test('15-1 inl(\'<w:r><w:lastRenderedPageBreak/></w:r>\')', () {
      final res = _run(() => inl('<w:r><w:lastRenderedPageBreak/></w:r>'));
      expect(res, isEmpty);
    });
    // Đường: D1Đ W1Đ → R1
    test('15-2 w:t "a"', () {
      final res = _run(() => txt(r(t('a'))));
      expect(res, 'a');
    });
    // Đường: D1S D2Đ W2Đ → R1
    test('15-3 w:tab', () {
      final res = _run(() => txt(r(t('a') + '<w:tab/>' + t('b'))));
      expect(res, 'a\tb');
    });
    // Đường: D1S D2S D3Đ W2Đ → R1
    test('15-4 w:ptab', () {
      final res = _run(() => txt(r(t('a') + '<w:ptab w:alignment="right" w:relativeTo="margin" w:leader="none"/>' + t('b'))));
      expect(res, 'a\tb');
    });
    // Đường: D1S D2S D3S D4Đ W3Đ → R1
    test('15-5 w:noBreakHyphen', () {
      final res = _run(() => txt(r(t('a') + '<w:noBreakHyphen/>' + t('b'))));
      expect(res, 'a-b');
    });
    // Đường: D1S D2S D3S D4S D5Đ W4S W5Đ W6Đ W7S → R1
    test('15-6 sym char 0041', () {
      final res = _run(() => txt(r('<w:sym w:font="Arial" w:char="0041"/>')));
      expect(res, 'A');
    });
    // Đường: D1S D2S D3S D4S D5S D6Đ W9S W10S → R1
    test('15-7 w:br thường', () {
      final res = _run(() => inl(r(t('a') + '<w:br/>' + t('b'))).map((e) => e.runtimeType.toString()).join(','));
      expect(res, 'DocxRun,DocxBreak,DocxRun');
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7Đ W11S → R1
    test('15-8 w:cr', () {
      final res = _run(() => txt(r(t('a') + '<w:cr/>' + t('b'))));
      expect(res, 'a\nb');
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8Đ W12S W13Đ → R1
    test('15-9 drawing inline có ảnh', () {
      final res = _run(() => img1(r(drawing('inline', ext + blip('rI')))));
      expect(res, isA<DocxImage>());
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9Đ W14S W15Đ → R1
    test('15-10 w:pict VML có ảnh', () {
      final res = _run(() => img1(r(vml('width:72pt;height:36pt'))));
      expect(res, isA<DocxImage>());
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10Đ W14S W15Đ → R1
    test('15-11 w:object VML có ảnh', () {
      final res = _run(() => img1(r(vml('width:72pt;height:36pt').replaceAll('w:pict', 'w:object'))));
      expect(res, isA<DocxImage>());
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10S D11Đ W16Đ → R1
    test('15-12 field begin…separate…end, kết quả "3"', () {
      final res = _run(() => txt(fb + r('<w:instrText>PAGE</w:instrText>' + t('CODE')) + fs + r(t('3')) + fe));
      expect(res, '3');
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10S D11S D12Đ W21Đ → R1
    test('15-13 AlternateContent trong run', () {
      final res = _run(() => txt(r('<mc:AlternateContent><mc:Choice Requires="w14">' + t('c') + '</mc:Choice></mc:AlternateContent>')));
      expect(res, 'c');
    });
    // Đường: D1Đ W1S → R1
    test('15-14 w:t trong phần mã field', () {
      final res = _run(() => txt(fb + r(t('CODE')) + fs + r(t('R')) + fe));
      expect(res, 'R');
    });
    // Đường: D1S D2Đ W2S → R1
    test('15-15 w:tab trong mã field', () {
      final res = _run(() => txt(fb + r('<w:tab/>') + fs + r(t('R')) + fe));
      expect(res, 'R');
    });
    // Đường: D1S D2S D3S D4Đ W3S → R1
    test('15-16 noBreakHyphen trong mã field', () {
      final res = _run(() => txt(fb + r('<w:noBreakHyphen/>') + fs + r(t('R')) + fe));
      expect(res, 'R');
    });
    // Đường: D1S D2S D3S D4S D5Đ W4Đ W5S → R1
    test('15-17 sym thiếu char', () {
      final res = _run(() => txt(r('<w:sym w:font="Symbol"/>')));
      expect(res, '');
    });
    // Đường: D1S D2S D3S D4S D5Đ W4S W5S → R1
    test('15-18 sym char không phải hex', () {
      final res = _run(() => txt(r('<w:sym w:font="Symbol" w:char="zz"/>')));
      expect(res, '');
    });
    // Đường: D1S D2S D3S D4S D5Đ W4S W5Đ W6S → R1
    test('15-19 sym trong mã field', () {
      final res = _run(() => txt(fb + r('<w:sym w:font="Arial" w:char="0041"/>') + fs + r(t('R')) + fe));
      expect(res, 'R');
    });
    // Đường: D1S D2S D3S D4S D5Đ W4S W5Đ W6Đ W7Đ W8Đ → R1
    test('15-20 sym F0B7 (Symbol, vùng PUA)', () {
      final res = _run(() => txt(r('<w:sym w:font="Symbol" w:char="F0B7"/>')));
      expect(res, '•');
    });
    // Đường: D1S D2S D3S D4S D5S D6Đ W9Đ → R1
    test('15-21 br trong mã field', () {
      final res = _run(() => inl(fb + r('<w:br/>') + fs + r(t('R')) + fe).length);
      expect(res, 1);
    });
    // Đường: D1S D2S D3S D4S D5S D6Đ W9S W10Đ → R1
    test('15-22 br type page', () {
      final res = _run(() => kinds(blocks('<w:p>' + r(t('a') + '<w:br w:type="page"/>' + t('b')) + '</w:p>')));
      expect(res, 'P(a) B P(b)');
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7Đ W11Đ → R1
    test('15-23 cr trong mã field', () {
      final res = _run(() => inl(fb + r('<w:cr/>') + fs + r(t('R')) + fe).length);
      expect(res, 1);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8Đ W12Đ → R1
    test('15-24 drawing trong mã field', () {
      final res = _run(() => img1(fb + r(drawing('inline', ext + blip('rI'))) + fs + r(t('R')) + fe));
      expect(res, isNull);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8Đ W12S W13S → R1
    test('15-25 drawing không có blip', () {
      final res = _run(() => img1(r(drawing('inline', ext))));
      expect(res, isNull);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9Đ W14Đ → R1
    test('15-26 pict trong mã field', () {
      final res = _run(() => img1(fb + r(vml('width:72pt')) + fs + r(t('R')) + fe));
      expect(res, isNull);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9Đ W14S W15S → R1
    test('15-27 pict không có imagedata', () {
      final res = _run(() => img1(r('<w:pict><v:shape xmlns:v="urn:schemas-microsoft-com:vml" style="width:1pt"/></w:pict>')));
      expect(res, isNull);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10S D11Đ W16S W17S W19Đ W20Đ → R1
    test('15-28 field begin…end (không separate) rồi chữ thường', () {
      final res = _run(() => txt(fb + r(t('C')) + fe + r(t('after'))));
      expect(res, 'after');
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10S D11S D12Đ W21S → R1
    test('15-29 AlternateContent rỗng trong run', () {
      final res = _run(() => inl(r('<mc:AlternateContent/>')));
      expect(res, isEmpty);
    });
    // Đường: D1S D2S D3S D4S D5Đ W4S W5Đ W6Đ W7Đ W8S → R1
    test('15-30 sym F100 (ngoài F000–F0FF)', () {
      final res = _run(() => txt(r('<w:sym w:font="X" w:char="F100"/>')));
      expect(res, '\uF100');
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10S D11Đ W16S W17Đ W18Đ → R1
    test('15-31 separate khi đang trong field', () {
      final res = _run(() => txt(fb + r(t('C')) + fs + r(t('R')) + fe));
      expect(res, 'R');
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10S D11Đ W16S W17S W19S → R1
    test('15-32 fldChar không có fldCharType', () {
      final res = _run(() => txt(r('<w:fldChar/>') + r(t('x'))));
      expect(res, 'x');
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10S D11Đ W16S W17S W19Đ W20S → R1
    test('15-33 fldChar end khi không có field mở', () {
      final res = _run(() => txt(fe + r(t('x'))));
      expect(res, 'x');
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10S D11Đ W16S W17Đ W18S → R1
    test('15-34 fldChar separate khi không có field mở', () {
      final res = _run(() => txt(fs + r(t('x'))));
      expect(res, 'x');
    });
  });
  group('Đơn vị 16 — _DocxReader._drawing', () {
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S → R2
    test('16-1 wp:inline có extent 914400×457200 + blip rI', () {
      final res = _run(() => img1(r(drawing('inline', ext + blip('rI')))));
      expect(res, isA<DocxImage>().having((i) => i.widthEmu, 'w', 914400).having((i) => i.heightEmu, 'h', 457200).having((i) => i.floating, 'floating', isFalse));
    });
    // Đường: D1Đ D2S D3S D4S D5S D6S D7S D8S → R2
    test('16-2 wp:anchor (không inline)', () {
      final res = _run(() => img1(r(drawing('anchor', ext + blip('rI'))))?.floating);
      expect(res, isTrue);
    });
    // Đường: D1S D2S D3Đ D4Đ → R1
    test('16-4 không có a:blip', () {
      final res = _run(() => img1(r(drawing('inline', ext))));
      expect(res, isNull);
    });
    // Đường: D1S D2S D3S D4Đ → R1
    test('16-5 a:blip không có r:embed (chỉ r:link)', () {
      final res = _run(() => img1(r(drawing('inline', ext + blip('rI').replaceAll('r:embed', 'r:link')))));
      expect(res, isNull);
    });
    // Đường: D1S D2S D3S D4S D5Đ D6Đ D7Đ D8Đ → R2
    test('16-6 không có wp:extent', () {
      final res = _run(() => (() { final i = img1(r(drawing('inline', blip('rI'))))!; return (i.widthEmu, i.heightEmu); })());
      expect(res, equals((0, 0)));
    });
    // Đường: D1S D2S D3S D4S D5S D6Đ D7S D8S → R2
    test('16-7 extent thiếu cx', () {
      final res = _run(() => (() { final i = img1(r(drawing('inline', '<wp:extent cy="457200"/>' + blip('rI'))))!; return (i.widthEmu, i.heightEmu); })());
      expect(res, equals((0, 457200)));
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8Đ → R2
    test('16-9 extent thiếu cy', () {
      final res = _run(() => (() { final i = img1(r(drawing('inline', '<wp:extent cx="914400"/>' + blip('rI'))))!; return (i.widthEmu, i.heightEmu); })());
      expect(res, equals((914400, 0)));
    });
  });
  group('Đơn vị 17 — _DocxReader._vml', () {
    // Đường: D1S D2S D3S D4S → R2
    test('17-1 VML style width:72pt;height:36pt', () {
      final res = _run(() => (() { final i = img1(r(vml('width:72pt;height:36pt')))!; return (i.widthEmu, i.heightEmu, i.floating); })());
      expect(res, equals((914400, 457200, false)));
    });
    // Đường: D1Đ D2Đ → R1
    test('17-2 pict không có imagedata', () {
      final res = _run(() => img1(r('<w:pict><v:shape xmlns:v="urn:schemas-microsoft-com:vml" style="width:1pt"/></w:pict>')));
      expect(res, isNull);
    });
    // Đường: D1S D2Đ → R1
    test('17-3 imagedata không có r:id', () {
      final res = _run(() => img1(r(vml('width:1pt').replaceAll(' r:id="rI"', ''))));
      expect(res, isNull);
    });
    // Đường: D1S D2S D3Đ D4Đ → R2
    test('17-4 pict chỉ có imagedata (không có shape)', () {
      final res = _run(() => (() { final i = img1(r('<w:pict><v:imagedata xmlns:v="urn:schemas-microsoft-com:vml" r:id="rI"/></w:pict>'))!; return (i.widthEmu, i.heightEmu); })());
      expect(res, equals((0, 0)));
    });
    // Đường: D1S D2S D3S D4Đ → R2
    test('17-5 shape không có style', () {
      final res = _run(() => (() { final i = img1(r(vml('').replaceAll(' style=""', '')))!; return (i.widthEmu, i.heightEmu); })());
      expect(res, equals((0, 0)));
    });
  });
  group('Đơn vị 18 — _vml — emu (hàm cục bộ)', () {
    // Đường: D1S D2S D3S D4S D5S D6S D7S → R2
    test('18-1 width:96px;height:48px', () {
      final res = _run(() => (() { final i = img1(r(vml('width:96px;height:48px')))!; return (i.widthEmu, i.heightEmu); })());
      expect(res, equals((914400, 457200)));
    });
    // Đường: D1Đ → R1
    test('18-2 style không có width', () {
      final res = _run(() => img1(r(vml('height:36pt')))!.widthEmu);
      expect(res, 0);
    });
    // Đường: D1S D2Đ → R3
    test('18-3 width:1.2.3pt (số hỏng)', () {
      final res = _run(() => img1(r(vml('width:1.2.3pt;height:36pt')))?.heightEmu);
      expect(res, 457200);
    });
    // Đường: D1S D2S D3Đ D4S D5S D6S D7S → R2
    test('18-4 width:50 (không đơn vị ⇒ px)', () {
      final res = _run(() => img1(r(vml('width:50;height:1pt')))!.widthEmu);
      expect(res, 476250);
    });
    // Đường: D1S D2S D3S D4Đ → R2
    test('18-5 width:72pt', () {
      final res = _run(() => img1(r(vml('width:72pt')))!.widthEmu);
      expect(res, 914400);
    });
    // Đường: D1S D2S D3S D4S D5Đ → R2
    test('18-6 width:1in', () {
      final res = _run(() => img1(r(vml('width:1in')))!.widthEmu);
      expect(res, 914400);
    });
    // Đường: D1S D2S D3S D4S D5S D6Đ → R2
    test('18-7 width:2.54cm', () {
      final res = _run(() => img1(r(vml('width:2.54cm')))!.widthEmu);
      expect(res, 914400);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7Đ → R2
    test('18-8 width:25.4mm', () {
      final res = _run(() => img1(r(vml('width:25.4mm')))!.widthEmu);
      expect(res, 914400);
    });
  });
  group('Đơn vị 19 — _DocxReader._image', () {
    // Đường: D1S D2S D3S D4S → R2
    test('19-1 rel nội bộ media/i.png có bytes', () {
      final res = _run(() => (() { final i = img1(r(drawing('inline', ext + blip('rI'))))!; return (i.extension, i.bytes.length); })());
      expect(res, equals(('png', tinyPng.length)));
    });
    // Đường: D1Đ → R1
    test('19-2 r:embed trỏ rId không có', () {
      final res = _run(() => img1(r(drawing('inline', ext + blip('rZ')))));
      expect(res, isNull);
    });
    // Đường: D1S D2Đ → R1
    test('19-3 rel External', () {
      final res = _run(() => inl(r(drawing('inline', ext + blip('rE'))), rels: rel('rE', 'image', 'http://x/a.png', ext: true)).whereType<DocxImage>().firstOrNull);
      expect(res, isNull);
    });
    // Đường: D1S D2S D3Đ → R1
    test('19-4 rel nội bộ nhưng file media không có', () {
      final res = _run(() => inl(r(drawing('inline', ext + blip('rI'))), rels: imgRel).whereType<DocxImage>().firstOrNull);
      expect(res, isNull);
    });
    // Đường: D1S D2S D3S D4Đ → R2
    test('19-5 media không có đuôi (media/img)', () {
      final res = _run(() => inl(r(drawing('inline', ext + blip('rN'))), rels: rel('rN', 'image', 'media/img'), media: {'media/img': tinyPng}).whereType<DocxImage>().first.extension);
      expect(res, '');
    });
  });
  group('Đơn vị 20 — _DocxReader._table', () {
    // Đường: D1S D3S D2S D4S D5S D6S D7Đ D8S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20Đ D21S D23S D25S D26S D27S D28S D29Đ D30S D31S D32S D33S D35S D36Đ D37Đ D38S D39Đ D40S D41S D39S D42Đ D37S D36S → R1
    test('20-1 bảng chuẩn: tblStyle Plain (viền none), grid 2000/3000, hàng 1 trHeight 400, ô gridSpan 2 + shd FF0000 + tcW 5000 dxa; hàng 2 ô vMerge ', () {
      final res = _run(() => tb0());
      expect(res, isA<DocxTable>().having((x) => x.columnWidthsTwips, 'grid', equals([2000, 3000])).having((x) => x.bordered, 'bordered', isFalse).having((x) => x.rows.first.heightTwips, 'height', 400).having((x) => x.rows.first.isHeader, 'header', isFalse).having((x) => x.rows.first.cells.first.gridSpan, 'gridSpan', 2).having((x) => x.rows.first.cells.first.shadingArgb, 'shading', 0xFFFF0000).having((x) => x.rows.first.cells.first.widthTwips, 'width', 5000).having((x) => x.rows.first.cells.first.vMergeContinue, 'vMergeContinue', isFalse).having((x) => x.rows.first.cells.first.rowSpan, 'rowSpan', 2));
    });
    // Đường: D1Đ D2Đ D4S D5S D6S D7Đ D8S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20Đ D21S D23S D25S D26S D27S D28S D29Đ D30S D31S D32S D33S D35S D36Đ D37Đ D38S D39Đ D40S D41S D39S D42Đ D37S D36S → R1
    test('20-2 không có tblGrid', () {
      final res = _run(() => tb0(grid: null));
      expect(res, isA<DocxTable>().having((x) => x.columnWidthsTwips, 'grid', isEmpty).having((x) => x.bordered, 'bordered', isFalse).having((x) => x.rows.first.heightTwips, 'height', 400).having((x) => x.rows.first.isHeader, 'header', isFalse).having((x) => x.rows.first.cells.first.gridSpan, 'gridSpan', 2).having((x) => x.rows.first.cells.first.shadingArgb, 'shading', 0xFFFF0000).having((x) => x.rows.first.cells.first.widthTwips, 'width', 5000).having((x) => x.rows.first.cells.first.vMergeContinue, 'vMergeContinue', isFalse).having((x) => x.rows.first.cells.first.rowSpan, 'rowSpan', 2));
    });
    // Đường: D1S D3Đ D2S D4S D5S D6S D7Đ D8S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20Đ D21S D23S D25S D26S D27S D28S D29Đ D30S D31S D32S D33S D35S D36Đ D37Đ D38S D39Đ D40S D41S D39S D42Đ D37S D36S → R1
    test('20-3 gridCol đầu thiếu w', () {
      final res = _run(() => tb0(grid: '<w:gridCol/><w:gridCol w:w="3000"/>'));
      expect(res, isA<DocxTable>().having((x) => x.columnWidthsTwips, 'grid', equals([0, 3000])).having((x) => x.bordered, 'bordered', isFalse).having((x) => x.rows.first.heightTwips, 'height', 400).having((x) => x.rows.first.isHeader, 'header', isFalse).having((x) => x.rows.first.cells.first.gridSpan, 'gridSpan', 2).having((x) => x.rows.first.cells.first.shadingArgb, 'shading', 0xFFFF0000).having((x) => x.rows.first.cells.first.widthTwips, 'width', 5000).having((x) => x.rows.first.cells.first.vMergeContinue, 'vMergeContinue', isFalse).having((x) => x.rows.first.cells.first.rowSpan, 'rowSpan', 2));
    });
    // Đường: D1S D3S D2S D4Đ D5Đ D6S D7Đ D8Đ D9S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20Đ D21S D23S D25S D26S D27S D28S D29Đ D30S D31S D32S D33S D35S D36Đ D37Đ D38S D39Đ D40S D41S D39S D42Đ D37S D36S → R1
    test('20-5 không có tblPr', () {
      final res = _run(() => tb0(tblPr: null));
      expect(res, isA<DocxTable>().having((x) => x.columnWidthsTwips, 'grid', equals([2000, 3000])).having((x) => x.bordered, 'bordered', isFalse).having((x) => x.rows.first.heightTwips, 'height', 400).having((x) => x.rows.first.isHeader, 'header', isFalse).having((x) => x.rows.first.cells.first.gridSpan, 'gridSpan', 2).having((x) => x.rows.first.cells.first.shadingArgb, 'shading', 0xFFFF0000).having((x) => x.rows.first.cells.first.widthTwips, 'width', 5000).having((x) => x.rows.first.cells.first.vMergeContinue, 'vMergeContinue', isFalse).having((x) => x.rows.first.cells.first.rowSpan, 'rowSpan', 2));
    });
    // Đường: D1S D3S D2S D4S D5S D6Đ D7S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20Đ D21S D23S D25S D26S D27S D28S D29Đ D30S D31S D32S D33S D35S D36Đ D37Đ D38S D39Đ D40S D41S D39S D42Đ D37S D36S → R1
    test('20-7 tblBorders trực tiếp toàn none', () {
      final res = _run(() => tb0(tblPr: '<w:tblStyle w:val="Plain"/><w:tblBorders><w:top w:val="none"/></w:tblBorders>'));
      expect(res, isA<DocxTable>().having((x) => x.columnWidthsTwips, 'grid', equals([2000, 3000])).having((x) => x.bordered, 'bordered', isFalse).having((x) => x.rows.first.heightTwips, 'height', 400).having((x) => x.rows.first.isHeader, 'header', isFalse).having((x) => x.rows.first.cells.first.gridSpan, 'gridSpan', 2).having((x) => x.rows.first.cells.first.shadingArgb, 'shading', 0xFFFF0000).having((x) => x.rows.first.cells.first.widthTwips, 'width', 5000).having((x) => x.rows.first.cells.first.vMergeContinue, 'vMergeContinue', isFalse).having((x) => x.rows.first.cells.first.rowSpan, 'rowSpan', 2));
    });
    // Đường: D1S D3S D2S D4S D5S D6S D7Đ D8Đ D9S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20Đ D21S D23S D25S D26S D27S D28S D29Đ D30S D31S D32S D33S D35S D36Đ D37Đ D38S D39Đ D40S D41S D39S D42Đ D37S D36S → R1
    test('20-9 tblPr không có tblStyle', () {
      final res = _run(() => tb0(tblPr: '<w:tblW w:w="0"/>'));
      expect(res, isA<DocxTable>().having((x) => x.columnWidthsTwips, 'grid', equals([2000, 3000])).having((x) => x.bordered, 'bordered', isFalse).having((x) => x.rows.first.heightTwips, 'height', 400).having((x) => x.rows.first.isHeader, 'header', isFalse).having((x) => x.rows.first.cells.first.gridSpan, 'gridSpan', 2).having((x) => x.rows.first.cells.first.shadingArgb, 'shading', 0xFFFF0000).having((x) => x.rows.first.cells.first.widthTwips, 'width', 5000).having((x) => x.rows.first.cells.first.vMergeContinue, 'vMergeContinue', isFalse).having((x) => x.rows.first.cells.first.rowSpan, 'rowSpan', 2));
    });
    // Đường: D1S D3S D2S D4S D5S D6S D7Đ D8S D11Đ D12S D13S D14S D15S D16S D17S D18S D19S D20Đ D21S D23S D25S D26S D27S D28S D29Đ D30S D31Đ D32Đ D33S D35Đ D36Đ D37Đ D38S D39Đ D40S D41S D39S D42Đ D37S D36S → R1
    test('20-10 hàng 1 không có trPr', () {
      final res = _run(() => tb0(trPr: null));
      expect(res, isA<DocxTable>().having((x) => x.columnWidthsTwips, 'grid', equals([2000, 3000])).having((x) => x.bordered, 'bordered', isFalse).having((x) => x.rows.first.heightTwips, 'height', isNull).having((x) => x.rows.first.isHeader, 'header', isFalse).having((x) => x.rows.first.cells.first.gridSpan, 'gridSpan', 2).having((x) => x.rows.first.cells.first.shadingArgb, 'shading', 0xFFFF0000).having((x) => x.rows.first.cells.first.widthTwips, 'width', 5000).having((x) => x.rows.first.cells.first.vMergeContinue, 'vMergeContinue', isFalse).having((x) => x.rows.first.cells.first.rowSpan, 'rowSpan', 2));
    });
    // Đường: D1S D3S D2S D4S D5S D6S D7Đ D8S D11S D12Đ D13S D14S D15S D16S D17S D18S D19S D20Đ D21S D23S D25S D26S D27S D28S D29Đ D30S D31S D32S D33S D35S D36Đ D37Đ D38S D39Đ D40S D41S D39S D42Đ D37S D36S → R1
    test('20-11 trPr không có gridBefore', () {
      final res = _run(() => tb0(trPr: '<w:trHeight w:val="400"/>'));
      expect(res, isA<DocxTable>().having((x) => x.columnWidthsTwips, 'grid', equals([2000, 3000])).having((x) => x.bordered, 'bordered', isFalse).having((x) => x.rows.first.heightTwips, 'height', 400).having((x) => x.rows.first.isHeader, 'header', isFalse).having((x) => x.rows.first.cells.first.gridSpan, 'gridSpan', 2).having((x) => x.rows.first.cells.first.shadingArgb, 'shading', 0xFFFF0000).having((x) => x.rows.first.cells.first.widthTwips, 'width', 5000).having((x) => x.rows.first.cells.first.vMergeContinue, 'vMergeContinue', isFalse).having((x) => x.rows.first.cells.first.rowSpan, 'rowSpan', 2));
    });
    // Đường: D1S D3S D2S D4S D5S D6S D7Đ D8S D11S D12S D13Đ D14Đ D15Đ D16Đ D18Đ D19Đ D20Đ D21S D23S D25Đ D27S D28S D29Đ D30S D31S D32S D33S D35S D36Đ D37Đ D38S D39Đ D40S D41S D39S D42Đ D37S D36S → R1
    test('20-12 ô 1 không có tcPr', () {
      final res = _run(() => tb0(tcPr: null));
      expect(res, isA<DocxTable>().having((x) => x.columnWidthsTwips, 'grid', equals([2000, 3000])).having((x) => x.bordered, 'bordered', isFalse).having((x) => x.rows.first.heightTwips, 'height', 400).having((x) => x.rows.first.isHeader, 'header', isFalse).having((x) => x.rows.first.cells.first.gridSpan, 'gridSpan', 1).having((x) => x.rows.first.cells.first.shadingArgb, 'shading', isNull).having((x) => x.rows.first.cells.first.widthTwips, 'width', isNull).having((x) => x.rows.first.cells.first.vMergeContinue, 'vMergeContinue', isFalse).having((x) => x.rows.first.cells.first.rowSpan, 'rowSpan', 2));
    });
    // Đường: D1S D3S D2S D4S D5S D6S D7Đ D8S D11S D12S D13S D14Đ D15S D16S D17S D18S D19S D20Đ D21S D23S D25S D26S D27S D28S D29Đ D30S D31S D32S D33S D35S D36Đ D37Đ D38S D39Đ D40S D41S D39S D42Đ D37S D36S → R1
    test('20-13 tcPr không có gridSpan', () {
      final res = _run(() => tb0(tcPr: '<w:shd w:val="clear" w:fill="FF0000"/><w:tcW w:w="5000" w:type="dxa"/>'));
      expect(res, isA<DocxTable>().having((x) => x.columnWidthsTwips, 'grid', equals([2000, 3000])).having((x) => x.bordered, 'bordered', isFalse).having((x) => x.rows.first.heightTwips, 'height', 400).having((x) => x.rows.first.isHeader, 'header', isFalse).having((x) => x.rows.first.cells.first.gridSpan, 'gridSpan', 1).having((x) => x.rows.first.cells.first.shadingArgb, 'shading', 0xFFFF0000).having((x) => x.rows.first.cells.first.widthTwips, 'width', 5000).having((x) => x.rows.first.cells.first.vMergeContinue, 'vMergeContinue', isFalse).having((x) => x.rows.first.cells.first.rowSpan, 'rowSpan', 2));
    });
    // Đường: D1S D3S D2S D4S D5S D6S D7Đ D8S D11S D12S D13S D14S D15S D16S D17Đ D18S D19S D20Đ D21S D23S D25Đ D27S D28S D29Đ D30S D31S D32S D33S D35S D36Đ D37Đ D38S D39Đ D40S D41S D39S D42Đ D37S D36S → R1
    test('20-16 tcPr không có shd', () {
      final res = _run(() => tb0(tcPr: '<w:gridSpan w:val="2"/><w:tcW w:w="5000" w:type="dxa"/>'));
      expect(res, isA<DocxTable>().having((x) => x.columnWidthsTwips, 'grid', equals([2000, 3000])).having((x) => x.bordered, 'bordered', isFalse).having((x) => x.rows.first.heightTwips, 'height', 400).having((x) => x.rows.first.isHeader, 'header', isFalse).having((x) => x.rows.first.cells.first.gridSpan, 'gridSpan', 2).having((x) => x.rows.first.cells.first.shadingArgb, 'shading', isNull).having((x) => x.rows.first.cells.first.widthTwips, 'width', 5000).having((x) => x.rows.first.cells.first.vMergeContinue, 'vMergeContinue', isFalse).having((x) => x.rows.first.cells.first.rowSpan, 'rowSpan', 2));
    });
    // Đường: D1S D3S D2S D4S D5S D6S D7Đ D8S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20S D23S D25S D26S D27S D28S D29Đ D30S D31S D32S D33S D35S D36Đ D37Đ D38S D39Đ D40S D41S D39S D42Đ D37S D36S → R1
    test('20-19 style Plain có viền single ⇒ đã bordered', () {
      final res = _run(() => tb0(styleDefs: plainStyle.replaceAll('none', 'single')));
      expect(res, isA<DocxTable>().having((x) => x.columnWidthsTwips, 'grid', equals([2000, 3000])).having((x) => x.bordered, 'bordered', isTrue).having((x) => x.rows.first.heightTwips, 'height', 400).having((x) => x.rows.first.isHeader, 'header', isFalse).having((x) => x.rows.first.cells.first.gridSpan, 'gridSpan', 2).having((x) => x.rows.first.cells.first.shadingArgb, 'shading', 0xFFFF0000).having((x) => x.rows.first.cells.first.widthTwips, 'width', 5000).having((x) => x.rows.first.cells.first.vMergeContinue, 'vMergeContinue', isFalse).having((x) => x.rows.first.cells.first.rowSpan, 'rowSpan', 2));
    });
    // Đường: D1S D3S D2S D4S D5S D6S D7Đ D8S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20Đ D21Đ D22S D23S D25S D26S D27S D28S D29Đ D30S D31S D32S D33S D35S D36Đ D37Đ D38S D39Đ D40S D41S D39S D42Đ D37S D36S → R1
    test('20-20 ô có tcBorders toàn none', () {
      final res = _run(() => tb0(tcPr: tcPrDef + '<w:tcBorders><w:top w:val="none"/></w:tcBorders>'));
      expect(res, isA<DocxTable>().having((x) => x.columnWidthsTwips, 'grid', equals([2000, 3000])).having((x) => x.bordered, 'bordered', isFalse).having((x) => x.rows.first.heightTwips, 'height', 400).having((x) => x.rows.first.isHeader, 'header', isFalse).having((x) => x.rows.first.cells.first.gridSpan, 'gridSpan', 2).having((x) => x.rows.first.cells.first.shadingArgb, 'shading', 0xFFFF0000).having((x) => x.rows.first.cells.first.widthTwips, 'width', 5000).having((x) => x.rows.first.cells.first.vMergeContinue, 'vMergeContinue', isFalse).having((x) => x.rows.first.cells.first.rowSpan, 'rowSpan', 2));
    });
    // Đường: D1S D3S D2S D4S D5S D6S D7Đ D8S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20Đ D21S D23Đ D24S D25S D26S D27S D28S D29Đ D30S D31S D32S D33S D35S D36Đ D37Đ D38S D39Đ D40S D41S D39S D42Đ D37S D36S → R1
    test('20-21 ô 1 vMerge restart', () {
      final res = _run(() => tb0(tcPr: tcPrDef + '<w:vMerge w:val="restart"/>'));
      expect(res, isA<DocxTable>().having((x) => x.columnWidthsTwips, 'grid', equals([2000, 3000])).having((x) => x.bordered, 'bordered', isFalse).having((x) => x.rows.first.heightTwips, 'height', 400).having((x) => x.rows.first.isHeader, 'header', isFalse).having((x) => x.rows.first.cells.first.gridSpan, 'gridSpan', 2).having((x) => x.rows.first.cells.first.shadingArgb, 'shading', 0xFFFF0000).having((x) => x.rows.first.cells.first.widthTwips, 'width', 5000).having((x) => x.rows.first.cells.first.vMergeContinue, 'vMergeContinue', isFalse).having((x) => x.rows.first.cells.first.rowSpan, 'rowSpan', 2));
    });
    // Đường: D1S D3S D2S D4S D5S D6S D7Đ D8S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20Đ D21S D23S D25Đ D27S D28S D29Đ D30S D31S D32S D33S D35S D36Đ D37Đ D38S D39Đ D40S D41S D39S D42Đ D37S D36S → R1
    test('20-22 shd không có fill', () {
      final res = _run(() => tb0(tcPr: '<w:gridSpan w:val="2"/><w:shd w:val="clear"/><w:tcW w:w="5000" w:type="dxa"/>'));
      expect(res, isA<DocxTable>().having((x) => x.columnWidthsTwips, 'grid', equals([2000, 3000])).having((x) => x.bordered, 'bordered', isFalse).having((x) => x.rows.first.heightTwips, 'height', 400).having((x) => x.rows.first.isHeader, 'header', isFalse).having((x) => x.rows.first.cells.first.gridSpan, 'gridSpan', 2).having((x) => x.rows.first.cells.first.shadingArgb, 'shading', isNull).having((x) => x.rows.first.cells.first.widthTwips, 'width', 5000).having((x) => x.rows.first.cells.first.vMergeContinue, 'vMergeContinue', isFalse).having((x) => x.rows.first.cells.first.rowSpan, 'rowSpan', 2));
    });
    // Đường: D1S D3S D2S D4S D5S D6S D7Đ D8S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20Đ D21S D23S D25S D26Đ D27S D28S D29Đ D30S D31S D32S D33S D35S D36Đ D37Đ D38S D39Đ D40S D41S D39S D42Đ D37S D36S → R1
    test('20-23 shd fill auto', () {
      final res = _run(() => tb0(tcPr: '<w:gridSpan w:val="2"/><w:shd w:val="clear" w:fill="auto"/><w:tcW w:w="5000" w:type="dxa"/>'));
      expect(res, isA<DocxTable>().having((x) => x.columnWidthsTwips, 'grid', equals([2000, 3000])).having((x) => x.bordered, 'bordered', isFalse).having((x) => x.rows.first.heightTwips, 'height', 400).having((x) => x.rows.first.isHeader, 'header', isFalse).having((x) => x.rows.first.cells.first.gridSpan, 'gridSpan', 2).having((x) => x.rows.first.cells.first.shadingArgb, 'shading', isNull).having((x) => x.rows.first.cells.first.widthTwips, 'width', 5000).having((x) => x.rows.first.cells.first.vMergeContinue, 'vMergeContinue', isFalse).having((x) => x.rows.first.cells.first.rowSpan, 'rowSpan', 2));
    });
    // Đường: D1S D3S D2S D4S D5S D6S D7Đ D8S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20Đ D21S D23S D25S D26S D27Đ D28Đ D29Đ D30Đ D31S D32S D33S D35S D36Đ D37Đ D38S D39Đ D40S D41S D39S D42Đ D37S D36S → R1
    test('20-24 không có tcW', () {
      final res = _run(() => tb0(tcPr: '<w:gridSpan w:val="2"/><w:shd w:val="clear" w:fill="FF0000"/>'));
      expect(res, isA<DocxTable>().having((x) => x.columnWidthsTwips, 'grid', equals([2000, 3000])).having((x) => x.bordered, 'bordered', isFalse).having((x) => x.rows.first.heightTwips, 'height', 400).having((x) => x.rows.first.isHeader, 'header', isFalse).having((x) => x.rows.first.cells.first.gridSpan, 'gridSpan', 2).having((x) => x.rows.first.cells.first.shadingArgb, 'shading', 0xFFFF0000).having((x) => x.rows.first.cells.first.widthTwips, 'width', isNull).having((x) => x.rows.first.cells.first.vMergeContinue, 'vMergeContinue', isFalse).having((x) => x.rows.first.cells.first.rowSpan, 'rowSpan', 2));
    });
    // Đường: D1S D3S D2S D4S D5S D6S D7Đ D8S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20Đ D21S D23S D25S D26S D27S D28Đ D29Đ D30S D31S D32S D33S D35S D36Đ D37Đ D38S D39Đ D40S D41S D39S D42Đ D37S D36S → R1
    test('20-25 tcW không có type', () {
      final res = _run(() => tb0(tcPr: '<w:gridSpan w:val="2"/><w:shd w:val="clear" w:fill="FF0000"/><w:tcW w:w="5000"/>'));
      expect(res, isA<DocxTable>().having((x) => x.columnWidthsTwips, 'grid', equals([2000, 3000])).having((x) => x.bordered, 'bordered', isFalse).having((x) => x.rows.first.heightTwips, 'height', 400).having((x) => x.rows.first.isHeader, 'header', isFalse).having((x) => x.rows.first.cells.first.gridSpan, 'gridSpan', 2).having((x) => x.rows.first.cells.first.shadingArgb, 'shading', 0xFFFF0000).having((x) => x.rows.first.cells.first.widthTwips, 'width', 5000).having((x) => x.rows.first.cells.first.vMergeContinue, 'vMergeContinue', isFalse).having((x) => x.rows.first.cells.first.rowSpan, 'rowSpan', 2));
    });
    // Đường: D1S D3S D2S D4S D5S D6S D7Đ D8S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20Đ D21S D23S D25S D26S D27S D28S D29S D31S D32S D33S D35S D36Đ D37Đ D38S D39Đ D40S D41S D39S D42Đ D37S D36S → R1
    test('20-26 tcW type pct', () {
      final res = _run(() => tb0(tcPr: '<w:gridSpan w:val="2"/><w:shd w:val="clear" w:fill="FF0000"/><w:tcW w:w="2500" w:type="pct"/>'));
      expect(res, isA<DocxTable>().having((x) => x.columnWidthsTwips, 'grid', equals([2000, 3000])).having((x) => x.bordered, 'bordered', isFalse).having((x) => x.rows.first.heightTwips, 'height', 400).having((x) => x.rows.first.isHeader, 'header', isFalse).having((x) => x.rows.first.cells.first.gridSpan, 'gridSpan', 2).having((x) => x.rows.first.cells.first.shadingArgb, 'shading', 0xFFFF0000).having((x) => x.rows.first.cells.first.widthTwips, 'width', isNull).having((x) => x.rows.first.cells.first.vMergeContinue, 'vMergeContinue', isFalse).having((x) => x.rows.first.cells.first.rowSpan, 'rowSpan', 2));
    });
    // Đường: D1S D3S D2S D4S D5S D6S D7Đ D8S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20Đ D21S D23S D25S D26S D27S D28S D29Đ D30S D31S D32S D33Đ D34Đ D35S D36Đ D37Đ D38S D39Đ D40S D41S D39S D42Đ D37S D36S → R1
    test('20-30 trPr có tblHeader', () {
      final res = _run(() => tb0(trPr: trPrDef + '<w:tblHeader/>'));
      expect(res, isA<DocxTable>().having((x) => x.columnWidthsTwips, 'grid', equals([2000, 3000])).having((x) => x.bordered, 'bordered', isFalse).having((x) => x.rows.first.heightTwips, 'height', 400).having((x) => x.rows.first.isHeader, 'header', isTrue).having((x) => x.rows.first.cells.first.gridSpan, 'gridSpan', 2).having((x) => x.rows.first.cells.first.shadingArgb, 'shading', 0xFFFF0000).having((x) => x.rows.first.cells.first.widthTwips, 'width', 5000).having((x) => x.rows.first.cells.first.vMergeContinue, 'vMergeContinue', isFalse).having((x) => x.rows.first.cells.first.rowSpan, 'rowSpan', 2));
    });
    // Đường: D1S D3S D2S D4S D5S D6S D7Đ D8S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20Đ D21S D23S D25S D26S D27S D28S D29Đ D30S D31S D32S D33S D35Đ D36Đ D37Đ D38S D39Đ D40S D41S D39S D42Đ D37S D36S → R1
    test('20-31 trPr không có trHeight', () {
      final res = _run(() => tb0(trPr: '<w:gridBefore w:val="0"/>'));
      expect(res, isA<DocxTable>().having((x) => x.columnWidthsTwips, 'grid', equals([2000, 3000])).having((x) => x.bordered, 'bordered', isFalse).having((x) => x.rows.first.heightTwips, 'height', isNull).having((x) => x.rows.first.isHeader, 'header', isFalse).having((x) => x.rows.first.cells.first.gridSpan, 'gridSpan', 2).having((x) => x.rows.first.cells.first.shadingArgb, 'shading', 0xFFFF0000).having((x) => x.rows.first.cells.first.widthTwips, 'width', 5000).having((x) => x.rows.first.cells.first.vMergeContinue, 'vMergeContinue', isFalse).having((x) => x.rows.first.cells.first.rowSpan, 'rowSpan', 2));
    });
    // Đường: D1S D3S D2S D4S D5S D6S D7Đ D8S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20Đ D21S D23S D25S D26S D27S D28S D29Đ D30S D31S D32S D33S D35S D36S → R1
    test('20-32 bảng không có hàng', () {
      final res = _run(() => tb0(rows: '').rows);
      expect(res, isEmpty);
    });
    // Đường: D1S D3S D2S D4S D5S D6S D7Đ D8S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20Đ D21S D23S D25S D26S D27S D28S D29Đ D30S D31S D32S D33S D35S D36Đ D37S D36S → R1
    test('20-33 hàng không có ô', () {
      final res = _run(() => tb0(rows: '<w:tr/>').rows.single.cells);
      expect(res, isEmpty);
    });
    // Đường: D1S D3S D2S D4S D5S D6S D7Đ D8S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20Đ D21S D23S D25S D26S D27S D28S D29Đ D30S D31S D32S D33S D35S D36Đ D37Đ D38S D39S D42S D37S D36S → R1
    test('20-35 chỉ 1 hàng', () {
      final res = _run(() => tb0(row2: ''));
      expect(res, isA<DocxTable>().having((x) => x.columnWidthsTwips, 'grid', equals([2000, 3000])).having((x) => x.bordered, 'bordered', isFalse).having((x) => x.rows.first.heightTwips, 'height', 400).having((x) => x.rows.first.isHeader, 'header', isFalse).having((x) => x.rows.first.cells.first.gridSpan, 'gridSpan', 2).having((x) => x.rows.first.cells.first.shadingArgb, 'shading', 0xFFFF0000).having((x) => x.rows.first.cells.first.widthTwips, 'width', 5000).having((x) => x.rows.first.cells.first.vMergeContinue, 'vMergeContinue', isFalse).having((x) => x.rows.first.cells.first.rowSpan, 'rowSpan', 1));
    });
    // Đường: D1S D3S D2S D4S D5S D6S D7Đ D8S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20Đ D21S D23S D25S D26S D27S D28S D29Đ D30S D31S D32S D33S D35S D36Đ D37Đ D38S D39Đ D40Đ D42S D37S D36S → R1
    test('20-36 hàng 2 gridBefore 1 ⇒ ô ở cột khác', () {
      final res = _run(() => tb0(row2: row2Def.replaceFirst('w:gridBefore w:val="0"', 'w:gridBefore w:val="1"')));
      expect(res, isA<DocxTable>().having((x) => x.columnWidthsTwips, 'grid', equals([2000, 3000])).having((x) => x.bordered, 'bordered', isFalse).having((x) => x.rows.first.heightTwips, 'height', 400).having((x) => x.rows.first.isHeader, 'header', isFalse).having((x) => x.rows.first.cells.first.gridSpan, 'gridSpan', 2).having((x) => x.rows.first.cells.first.shadingArgb, 'shading', 0xFFFF0000).having((x) => x.rows.first.cells.first.widthTwips, 'width', 5000).having((x) => x.rows.first.cells.first.vMergeContinue, 'vMergeContinue', isFalse).having((x) => x.rows.first.cells.first.rowSpan, 'rowSpan', 1));
    });
    // Đường: D1S D3S D2S D4S D5S D6S D7Đ D8S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20Đ D21S D23S D25S D26S D27S D28S D29Đ D30S D31S D32S D33S D35S D36Đ D37Đ D38S D39Đ D40S D41Đ D42S D37S D36S → R1
    test('20-37 hàng 2 ô không vMerge', () {
      final res = _run(() => tb0(row2: row2Def.replaceFirst('<w:vMerge/>', '')));
      expect(res, isA<DocxTable>().having((x) => x.columnWidthsTwips, 'grid', equals([2000, 3000])).having((x) => x.bordered, 'bordered', isFalse).having((x) => x.rows.first.heightTwips, 'height', 400).having((x) => x.rows.first.isHeader, 'header', isFalse).having((x) => x.rows.first.cells.first.gridSpan, 'gridSpan', 2).having((x) => x.rows.first.cells.first.shadingArgb, 'shading', 0xFFFF0000).having((x) => x.rows.first.cells.first.widthTwips, 'width', 5000).having((x) => x.rows.first.cells.first.vMergeContinue, 'vMergeContinue', isFalse).having((x) => x.rows.first.cells.first.rowSpan, 'rowSpan', 1));
    });
    // Đường: D1S D3S D2S D4S D5S D6S D7Đ D8Đ D9Đ D10S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20Đ D21S D23S D25S D26S D27S D28S D29Đ D30S D31S D32S D33S D35S D36Đ D37Đ D38S D39Đ D40S D41S D39S D42Đ D37S D36S → R1
    test('20-39 tblStyle Plain2 không có trong styles', () {
      final res = _run(() => tb0(tblPr: '<w:tblStyle w:val="Plain2"/>'));
      expect(res, isA<DocxTable>().having((x) => x.columnWidthsTwips, 'grid', equals([2000, 3000])).having((x) => x.bordered, 'bordered', isFalse).having((x) => x.rows.first.heightTwips, 'height', 400).having((x) => x.rows.first.isHeader, 'header', isFalse).having((x) => x.rows.first.cells.first.gridSpan, 'gridSpan', 2).having((x) => x.rows.first.cells.first.shadingArgb, 'shading', 0xFFFF0000).having((x) => x.rows.first.cells.first.widthTwips, 'width', 5000).having((x) => x.rows.first.cells.first.vMergeContinue, 'vMergeContinue', isFalse).having((x) => x.rows.first.cells.first.rowSpan, 'rowSpan', 2));
    });
    // Đường: D1S D3S D2S D4S D5S D6S D7Đ D8S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20Đ D21Đ D22Đ D23S D25S D26S D27S D28S D29Đ D30S D31S D32S D33S D35S D36Đ D37Đ D38S D39Đ D40S D41S D39S D42Đ D37S D36S → R1
    test('20-40 ô có tcBorders single', () {
      final res = _run(() => tb0(tcPr: tcPrDef + '<w:tcBorders><w:top w:val="single"/></w:tcBorders>'));
      expect(res, isA<DocxTable>().having((x) => x.columnWidthsTwips, 'grid', equals([2000, 3000])).having((x) => x.bordered, 'bordered', isTrue).having((x) => x.rows.first.heightTwips, 'height', 400).having((x) => x.rows.first.isHeader, 'header', isFalse).having((x) => x.rows.first.cells.first.gridSpan, 'gridSpan', 2).having((x) => x.rows.first.cells.first.shadingArgb, 'shading', 0xFFFF0000).having((x) => x.rows.first.cells.first.widthTwips, 'width', 5000).having((x) => x.rows.first.cells.first.vMergeContinue, 'vMergeContinue', isFalse).having((x) => x.rows.first.cells.first.rowSpan, 'rowSpan', 2));
    });
    // Đường: D1S D3S D2S D4S D5S D6S D7Đ D8S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20Đ D21S D23Đ D24Đ D25S D26S D27S D28S D29Đ D30S D31S D32S D33S D35S D36Đ D37Đ D38Đ D37S D36S → R1
    test('20-41 ô 1 vMerge (tiếp) ở hàng đầu', () {
      final res = _run(() => tb0(tcPr: tcPrDef + '<w:vMerge/>'));
      expect(res, isA<DocxTable>().having((x) => x.columnWidthsTwips, 'grid', equals([2000, 3000])).having((x) => x.bordered, 'bordered', isFalse).having((x) => x.rows.first.heightTwips, 'height', 400).having((x) => x.rows.first.isHeader, 'header', isFalse).having((x) => x.rows.first.cells.first.gridSpan, 'gridSpan', 2).having((x) => x.rows.first.cells.first.shadingArgb, 'shading', 0xFFFF0000).having((x) => x.rows.first.cells.first.widthTwips, 'width', 5000).having((x) => x.rows.first.cells.first.vMergeContinue, 'vMergeContinue', isTrue).having((x) => x.rows.first.cells.first.rowSpan, 'rowSpan', 1));
    });
    // Đường: D1S D3S D2S D4S D5S D6S D7Đ D8S D11S D12S D13S D14S D15S D16S D17S D18S D19S D20Đ D21S D23S D25S D26S D27S D28S D29Đ D30S D31S D32S D33Đ D34S D35S D36Đ D37Đ D38S D39Đ D40S D41S D39S D42Đ D37S D36S → R1
    test('20-42 tblHeader val=0', () {
      final res = _run(() => tb0(trPr: trPrDef + '<w:tblHeader w:val="0"/>'));
      expect(res, isA<DocxTable>().having((x) => x.columnWidthsTwips, 'grid', equals([2000, 3000])).having((x) => x.bordered, 'bordered', isFalse).having((x) => x.rows.first.heightTwips, 'height', 400).having((x) => x.rows.first.isHeader, 'header', isFalse).having((x) => x.rows.first.cells.first.gridSpan, 'gridSpan', 2).having((x) => x.rows.first.cells.first.shadingArgb, 'shading', 0xFFFF0000).having((x) => x.rows.first.cells.first.widthTwips, 'width', 5000).having((x) => x.rows.first.cells.first.vMergeContinue, 'vMergeContinue', isFalse).having((x) => x.rows.first.cells.first.rowSpan, 'rowSpan', 2));
    });
    // Đường: D1S D3S D2S D4S D5S D6S D7Đ D8Đ D9Đ D10Đ D11S D12S D13S D14S D15S D16S D17S D18S D19S D20Đ D21S D23S D25S D26S D27S D28S D29Đ D30S D31S D32S D33S D35S D36Đ D37Đ D38S D39Đ D40S D41S D39S D42Đ D37S D36S → R1
    test('20-43 tblStyle TableGrid không có trong styles', () {
      final res = _run(() => tb0(tblPr: '<w:tblStyle w:val="TableGrid"/>'));
      expect(res, isA<DocxTable>().having((x) => x.columnWidthsTwips, 'grid', equals([2000, 3000])).having((x) => x.bordered, 'bordered', isTrue).having((x) => x.rows.first.heightTwips, 'height', 400).having((x) => x.rows.first.isHeader, 'header', isFalse).having((x) => x.rows.first.cells.first.gridSpan, 'gridSpan', 2).having((x) => x.rows.first.cells.first.shadingArgb, 'shading', 0xFFFF0000).having((x) => x.rows.first.cells.first.widthTwips, 'width', 5000).having((x) => x.rows.first.cells.first.vMergeContinue, 'vMergeContinue', isFalse).having((x) => x.rows.first.cells.first.rowSpan, 'rowSpan', 2));
    });
  });
  group('Đơn vị 21 — _DocxReader._rowsOf', () {
    // Đường: D1Đ → R1
    test('21-1 tbl có tr trực tiếp', () {
      final res = _run(() => tb0(rows: tr(tc('a'))).rows.length);
      expect(res, 1);
    });
    // Đường: D1S D2S D4S → R1
    test('21-2 tbl chỉ có bookmarkStart', () {
      final res = _run(() => tb0(rows: '<w:bookmarkStart w:id="0" w:name="b"/>').rows.length);
      expect(res, 0);
    });
    // Đường: D1S D2Đ D3Đ → R1
    test('21-3 sdt bọc tr', () {
      final res = _run(() => tb0(rows: '<w:sdt><w:sdtContent>' + tr(tc('a')) + '</w:sdtContent></w:sdt>').rows.length);
      expect(res, 1);
    });
    // Đường: D1S D2S D4Đ → R1
    test('21-4 customXml bọc tr', () {
      final res = _run(() => tb0(rows: '<w:customXml>' + tr(tc('a')) + '</w:customXml>').rows.length);
      expect(res, 1);
    });
    // Đường: D1S D2Đ D3S → R1
    test('21-5 sdt không có sdtContent', () {
      final res = _run(() => tb0(rows: '<w:sdt><w:sdtPr/></w:sdt>').rows.length);
      expect(res, 0);
    });
  });
  group('Đơn vị 22 — _DocxReader._cellsOf', () {
    // Đường: D1Đ → R1
    test('22-1 tr có tc trực tiếp', () {
      final res = _run(() => tb0(rows: tr(tc('a'))).rows.single.cells.length);
      expect(res, 1);
    });
    // Đường: D1S D2S D4S → R1
    test('22-2 tr chỉ có bookmarkStart', () {
      final res = _run(() => tb0(rows: tr('<w:bookmarkStart w:id="0" w:name="b"/>')).rows.single.cells.length);
      expect(res, 0);
    });
    // Đường: D1S D2Đ D3Đ → R1
    test('22-3 sdt bọc tc', () {
      final res = _run(() => tb0(rows: tr('<w:sdt><w:sdtContent>' + tc('a') + '</w:sdtContent></w:sdt>')).rows.single.cells.length);
      expect(res, 1);
    });
    // Đường: D1S D2S D4Đ → R1
    test('22-4 customXml bọc tc', () {
      final res = _run(() => tb0(rows: tr('<w:customXml>' + tc('a') + '</w:customXml>')).rows.single.cells.length);
      expect(res, 1);
    });
    // Đường: D1S D2Đ D3S → R1
    test('22-5 sdt không có sdtContent', () {
      final res = _run(() => tb0(rows: tr('<w:sdt><w:sdtPr/></w:sdt>')).rows.single.cells.length);
      expect(res, 0);
    });
  });
}
