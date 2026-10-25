import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:pdf_layout/pdf_layout.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

import 'helpers.dart';

const _w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

XmlDocument _part(Archive zip, String name) {
  final f = zip.findFile(name);
  expect(f, isNotNull, reason: 'missing $name');
  return XmlDocument.parse(utf8.decode(f!.content));
}

Iterable<XmlElement> _all(XmlNode n, String local) => n.descendants
    .whereType<XmlElement>()
    .where((e) => e.name.local == local && e.name.namespaceUri == _w);

String _attr(XmlElement e, String local) =>
    e.attributes.firstWhere((a) => a.name.local == local).value;

String _paraText(XmlElement p) => _all(p, 't').map((t) => t.innerText).join();

void main() {
  final blocks = <DocBlock>[
    const DocHeading(level: 1, spans: [DocSpan('Báo cáo tổng hợp')]),
    const DocParagraph(
      spans: [
        DocSpan('Ký tự đặc biệt: ', bold: true),
        DocSpan('a < b & c > d "quoted" \'single\''),
      ],
      align: DocAlign.justify,
      indentPt: 18,
      firstLineIndentPt: 12,
    ),
    const DocHeading(level: 2, spans: [DocSpan('中文标题 ภาษาไทย')]),
    const DocListItem(ordered: false, marker: '•', spans: [DocSpan('Táo')]),
    const DocListItem(ordered: false, marker: '•', spans: [DocSpan('Lê')]),
    const DocListItem(ordered: true, marker: '1.', spans: [DocSpan('Một')]),
    const DocListItem(ordered: true, marker: '2.', spans: [DocSpan('Hai')]),
    const DocTable(
      cells: [
        ['Tên', 'SL', 'Giá'],
        ['Táo', '', '1.5'],
        ['Lê', '2'],
      ],
    ),
    const DocPageBreak(),
    const DocHeading(level: 3, spans: [DocSpan('Phụ lục', fontSizePt: 13)]),
    const DocParagraph(spans: [DocSpan('Control\u0001char removed\tand tab')]),
  ];

  late Archive zip;
  setUpAll(() {
    final bytes = writeDocx(blocks);
    expect(bytes.sublist(0, 2), [0x50, 0x4B]); // "PK"
    zip = ZipDecoder().decodeBytes(bytes);
  });

  test('contains all required parts, content types first', () {
    final names = zip.files.map((f) => f.name).toList();
    expect(names.first, '[Content_Types].xml');
    expect(
      names,
      containsAll([
        '[Content_Types].xml',
        '_rels/.rels',
        'word/document.xml',
        'word/styles.xml',
        'word/numbering.xml',
        'word/_rels/document.xml.rels',
        'docProps/core.xml',
      ]),
    );
  });

  test('content types declare every part', () {
    final ct = _part(zip, '[Content_Types].xml');
    final defaults = {
      for (final e in ct.findAllElements('Default'))
        e.getAttribute('Extension'): e.getAttribute('ContentType'),
    };
    expect(
      defaults['rels'],
      'application/vnd.openxmlformats-package.relationships+xml',
    );
    expect(defaults['xml'], 'application/xml');
    final overrides = {
      for (final e in ct.findAllElements('Override'))
        e.getAttribute('PartName'): e.getAttribute('ContentType'),
    };
    expect(
      overrides['/word/document.xml'],
      'application/vnd.openxmlformats-officedocument.wordprocessingml.'
      'document.main+xml',
    );
    expect(overrides['/word/styles.xml'], endsWith('styles+xml'));
    expect(overrides['/word/numbering.xml'], endsWith('numbering+xml'));
    expect(overrides['/docProps/core.xml'], endsWith('core-properties+xml'));
    for (final part in overrides.keys) {
      expect(zip.findFile(part!.substring(1)), isNotNull, reason: part);
    }
  });

  test('relationships point at existing parts', () {
    final rels = _part(zip, '_rels/.rels');
    final targets = rels
        .findAllElements('Relationship')
        .map((e) => e.getAttribute('Target'))
        .toList();
    expect(targets, contains('word/document.xml'));
    final docRels = _part(zip, 'word/_rels/document.xml.rels');
    for (final e in docRels.findAllElements('Relationship')) {
      expect(zip.findFile('word/${e.getAttribute('Target')}'), isNotNull);
    }
  });

  test('document has headings, paragraphs, lists, table and page break', () {
    final doc = _part(zip, 'word/document.xml');
    final body = _all(doc, 'body').single;
    final paras = body.childElements.where((e) => e.name.local == 'p').toList();

    String? style(XmlElement p) {
      final s = _all(p, 'pStyle');
      return s.isEmpty ? null : _attr(s.first, 'val');
    }

    final headings = paras
        .where((p) => (style(p) ?? '').startsWith('Heading'))
        .map((p) => (style(p), _paraText(p)))
        .toList();
    expect(headings, [
      ('Heading1', 'Báo cáo tổng hợp'),
      ('Heading2', '中文标题 ภาษาไทย'),
      ('Heading3', 'Phụ lục'),
    ]);

    final special = paras.firstWhere((p) => _paraText(p).startsWith('Ký tự'));
    expect(
      _paraText(special),
      'Ký tự đặc biệt: a < b & c > d "quoted" \'single\'',
    );
    expect(_all(special, 'b'), isNotEmpty);
    expect(_attr(_all(special, 'jc').single, 'val'), 'both');
    final ind = _all(special, 'ind').single;
    expect(_attr(ind, 'left'), '360');
    expect(_attr(ind, 'firstLine'), '240');

    final listParas = paras.where((p) => _all(p, 'numPr').isNotEmpty).toList();
    expect(listParas.map(_paraText).toList(), ['Táo', 'Lê', 'Một', 'Hai']);
    final numIds = listParas
        .map((p) => _attr(_all(p, 'numId').single, 'val'))
        .toList();
    expect(numIds[0], numIds[1]);
    expect(numIds[2], numIds[3]);
    expect(numIds[0], isNot(numIds[2]));

    final tables = _all(body, 'tbl').toList();
    expect(tables, hasLength(1));
    final rows = _all(tables.single, 'tr').toList();
    expect(rows, hasLength(3));
    for (final r in rows) {
      expect(_all(r, 'tc'), hasLength(3)); // ragged rows are padded
    }
    expect(_all(rows[1], 'tc').map(_paraText).toList(), ['Táo', '', '1.5']);
    expect(_all(tables.single, 'tblBorders'), isNotEmpty);

    final breaks = _all(body, 'br').where((b) => _attr(b, 'type') == 'page');
    expect(breaks, hasLength(1));

    final last = paras.last;
    expect(_paraText(last), 'Controlchar removedand tab');
    expect(_all(last, 'tab'), isNotEmpty);

    final pgSz = _all(body, 'pgSz').single;
    expect(_attr(pgSz, 'w'), '11906');
    expect(_attr(pgSz, 'h'), '16838');
  });

  test('numbering and styles define what the document uses', () {
    final numbering = _part(zip, 'word/numbering.xml');
    final abstractIds = _all(
      numbering,
      'abstractNum',
    ).map((e) => _attr(e, 'abstractNumId')).toSet();
    final fmts = _all(numbering, 'numFmt').map((e) => _attr(e, 'val')).toSet();
    expect(fmts, containsAll(['bullet', 'decimal']));
    final nums = _all(numbering, 'num').toList();
    for (final n in nums) {
      expect(
        abstractIds,
        contains(_attr(_all(n, 'abstractNumId').single, 'val')),
      );
    }

    final styles = _part(zip, 'word/styles.xml');
    final ids = _all(styles, 'style').map((e) => _attr(e, 'styleId')).toSet();
    expect(ids, containsAll(['Normal', 'Heading1', 'Heading2', 'Heading3']));
    final fonts = _all(styles, 'rFonts').first;
    expect(_attr(fonts, 'ascii'), 'Arial');
    expect(_attr(fonts, 'eastAsia'), 'Noto Sans');

    final core = _part(zip, 'docProps/core.xml');
    expect(core.rootElement.name.local, 'coreProperties');
  });

  test('empty input still produces a valid document', () {
    final z = ZipDecoder().decodeBytes(writeDocx(const []));
    final doc = _part(z, 'word/document.xml');
    expect(_all(doc, 'p'), isNotEmpty);
  });

  test('round trip: rebuilt blocks can be written', () {
    final page = mkPage([
      mkLine('Title', marginL, 60, size: 20),
      mkLine('Some body text.', marginL, 100),
    ]);
    final z = ZipDecoder().decodeBytes(writeDocx(rebuildDocument([page])));
    final doc = _part(z, 'word/document.xml');
    expect(
      _all(doc, 'p').map(_paraText),
      containsAll(['Title', 'Some body text.']),
    );
  });
}
