import 'dart:typed_data';

import 'package:office_reader/office_reader.dart';
import 'package:test/test.dart';

import 'helpers/ooxml.dart';

const _styles = '''
<w:docDefaults>
  <w:rPrDefault><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:sz w:val="22"/></w:rPr></w:rPrDefault>
  <w:pPrDefault><w:pPr><w:spacing w:after="160"/></w:pPr></w:pPrDefault>
</w:docDefaults>
<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style>
<w:style w:type="paragraph" w:styleId="Heading1">
  <w:name w:val="heading 1"/><w:basedOn w:val="Normal"/>
  <w:pPr><w:outlineLvl w:val="0"/><w:spacing w:before="240"/></w:pPr>
  <w:rPr><w:b/><w:color w:val="2F5496"/><w:sz w:val="32"/></w:rPr>
</w:style>
<w:style w:type="paragraph" w:styleId="Heading2">
  <w:name w:val="heading 2"/><w:basedOn w:val="Heading1"/>
  <w:rPr><w:sz w:val="26"/></w:rPr>
</w:style>
<w:style w:type="paragraph" w:styleId="MyQuote">
  <w:name w:val="My Quote"/><w:basedOn w:val="Normal"/>
  <w:pPr><w:jc w:val="center"/><w:ind w:left="720" w:firstLine="360"/></w:pPr>
  <w:rPr><w:i/><w:color w:val="FF0000"/></w:rPr>
</w:style>
<w:style w:type="paragraph" w:styleId="MyQuoteChild">
  <w:name w:val="My Quote Child"/><w:basedOn w:val="MyQuote"/>
  <w:rPr><w:u w:val="single"/></w:rPr>
</w:style>
<w:style w:type="character" w:styleId="Strong">
  <w:name w:val="Strong"/><w:rPr><w:b/></w:rPr>
</w:style>
''';

DocxParagraph _para(DocxDocument d, int i) => d.blocks[i] as DocxParagraph;
DocxRun _run(DocxParagraph p, int i) => p.inlines[i] as DocxRun;

