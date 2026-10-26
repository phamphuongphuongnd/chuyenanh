import 'dart:isolate';

import 'package:office_reader/office_reader.dart';
import 'package:test/test.dart';

import 'helpers/ooxml.dart';

void main() {
  test('readDocx / readXlsx work inside Isolate.run', () async {
    final docx = buildDocx(body: p('isolate ok'));
    final xlsx = buildXlsx(
      sheets: [
        const SheetSpec(
          'S',
          '<sheetData><row r="1"><c r="A1"><v>42</v></c></row></sheetData>',
        ),
      ],
    );
    final text = await Isolate.run(
      () => (readDocx(docx).blocks.single as DocxParagraph).plainText,
    );
    expect(text, 'isolate ok');
    final v = await Isolate.run(
      () => readXlsx(xlsx).sheets.single.cells[(0, 0)]!.display,
    );
    expect(v, '42');
  });

  test('headers, footers, footnotes and textboxes do not break parsing', () {
    final doc = readDocx(
      buildDocx(
        rels:
            '<Relationship Id="h1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/>',
        extraParts: {
          'word/header1.xml': '<w:hdr xmlns:w="x"><w:p/></w:hdr>',
          'word/footnotes.xml': '<w:footnotes xmlns:w="x"/>',
        },
        body:
            '<w:p><w:r><w:t>A</w:t></w:r>'
            '<w:r><mc:AlternateContent><mc:Choice Requires="wps"><w:drawing>'
            '<wp:anchor><wp:extent cx="10" cy="10"/><a:graphic><a:graphicData>'
            '<wps:wsp xmlns:wps="urn:wps"><wps:txbx><w:txbxContent>'
            '<w:p><w:r><w:t>textbox</w:t></w:r></w:p>'
            '</w:txbxContent></wps:txbx></wps:wsp></a:graphicData></a:graphic>'
            '</wp:anchor></w:drawing></mc:Choice>'
            '<mc:Fallback><w:pict/></mc:Fallback></mc:AlternateContent></w:r>'
            '<w:r><w:footnoteReference w:id="2"/></w:r>'
            '<w:r><w:t>B</w:t></w:r></w:p>'
            '<w:sectPr><w:headerReference r:id="h1"/></w:sectPr>',
      ),
    );
    expect((doc.blocks.single as DocxParagraph).plainText, 'AB');
  });

  test('xlsx theme colours and tint resolve', () {
    final bytes = buildXlsx(
      styles:
          '<fonts count="1"><font><color theme="4"/></font></fonts>'
          '<fills count="3"><fill><patternFill patternType="none"/></fill>'
          '<fill><patternFill patternType="gray125"/></fill>'
          '<fill><patternFill patternType="solid"><fgColor theme="0" tint="-0.5"/></patternFill></fill></fills>'
          '<borders count="1"><border/></borders>'
          '<cellXfs count="1"><xf fontId="0" fillId="2" borderId="0"/></cellXfs>',
      sheets: [
        const SheetSpec(
          'S',
          '<sheetData><row r="1"><c r="A1" s="0"><v>1</v></c></row></sheetData>',
        ),
      ],
    );
    final s = readXlsx(bytes).sheets.single.cells[(0, 0)]!.style;
    expect(s.fontColorArgb, 0xFF4472C4, reason: 'default theme accent1');
    expect(s.fillArgb, 0xFF808080, reason: 'white darkened 50%');
  });

  test('truncated zip throws OfficeFormatException', () {
    final good = buildDocx(body: p('x'));
    expect(
      () => readDocx(good.sublist(0, good.length ~/ 2)),
      throwsA(isA<OfficeFormatException>()),
    );
  });
}
