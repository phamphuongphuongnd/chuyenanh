// Kiểm thử hộp trắng (A18) — lib/src/docx_writer.dart. Mong đợi chép từ buoc-5-du-lieu-thu.md.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pdf_layout/pdf_layout.dart';
import 'package:pdf_layout/src/docx_writer.dart' show cleanXmlText;
import 'package:test/test.dart';
import 'package:xml/xml.dart';

DocParagraph _p(String t) => DocParagraph(spans: [DocSpan(t)]);
DocListItem _l(String m, {bool ordered = false}) =>
    DocListItem(ordered: ordered, marker: m, spans: const [DocSpan('item')]);

XmlDocument _part(Uint8List b, String name) => XmlDocument.parse(
  utf8.decode(ZipDecoder().decodeBytes(b).findFile(name)!.content),
);
XmlDocument _doc(List<DocBlock> blocks, [DocxWriteOptions o = const DocxWriteOptions()]) =>
    _part(writeDocx(blocks, options: o), 'word/document.xml');
XmlDocument _num(List<DocBlock> blocks) =>
    _part(writeDocx(blocks), 'word/numbering.xml');

XmlElement _body(XmlDocument d) => d.findAllElements('w:body').single;
List<XmlElement> _bodyKids(XmlDocument d) => _body(d).childElements.toList();
XmlElement _firstP(XmlDocument d) => _body(d).findElements('w:p').first;
String? _attr(XmlElement? e, String a) => e?.getAttribute(a);
XmlElement? _one(XmlElement e, String name) =>
    e.findAllElements(name).isEmpty ? null : e.findAllElements(name).first;
List<String?> _numIds(XmlDocument d) => [
  for (final p in _body(d).findElements('w:p'))
    _attr(_one(p, 'w:numId'), 'w:val'),
];