void main() {
  group('styles', () {
    test('heading level and formatting come from paragraph style', () {
      final doc = readDocx(
        buildDocx(
          styles: _styles,
          body:
              p('Title', pPr: '<w:pStyle w:val="Heading1"/>') +
              p('Sub', pPr: '<w:pStyle w:val="Heading2"/>') +
              p('Body'),
        ),
      );
      final h1 = _para(doc, 0);
      expect(h1.headingLevel, 1);
      expect(h1.styleId, 'Heading1');
      final r = _run(h1, 0);
      expect(r.text, 'Title');
      expect(r.bold, isTrue);
      expect(r.fontSizePt, 16);
      expect(r.colorArgb, 0xFF2F5496);
      expect(r.fontFamily, 'Calibri');
      expect(h1.spaceBeforePt, 12);
      expect(h1.spaceAfterPt, 8); // from docDefaults

      final h2 = _para(doc, 1);
      expect(h2.headingLevel, 2);
      expect(_run(h2, 0).bold, isTrue, reason: 'inherited via basedOn');
      expect(_run(h2, 0).fontSizePt, 13);

      final body = _para(doc, 2);
      expect(body.headingLevel, isNull);
      expect(_run(body, 0).bold, isFalse);
      expect(_run(body, 0).fontSizePt, 11);
    });

    test('basedOn chain inherits paragraph and run properties', () {
      final doc = readDocx(
        buildDocx(
          styles: _styles,
          body: p('Q', pPr: '<w:pStyle w:val="MyQuoteChild"/>'),
        ),
      );
      final para = _para(doc, 0);
      expect(para.align, DocxAlign.center);
      expect(para.indentLeftPt, 36);
      expect(para.firstLineIndentPt, 18);
      final r = _run(para, 0);
      expect(r.italic, isTrue);
      expect(r.underline, isTrue);
      expect(r.colorArgb, 0xFFFF0000);
    });

    test('run properties override style; char style applies', () {
      final doc = readDocx(
        buildDocx(
          styles: _styles,
          body:
              '<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr>'
              '<w:r><w:rPr><w:b w:val="0"/><w:sz w:val="20"/><w:color w:val="00FF00"/>'
              '<w:rFonts w:ascii="Arial"/><w:strike/><w:highlight w:val="yellow"/></w:rPr>'
              '<w:t>x</w:t></w:r>'
              '<w:r><w:rPr><w:rStyle w:val="Strong"/></w:rPr><w:t>y</w:t></w:r></w:p>'
              '<w:p><w:r><w:rPr><w:rStyle w:val="Strong"/><w:i/></w:rPr><w:t>z</w:t></w:r></w:p>',
        ),
      );
      final r = _run(_para(doc, 0), 0);
      expect(r.bold, isFalse);
      expect(r.fontSizePt, 10);
      expect(r.colorArgb, 0xFF00FF00);
      expect(r.fontFamily, 'Arial');
      expect(r.strike, isTrue);
      expect(r.highlightArgb, 0xFFFFFF00);
      final z = _run(_para(doc, 1), 0);
      expect(z.bold, isTrue);
      expect(z.italic, isTrue);
    });

    test('direct paragraph properties: align, spacing, pageBreakBefore', () {
      final doc = readDocx(
        buildDocx(
          body: p(
            'R',
            pPr:
                '<w:jc w:val="right"/><w:spacing w:before="120" w:after="0"/>'
                '<w:ind w:left="1440" w:hanging="360"/><w:pageBreakBefore/>',
          ),
        ),
      );
      final para = _para(doc, 0);
      expect(para.align, DocxAlign.right);
      expect(para.spaceBeforePt, 6);
      expect(para.spaceAfterPt, 0);
      expect(para.indentLeftPt, 72);
      expect(para.firstLineIndentPt, -18);
      expect(para.pageBreakBefore, isTrue);
    });

    test('missing styles.xml is fine', () {
      final doc = readDocx(buildDocx(body: p('plain')));
      expect(_run(_para(doc, 0), 0).text, 'plain');
      expect(_run(_para(doc, 0), 0).fontSizePt, isNull);
    });
  });

  group('lists', () {
    const numbering = '''
<w:abstractNum w:abstractNumId="0">
  <w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:lvlText w:val="%1."/><w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr></w:lvl>
  <w:lvl w:ilvl="1"><w:start w:val="1"/><w:numFmt w:val="lowerLetter"/><w:lvlText w:val="%2)"/></w:lvl>
  <w:lvl w:ilvl="2"><w:start w:val="1"/><w:numFmt w:val="lowerRoman"/><w:lvlText w:val="%1.%2.%3"/></w:lvl>
</w:abstractNum>
<w:abstractNum w:abstractNumId="1">
  <w:lvl w:ilvl="0"><w:numFmt w:val="bullet"/><w:lvlText w:val=""/></w:lvl>
  <w:lvl w:ilvl="1"><w:numFmt w:val="bullet"/><w:lvlText w:val="o"/></w:lvl>
</w:abstractNum>
<w:abstractNum w:abstractNumId="2">
  <w:lvl w:ilvl="0"><w:start w:val="3"/><w:numFmt w:val="upperRoman"/><w:lvlText w:val="%1."/></w:lvl>
</w:abstractNum>
<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>
<w:num w:numId="2"><w:abstractNumId w:val="1"/></w:num>
<w:num w:numId="3"><w:abstractNumId w:val="2"/></w:num>
''';
    String item(String t, int numId, int lvl) => p(
      t,
      pPr: '<w:numPr><w:ilvl w:val="$lvl"/><w:numId w:val="$numId"/></w:numPr>',
    );

    test('ordered multi-level labels', () {
      final doc = readDocx(
        buildDocx(
          numbering: numbering,
          body:
              item('one', 1, 0) +
              item('a', 1, 1) +
              item('b', 1, 1) +
              item('roman', 1, 2) +
              item('two', 1, 0) +
              item('a again', 1, 1) +
              item('III', 3, 0),
        ),
      );
      final labels = [for (var i = 0; i < 7; i++) _para(doc, i).listLabel];
      expect(labels, ['1.', 'a)', 'b)', '1.b.i', '2.', 'a)', 'III.']);
      expect(_para(doc, 0).listOrdered, isTrue);
      expect(_para(doc, 1).listLevel, 1);
      expect(_para(doc, 0).indentLeftPt, 36, reason: 'indent from numbering');
      expect(_para(doc, 0).firstLineIndentPt, -18);
    });

    test('bullets are unordered with readable labels', () {
      final doc = readDocx(
        buildDocx(
          numbering: numbering,
          body: item('x', 2, 0) + item('y', 2, 1) + p('not a list'),
        ),
      );
      expect(_para(doc, 0).listOrdered, isFalse);
      expect(_para(doc, 0).listLabel, '•');
      expect(_para(doc, 0).listLevel, 0);
      expect(_para(doc, 1).listLabel, 'o');
      expect(_para(doc, 2).listLevel, isNull);
      expect(_para(doc, 2).listLabel, isNull);
    });
  });

  group('tables', () {
    test('grid widths, gridSpan, vMerge and shading', () {
      String tc(String text, {String tcPr = ''}) =>
          '<w:tc><w:tcPr>$tcPr</w:tcPr>${p(text)}</w:tc>';
      final doc = readDocx(
        buildDocx(
          body:
              '<w:tbl><w:tblPr><w:tblBorders><w:top w:val="single"/></w:tblBorders></w:tblPr>'
              '<w:tblGrid><w:gridCol w:w="2000"/><w:gridCol w:w="3000"/><w:gridCol w:w="1000"/></w:tblGrid>'
              '<w:tr>${tc('wide', tcPr: '<w:gridSpan w:val="2"/><w:shd w:val="clear" w:fill="D9E2F3"/>')}'
              '${tc('tall', tcPr: '<w:vMerge w:val="restart"/>')}</w:tr>'
              '<w:tr>${tc('a')}${tc('b')}${tc('', tcPr: '<w:vMerge/>')}</w:tr>'
              '<w:tr>${tc('c')}${tc('d')}${tc('', tcPr: '<w:vMerge/>')}</w:tr>'
              '</w:tbl>'
              '${p('after')}',
        ),
      );
      final t = doc.blocks[0] as DocxTable;
      expect(t.columnWidthsTwips, [2000, 3000, 1000]);
      expect(t.bordered, isTrue);
      expect(t.rows, hasLength(3));
      final first = t.rows[0].cells;
      expect(first[0].gridSpan, 2);
      expect(first[0].shadingArgb, 0xFFD9E2F3);
      expect(
        ((first[0].blocks.single as DocxParagraph).inlines.single as DocxRun)
            .text,
        'wide',
      );
      expect(first[1].vMergeContinue, isFalse);
      expect(first[1].rowSpan, 3);
      expect(t.rows[1].cells[2].vMergeContinue, isTrue);
      expect(t.rows[2].cells[2].vMergeContinue, isTrue);
      expect(t.rows[1].cells[0].rowSpan, 1);
      expect(doc.blocks[1], isA<DocxParagraph>());
    });

    test('nested table inside a cell', () {
      final inner =
          '<w:tbl><w:tblGrid><w:gridCol w:w="500"/></w:tblGrid>'
          '<w:tr><w:tc>${p('inner')}</w:tc></w:tr></w:tbl>';
      final doc = readDocx(
        buildDocx(
          body:
              '<w:tbl><w:tblGrid><w:gridCol w:w="4000"/></w:tblGrid>'
              '<w:tr><w:tc>$inner${p('')}</w:tc></w:tr></w:tbl>',
        ),
      );
      final outer = doc.blocks.single as DocxTable;
      expect(outer.rows.single.cells.single.blocks.first, isA<DocxTable>());
    });
  });

  group('inlines', () {
    test('inline and anchored images resolve through rels', () {
      String drawing(String kind, String rid) =>
          '<w:r><w:drawing><wp:$kind><wp:extent cx="914400" cy="457200"/>'
          '<a:graphic><a:graphicData><pic:pic><pic:blipFill>'
          '<a:blip r:embed="$rid"/></pic:blipFill></pic:pic>'
          '</a:graphicData></a:graphic></wp:$kind></w:drawing></w:r>';
      final doc = readDocx(
        buildDocx(
          rels:
              '<Relationship Id="rIdImg" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image1.png"/>'
              '<Relationship Id="rIdImg2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="/word/media/pic.JPEG"/>',
          media: {'media/image1.png': tinyPng, 'media/pic.JPEG': tinyPng},
          body:
              '<w:p>${drawing('inline', 'rIdImg')}${drawing('anchor', 'rIdImg2')}'
              '${drawing('inline', 'rIdMissing')}</w:p>',
        ),
      );
      final para = _para(doc, 0);
      expect(para.inlines, hasLength(2));
      final img = para.inlines[0] as DocxImage;
      expect(img.bytes, tinyPng);
      expect(img.extension, 'png');
      expect(img.widthEmu, 914400);
      expect(img.heightEmu, 457200);
      expect((para.inlines[1] as DocxImage).extension, 'jpeg');
    });

    test('hyperlink, tab, line break and field result', () {
      final doc = readDocx(
        buildDocx(
          rels:
              '<Relationship Id="rIdL" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="https://example.com/" TargetMode="External"/>',
          body:
              '<w:p><w:hyperlink r:id="rIdL"><w:r><w:t>link</w:t></w:r></w:hyperlink>'
              '<w:r><w:tab/><w:t>a</w:t><w:br/><w:t>b</w:t></w:r>'
              '<w:r><w:fldChar w:fldCharType="begin"/></w:r>'
              '<w:r><w:instrText> PAGE </w:instrText></w:r>'
              '<w:r><w:fldChar w:fldCharType="separate"/></w:r>'
              '<w:r><w:t>7</w:t></w:r>'
              '<w:r><w:fldChar w:fldCharType="end"/></w:r>'
              '<w:hyperlink w:anchor="sec1"><w:r><w:t>in</w:t></w:r></w:hyperlink>'
              '</w:p>',
        ),
      );
      final inl = _para(doc, 0).inlines;
      final texts = inl
          .map((e) => e is DocxRun ? e.text : (e is DocxBreak ? '<br>' : '?'))
          .join('|');
      expect(texts, 'link|\ta|<br>|b|7|in');
      expect((inl[0] as DocxRun).hyperlink, 'https://example.com/');
      expect((inl[1] as DocxRun).hyperlink, isNull);
      expect((inl.last as DocxRun).hyperlink, '#sec1');
    });

    test('page break inside a paragraph becomes a DocxPageBreak block', () {
      final doc = readDocx(
        buildDocx(
          body:
              '<w:p><w:r><w:t>before</w:t><w:br w:type="page"/><w:t>after</w:t></w:r></w:p>'
              '<w:p><w:r><w:br w:type="page"/></w:r></w:p>'
              '${p('end')}',
        ),
      );
      expect(doc.blocks.map((b) => b.runtimeType.toString()).toList(), [
        'DocxParagraph',
        'DocxPageBreak',
        'DocxParagraph',
        'DocxPageBreak',
        'DocxParagraph',
      ]);
      expect(_run(_para(doc, 2), 0).text, 'after');
    });

    test('Unicode text (Vietnamese, CJK, Thai) is preserved', () {
      const s = 'Tiếng Việt có dấu: ắ ằ ẳ ẵ ặ đ Đ — 中文漢字 日本語 — ภาษาไทย';
      final doc = readDocx(buildDocx(body: p(s)));
      expect(_run(_para(doc, 0), 0).text, s);
    });

    test('ignores deleted text, footnote refs, sdt wrappers are unwrapped', () {
      final doc = readDocx(
        buildDocx(
          body:
              '<w:sdt><w:sdtContent>${p('inside sdt')}</w:sdtContent></w:sdt>'
              '<w:p><w:del><w:r><w:delText>gone</w:delText></w:r></w:del>'
              '<w:ins><w:r><w:t>new</w:t></w:r></w:ins>'
              '<w:r><w:footnoteReference w:id="1"/></w:r></w:p>',
        ),
      );
      expect(_run(_para(doc, 0), 0).text, 'inside sdt');
      expect(
        _para(doc, 1).inlines.map((e) => (e as DocxRun).text).join(),
        'new',
      );
    });
  });

  group('page setup', () {
    test('reads final sectPr size and margins', () {
      final doc = readDocx(
        buildDocx(
          body:
              '${p('x')}<w:sectPr><w:pgSz w:w="16838" w:h="11906" w:orient="landscape"/>'
              '<w:pgMar w:top="1000" w:right="1100" w:bottom="1200" w:left="1300" w:header="708" w:footer="708" w:gutter="0"/></w:sectPr>',
        ),
      );
      expect(doc.page.widthTwips, 16838);
      expect(doc.page.heightTwips, 11906);
      expect(doc.page.marginTopTwips, 1000);
      expect(doc.page.marginRightTwips, 1100);
      expect(doc.page.marginBottomTwips, 1200);
      expect(doc.page.marginLeftTwips, 1300);
    });

    test('defaults to A4 with 1 inch margins', () {
      final doc = readDocx(buildDocx(body: p('x')));
      expect(doc.page.widthTwips, 11906);
      expect(doc.page.heightTwips, 16838);
      expect(doc.page.marginLeftTwips, 1440);
    });
  });

  group('errors', () {
    test('garbage bytes throw OfficeFormatException', () {
      expect(
        () => readDocx(Uint8List.fromList([1, 2, 3, 4, 5])),
        throwsA(isA<OfficeFormatException>()),
      );
    });
    test('zip without document.xml throws', () {
      expect(
        () => readDocx(buildZip({'a.txt': 'hi'})),
        throwsA(isA<OfficeFormatException>()),
      );
    });
    test('malformed XML throws', () {
      expect(
        () => readDocx(buildZip({'word/document.xml': '<w:document><oops'})),
        throwsA(isA<OfficeFormatException>()),
      );
    });
  });
}