void main() {
  group('U1 cleanXmlText', () {
    test('U1-P1 chữ thường giữ', () => expect(cleanXmlText('a'), 'a'));
    test('U1-P2/P3/P4 tab, LF, CR giữ', () {
      expect(cleanXmlText('\t'), '\t');
      expect(cleanXmlText('\n'), '\n');
      expect(cleanXmlText('\r'), '\r');
    });
    test('U1-P5 ký tự điều khiển bị bỏ', () => expect(cleanXmlText('x\u0001y'), 'xy'));
    test('U1-P6 surrogate lẻ bị bỏ', () {
      expect(cleanXmlText('x${String.fromCharCode(0xD800)}y'), 'xy');
    });
    test('U1-P7 U+E000 giữ', () => expect(cleanXmlText('\uE000'), '\uE000'));
    test('U1-P8 U+FFFE bị bỏ', () => expect(cleanXmlText('x\uFFFEy'), 'xy'));
    test('U1-P9 U+10000 giữ', () => expect(cleanXmlText('𐀀'), '𐀀'));
    test('U1-P9b qua writeDocx: XML hợp lệ, chữ ab', () {
      final d = _doc([_p('a\u0001b')]);
      expect(_firstP(d).innerText, 'ab');
    });
  });

  group('U2 _core', () {
    XmlDocument core(DocxWriteOptions o) => _part(writeDocx(const [], options: o), 'docProps/core.xml');
    test('U2-P1 có title + created', () {
      final c = core(DocxWriteOptions(title: 'Tiêu đề', created: DateTime.utc(2026, 1, 2, 3, 4, 5)));
      expect(c.findAllElements('dc:title').single.innerText, 'Tiêu đề');
      expect(c.findAllElements('dcterms:created').single.innerText, '2026-01-02T03:04:05Z');
    });
    test('U2-P2 created null ⇒ giờ hiện tại UTC', () {
      final now = DateTime.now().toUtc();
      final t = core(const DocxWriteOptions()).findAllElements('dcterms:created').single.innerText;
      expect(t, matches(RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$')));
      expect(DateTime.parse(t).difference(now).inSeconds.abs(), lessThanOrEqualTo(60));
    });
    test('U2-P3 title null ⇒ không dc:title; creator PDF Office', () {
      final c = core(const DocxWriteOptions());
      expect(c.findAllElements('dc:title'), isEmpty);
      expect(c.findAllElements('dc:creator').single.innerText, 'PDF Office');
    });
  });

  test('U3-P1 styles có Heading1..3 đậm, outlineLvl 0..2', () {
    final s = _part(writeDocx(const []), 'word/styles.xml');
    for (var lv = 1; lv <= 3; lv++) {
      final st = s.findAllElements('w:style').firstWhere((e) => e.getAttribute('w:styleId') == 'Heading$lv');
      expect(_one(st, 'w:b'), isNotNull);
      expect(_attr(_one(st, 'w:outlineLvl'), 'w:val'), '${lv - 1}');
    }
  });

  group('U4–U7 numbering', () {
    List<(String?, String?)> abstracts(XmlDocument n) => [
      for (final a in n.findAllElements('w:abstractNum'))
        (_attr(_one(a, 'w:numFmt'), 'w:val'), _attr(_one(a, 'w:lvlText'), 'w:val')),
    ];
    String? startOf(XmlDocument n, String? numId) {
      final num = n.findAllElements('w:num').firstWhere((e) => e.getAttribute('w:numId') == numId);
      return _attr(_one(num, 'w:startOverride'), 'w:val');
    }

    test('U4-P1 hai bullet • ⇒ 1 abstractNum, cùng numId 1', () {
      expect(abstracts(_num([_l('•'), _l('•')])), [('bullet', '•')]);
      expect(_numIds(_doc([_l('•'), _l('•')])), ['1', '1']);
    });
    test('U4-P2 bullet - ⇒ thêm abstractNum', () {
      expect(abstracts(_num([_l('-')])), [('bullet', '•'), ('bullet', '-')]);
    });
    test('U5-P1 3. ⇒ decimal %1., startOverride 3', () {
      final blocks = [_l('3.', ordered: true)];
      expect(abstracts(_num(blocks)), contains(('decimal', '%1.')));
      expect(startOf(_num(blocks), _numIds(_doc(blocks)).single), '3');
    });
    test('U5-P2 - ⇒ bullet -', () => expect(abstracts(_num([_l('-')])).last, ('bullet', '-')));
    test('U5-P3 marker rỗng ⇒ bullet •', () {
      expect(abstracts(_num([_l('')])), [('bullet', '•')]);
    });
    test('U5-P4 b) ⇒ lowerLetter %1), start 2', () {
      final blocks = [_l('b)', ordered: true)];
      expect(abstracts(_num(blocks)), contains(('lowerLetter', '%1)')));
      expect(startOf(_num(blocks), _numIds(_doc(blocks)).single), '2');
    });
    test('U5-P5 C. ⇒ upperLetter %1., start 3', () {
      final blocks = [_l('C.', ordered: true)];
      expect(abstracts(_num(blocks)), contains(('upperLetter', '%1.')));
      expect(startOf(_num(blocks), _numIds(_doc(blocks)).single), '3');
    });
    test('U5-P6 iv. ⇒ decimal %1., start 1', () {
      final blocks = [_l('iv.', ordered: true)];
      expect(abstracts(_num(blocks)), contains(('decimal', '%1.')));
      expect(startOf(_num(blocks), _numIds(_doc(blocks)).single), '1');
    });
    test('U5-B1 marker số rất dài ⇒ không ném, ra .docx có 1 đoạn list', () {
      final r = (() {
        try {
          return writeDocx([_l('99999999999999999999.', ordered: true)]);
        } catch (e) {
          return e;
        }
      })();
      expect(r, isA<Uint8List>());
      expect(_numIds(_part(r as Uint8List, 'word/document.xml')).single, isNotNull);
    });
    test('U6-P1 đoạn văn chen giữa ⇒ 2 numId khác nhau', () {
      final ids = _numIds(_doc([_l('1.', ordered: true), _p('x'), _l('1.', ordered: true)]));
      expect(ids[1], isNull);
      expect(ids[0], isNot(ids[2]));
    });
    test('U6-P2 1. ⇒ numId ≠ 1, startOverride 1', () {
      final blocks = [_l('1.', ordered: true)];
      final id = _numIds(_doc(blocks)).single;
      expect(id, isNot('1'));
      expect(startOf(_num(blocks), id), '1');
    });
    test('U6-P3 • ⇒ numId 1', () => expect(_numIds(_doc([_l('•')])), ['1']));
    test('U6-P4 hai bullet - ⇒ cùng numId ≠ 1', () {
      final ids = _numIds(_doc([_l('-'), _l('-')]));
      expect(ids[0], ids[1]);
      expect(ids[0], isNot('1'));
    });
    test('U6-P5 1. rồi 2. ⇒ cùng numId', () {
      final ids = _numIds(_doc([_l('1.', ordered: true), _l('2.', ordered: true)]));
      expect(ids[0], ids[1]);
    });
    test('U7-P1 rỗng ⇒ 1 abstractNum bullet có rPr; num 1 không lvlOverride', () {
      final n = _num(const []);
      final a = n.findAllElements('w:abstractNum').single;
      expect(_one(a, 'w:rFonts'), isNotNull);
      final num = n.findAllElements('w:num').single;
      expect(num.getAttribute('w:numId'), '1');
      expect(_one(num, 'w:lvlOverride'), isNull);
    });
    test('U7-P2/P3 số ⇒ abstractNum decimal không rPr; num có startOverride 3', () {
      final n = _num([_l('3.', ordered: true)]);
      final dec = n.findAllElements('w:abstractNum').firstWhere((a) => _attr(_one(a, 'w:numFmt'), 'w:val') == 'decimal');
      expect(_one(dec, 'w:rPr'), isNull);
      expect(n.findAllElements('w:startOverride').map((e) => e.getAttribute('w:val')), contains('3'));
    });
  });

  group('U8 write', () {
    test('U8-P1 [P] ⇒ không thêm w:p rỗng', () {
      final kids = _bodyKids(_doc([_p('a')]));
      expect(kids.map((e) => e.name.qualified), ['w:p', 'w:sectPr']);
      expect(kids.first.innerText, 'a');
    });
    test('U8-P2 [] ⇒ 1 w:p rỗng + sectPr', () {
      final kids = _bodyKids(_doc(const []));
      expect(kids.map((e) => e.name.qualified), ['w:p', 'w:sectPr']);
      expect(kids.first.innerText, '');
    });
    test('U8-P3 bảng cuối ⇒ có w:p sau w:tbl', () {
      final kids = _bodyKids(_doc(const [
        DocTable(cells: [
          ['a'],
        ]),
      ]));
      expect(kids.map((e) => e.name.qualified), ['w:tbl', 'w:p', 'w:sectPr']);
    });
  });

  group('U9 _block', () {
    String? style(DocBlock b) => _attr(_one(_firstP(_doc([b])), 'w:pStyle'), 'w:val');
    test('U9-P1 heading level 2 / 0 / 7 ⇒ Heading2 / Heading1 / Heading3', () {
      expect(style(const DocHeading(level: 2, spans: [DocSpan('h')])), 'Heading2');
      expect(style(const DocHeading(level: 0, spans: [DocSpan('h')])), 'Heading1');
      expect(style(const DocHeading(level: 7, spans: [DocSpan('h')])), 'Heading3');
    });
    test('U9-P2 đoạn ⇒ không pStyle', () => expect(style(_p('x')), isNull));
    test('U9-P3 list ⇒ ListParagraph + numId', () {
      final p = _firstP(_doc([_l('•')]));
      expect(_attr(_one(p, 'w:pStyle'), 'w:val'), 'ListParagraph');
      expect(_one(p, 'w:numId'), isNotNull);
    });
    test('U9-P5 bảng ⇒ w:tbl', () {
      expect(_doc(const [
        DocTable(cells: [
          ['a'],
        ]),
      ]).findAllElements('w:tbl'), hasLength(1));
    });
    test('U9-P6 ngắt trang ⇒ w:br page', () {
      final br = _doc(const [DocPageBreak()]).findAllElements('w:br').single;
      expect(br.getAttribute('w:type'), 'page');
    });
  });

  group('U10 _paragraph', () {
    XmlElement? ppr(DocBlock b) => _firstP(_doc([b])).getElement('w:pPr');
    DocParagraph par(DocAlign a, double ind, double first) =>
        DocParagraph(spans: const [DocSpan('x')], align: a, indentPt: ind, firstLineIndentPt: first);
    Map<String, String> ind(XmlElement? p) => {
      for (final at in _one(p!, 'w:ind')?.attributes ?? <XmlAttribute>[]) at.name.qualified: at.value,
    };
    String? jc(XmlElement? p) => _attr(_one(p!, 'w:jc'), 'w:val');

    test('U10-P1 left 0 0 ⇒ không pPr', () => expect(ppr(par(DocAlign.left, 0, 0)), isNull));
    test('U10-P2 center ⇒ jc center, không ind', () {
      final p = ppr(par(DocAlign.center, 0, 0));
      expect(jc(p), 'center');
      expect(_one(p!, 'w:ind'), isNull);
    });
    test('U10-P3 right ⇒ jc right', () => expect(jc(ppr(par(DocAlign.right, 0, 0))), 'right'));
    test('U10-P4 justify ⇒ jc both', () => expect(jc(ppr(par(DocAlign.justify, 0, 0))), 'both'));
    test('U10-P5 heading ⇒ pStyle, không numPr/ind/jc', () {
      final p = ppr(const DocHeading(level: 1, spans: [DocSpan('h')]));
      expect(_attr(_one(p!, 'w:pStyle'), 'w:val'), 'Heading1');
      expect(_one(p, 'w:numPr'), isNull);
      expect(_one(p, 'w:ind'), isNull);
      expect(_one(p, 'w:jc'), isNull);
    });
    test('U10-P7 indent 36 ⇒ ind left 720', () {
      expect(ind(ppr(par(DocAlign.left, 36, 0))), {'w:left': '720'});
    });
    test('U10-P8 firstLine 18 ⇒ ind left 0 firstLine 360', () {
      expect(ind(ppr(par(DocAlign.left, 0, 18))), {'w:left': '0', 'w:firstLine': '360'});
    });
    test('U10-P10 list ⇒ pStyle + numPr', () {
      final p = ppr(_l('•'));
      expect(_one(p!, 'w:pStyle'), isNotNull);
      expect(_one(p, 'w:numPr'), isNotNull);
    });
    test('U10-P11 justify + indent 36 ⇒ ind left 720 + jc both', () {
      final p = ppr(par(DocAlign.justify, 36, 0));
      expect(ind(p), {'w:left': '720'});
      expect(jc(p), 'both');
    });
    test('U10-P12 justify + hanging 18 ⇒ ind hanging 360 + jc both', () {
      final p = ppr(par(DocAlign.justify, 0, -18));
      expect(ind(p), {'w:left': '0', 'w:hanging': '360'});
      expect(jc(p), 'both');
    });
    test('U10-P13 left 36 + firstLine 18', () {
      expect(ind(ppr(par(DocAlign.left, 36, 18))), {'w:left': '720', 'w:firstLine': '360'});
    });
    test('U10-P14 left 36 + hanging 18', () {
      expect(ind(ppr(par(DocAlign.left, 36, -18))), {'w:left': '720', 'w:hanging': '360'});
    });
  });

  group('U11 _run / U12 flushText', () {
    XmlElement run(DocSpan s) =>
        _firstP(_doc([DocParagraph(spans: [s])])).findElements('w:r').single;
    List<String> kids(XmlElement r) =>
        [for (final e in r.childElements) e.name.qualified == 'w:t' ? 't:${e.innerText}' : e.name.qualified];

    test('U11-P1 chữ thường ⇒ 1 w:r không rPr, w:t preserve', () {
      final r = run(const DocSpan('ab'));
      expect(r.getElement('w:rPr'), isNull);
      expect(r.getElement('w:t')!.getAttribute('xml:space'), 'preserve');
      expect(kids(r), ['t:ab']);
    });
    test('U11-P2 ô bảng rỗng ⇒ w:p không w:r', () {
      final tc = _doc(const [
        DocTable(cells: [
          ['', 'x'],
        ]),
      ]).findAllElements('w:tc').first;
      expect(tc.findAllElements('w:p'), hasLength(1));
      expect(tc.findAllElements('w:r'), isEmpty);
    });
    test('U11-P3 đậm ⇒ w:b, w:bCs, không w:sz', () {
      final rp = run(const DocSpan('b', bold: true)).getElement('w:rPr')!;
      expect(rp.getElement('w:b'), isNotNull);
      expect(rp.getElement('w:bCs'), isNotNull);
      expect(rp.getElement('w:sz'), isNull);
    });
    test('U11-P4 14pt ⇒ sz 28, không w:b', () {
      final rp = run(const DocSpan('s', fontSizePt: 14)).getElement('w:rPr')!;
      expect(_attr(rp.getElement('w:sz'), 'w:val'), '28');
      expect(_attr(rp.getElement('w:szCs'), 'w:val'), '28');
      expect(rp.getElement('w:b'), isNull);
    });
    test('U11-P5 0pt ⇒ không w:sz', () {
      final r = run(const DocSpan('z', fontSizePt: 0));
      expect(r.findAllElements('w:sz'), isEmpty);
    });
    test('U11-P7 đậm + 12pt ⇒ w:b + sz 24', () {
      final rp = run(const DocSpan('bs', bold: true, fontSizePt: 12)).getElement('w:rPr')!;
      expect(rp.getElement('w:b'), isNotNull);
      expect(_attr(rp.getElement('w:sz'), 'w:val'), '24');
    });
    test('U11-P8 / U12-P2 tab ⇒ w:tab; không w:t rỗng trước tab', () {
      expect(kids(run(const DocSpan('a\tb'))), ['t:a', 'w:tab', 't:b']);
      expect(kids(run(const DocSpan('\tb'))), ['w:tab', 't:b']);
    });
    test('U11-P9 xuống dòng ⇒ w:br', () => expect(kids(run(const DocSpan('a\nb'))), ['t:a', 'w:br', 't:b']));
    test('U11-P10 CR bị bỏ', () => expect(kids(run(const DocSpan('a\rb'))), ['t:ab']));
    test('U12-P1 có chữ ⇒ w:t', () => expect(kids(run(const DocSpan('ab'))), ['t:ab']));
  });

  group('U13 _table / U14 _sectPr', () {
    test('U13-P1/P2 hàng lệch ⇒ 2 gridCol, mỗi hàng 2 ô, ô thiếu rỗng', () {
      final tbl = _doc(const [
        DocTable(cells: [
          ['a', 'b'],
          ['c'],
        ]),
      ]).findAllElements('w:tbl').single;
      expect(tbl.findAllElements('w:gridCol'), hasLength(2));
      final rows = tbl.findAllElements('w:tr').toList();
      expect(rows.map((r) => r.findElements('w:tc').length), [2, 2]);
      expect(rows[1].findElements('w:tc').last.innerText, '');
    });
    test('U13-P3 bảng 0 cột ⇒ không w:tbl, vẫn có 1 w:p', () {
      final d = _doc(const [DocTable(cells: [])]);
      expect(d.findAllElements('w:tbl'), isEmpty);
      expect(_body(d).findElements('w:p'), hasLength(1));
    });
    test('U14-P1 mặc định A4 dọc ⇒ không orient', () {
      final sz = _doc(const []).findAllElements('w:pgSz').single;
      expect((sz.getAttribute('w:w'), sz.getAttribute('w:h')), ('11906', '16838'));
      expect(sz.getAttribute('w:orient'), isNull);
    });
    test('U14-P2 ngang ⇒ orient landscape', () {
      final sz = _doc(const [], const DocxWriteOptions(pageWidthPt: 841.9, pageHeightPt: 595.3))
          .findAllElements('w:pgSz')
          .single;
      expect(sz.getAttribute('w:orient'), 'landscape');
    });
  });
}
