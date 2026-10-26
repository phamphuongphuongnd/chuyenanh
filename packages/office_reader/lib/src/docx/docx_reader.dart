import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../common.dart';
import 'docx_model.dart';
import 'docx_numbering.dart';
import 'docx_styles.dart';

/// Parses a .docx file. Throws [OfficeFormatException] on unreadable input.
DocxDocument readDocx(Uint8List bytes) =>
    guardFormat('docx', () => _DocxReader(OoxmlPackage(bytes)).read());

const _pageBreak = Object();

class _DocxReader {
  final OoxmlPackage pkg;
  late final String docPath;
  late final Map<String, Relationship> rels;
  late final DocxStyles styles;
  late final DocxNumbering numbering;

  /// Complex-field nesting: true while inside the field *code* part.
  final List<bool> _fieldStack = [];

  _DocxReader(this.pkg);

  DocxDocument read() {
    docPath = _findMainPart();
    final doc = pkg.xml(docPath);
    if (doc == null) {
      throw const OfficeFormatException('Missing word/document.xml');
    }
    rels = pkg.rels(docPath);
    String? partOf(String typeSuffix, String fallback) {
      for (final r in rels.values) {
        if (!r.external && r.type.endsWith(typeSuffix)) return r.resolvedPath;
      }
      return fallback;
    }

    final theme = ThemeFonts.parse(
      pkg.xml(partOf('/theme', 'word/theme/theme1.xml')!),
    );
    styles = DocxStyles(pkg.xml(partOf('/styles', 'word/styles.xml')!), theme);
    numbering = DocxNumbering(
      pkg.xml(partOf('/numbering', 'word/numbering.xml')!),
    );
    _theme = theme;

    final body = doc.rootElement.child('body');
    if (body == null) {
      throw const OfficeFormatException('document.xml has no w:body');
    }
    final blocks = _blocks(body);
    final sect =
        body.child('sectPr') ??
        body.descendantElements
            .where((e) => e.localName == 'sectPr')
            .lastOrNull;
    return DocxDocument(blocks: blocks, page: _page(sect));
  }

  late ThemeFonts _theme;

  String _findMainPart() {
    final root = pkg.rels('');
    for (final r in root.values) {
      if (r.type.endsWith('/officeDocument') && pkg.has(r.resolvedPath)) {
        return r.resolvedPath;
      }
    }
    return 'word/document.xml';
  }

  DocxPageSetup _page(XmlElement? sect) {
    if (sect == null) return DocxPageSetup.a4;
    final sz = sect.child('pgSz');
    final mar = sect.child('pgMar');
    const d = DocxPageSetup.a4;
    int v(XmlElement? e, String a, int def) =>
        parseIntOrNull(e?.attr(a))?.abs() ?? def;
    return DocxPageSetup(
      widthTwips: v(sz, 'w', d.widthTwips),
      heightTwips: v(sz, 'h', d.heightTwips),
      marginTopTwips: v(mar, 'top', d.marginTopTwips),
      marginRightTwips: v(mar, 'right', d.marginRightTwips),
      marginBottomTwips: v(mar, 'bottom', d.marginBottomTwips),
      marginLeftTwips: v(mar, 'left', d.marginLeftTwips),
    );
  }

  // ---------------------------------------------------------------- blocks

  List<DocxBlock> _blocks(XmlElement container) {
    final out = <DocxBlock>[];
    for (final e in container.childElements) {
      switch (e.localName) {
        case 'p':
          out.addAll(_paragraph(e));
        case 'tbl':
          out.add(_table(e));
        case 'sdt':
          final c = e.child('sdtContent');
          if (c != null) out.addAll(_blocks(c));
        case 'customXml' || 'ins' || 'moveTo':
          out.addAll(_blocks(e));
        case 'AlternateContent':
          final pick = _alternate(e);
          if (pick != null) out.addAll(_blocks(pick));
      }
    }
    return out;
  }

  XmlElement? _alternate(XmlElement ac) =>
      ac.child('Choice') ?? ac.child('Fallback');

  List<DocxBlock> _paragraph(XmlElement p) {
    final pPr = p.child('pPr');
    final styleId = pPr?.childVal('pStyle') ?? styles.defaultParagraphStyle;
    final (styleP, styleR, styleHeading) = styles.paragraph(styleId);
    final direct = ParaProps.parse(pPr);
    var props = styleP.merge(direct);

    int? listLevel;
    var ordered = false;
    String? label;
    final numId = props.numId;
    if (numId != null && numId != 0 && numbering.exists(numId)) {
      final ilvl = props.ilvl ?? 0;
      props = styleP.merge(numbering.levelProps(numId, ilvl)).merge(direct);
      final res = numbering.next(numId, ilvl);
      if (res != null) {
        listLevel = ilvl;
        label = res.$1;
        ordered = res.$2;
      }
    }

    int? heading = styleHeading;
    if (direct.outlineLvl != null) {
      heading = direct.outlineLvl! < 6 ? direct.outlineLvl! + 1 : null;
    }

    final items = <Object>[];
    _inlines(p, styleR, null, items);

    final base = DocxParagraph(
      headingLevel: heading,
      styleId: styleId,
      align: _align(props.jc),
      listLevel: listLevel,
      listOrdered: ordered,
      listLabel: label,
      indentLeftPt: props.indLeft,
      indentRightPt: props.indRight,
      firstLineIndentPt: props.firstLine,
      spaceBeforePt: props.before,
      spaceAfterPt: props.after,
      lineSpacing: props.line,
      pageBreakBefore: props.pageBreakBefore ?? false,
    );

    if (!items.contains(_pageBreak)) {
      return [base.copyWith(inlines: items.cast<DocxInline>())];
    }
    // Split at explicit page breaks.
    final out = <DocxBlock>[];
    var seg = <DocxInline>[];
    var first = true;
    void flush() {
      if (seg.isNotEmpty) {
        out.add(
          first
              ? base.copyWith(inlines: seg)
              : base.copyWith(
                  inlines: seg,
                  clearList: true,
                  pageBreakBefore: false,
                ),
        );
      }
      first = false;
      seg = <DocxInline>[];
    }

    for (final it in items) {
      if (identical(it, _pageBreak)) {
        flush();
        out.add(const DocxPageBreak());
      } else {
        seg.add(it as DocxInline);
      }
    }
    flush();
    return out;
  }

  static DocxAlign _align(String? jc) => switch (jc) {
    'center' => DocxAlign.center,
    'right' || 'end' => DocxAlign.right,
    'both' ||
    'distribute' ||
    'justify' ||
    'lowKashida' ||
    'highKashida' ||
    'mediumKashida' ||
    'thaiDistribute' => DocxAlign.justify,
    _ => DocxAlign.left,
  };

  // --------------------------------------------------------------- inlines

  void _inlines(
    XmlElement parent,
    RunProps paraRPr,
    String? link,
    List<Object> out,
  ) {
    for (final e in parent.childElements) {
      switch (e.localName) {
        case 'r':
          _run(e, paraRPr, link, out);
        case 'hyperlink':
          String? target;
          final id = e.attr('id');
          if (id != null) target = rels[id]?.target;
          final anchor = e.attr('anchor');
          if (target == null && anchor != null) target = '#$anchor';
          _inlines(e, paraRPr, target ?? link, out);
        case 'ins' ||
            'moveTo' ||
            'smartTag' ||
            'customXml' ||
            'fldSimple' ||
            'dir' ||
            'bdo':
          _inlines(e, paraRPr, link, out);
        case 'sdt':
          final c = e.child('sdtContent');
          if (c != null) _inlines(c, paraRPr, link, out);
        case 'AlternateContent':
          final pick = _alternate(e);
          if (pick != null) _inlines(pick, paraRPr, link, out);
        case 'oMath' || 'oMathPara':
          final t = e.descendantElements
              .where((x) => x.localName == 't')
              .map((x) => x.innerText)
              .join();
          if (t.isNotEmpty && _fieldVisible) {
            out.add(_makeRun(t, paraRPr, link));
          }
      }
    }
  }

  bool get _fieldVisible => !_fieldStack.contains(true);

  RunProps _runProps(XmlElement r, RunProps paraRPr) {
    final direct = RunProps.parse(r.child('rPr'), _theme);
    final cs = direct.charStyle;
    var props = paraRPr;
    if (cs != null) props = props.merge(styles.character(cs));
    return props.merge(direct);
  }

  DocxRun _makeRun(String text, RunProps p, String? link) => DocxRun(
    text: (p.caps ?? false) || (p.smallCaps ?? false)
        ? text.toUpperCase()
        : text,
    smallCaps: p.smallCaps ?? false,
    bold: p.bold ?? false,
    italic: p.italic ?? false,
    underline: p.underline ?? false,
    strike: p.strike ?? false,
    superscript: p.superscript ?? false,
    subscript: p.subscript ?? false,
    fontSizePt: p.sizePt,
    colorArgb: p.color,
    highlightArgb: p.highlight,
    fontFamily: p.font,
    hyperlink: link,
  );

  void _run(XmlElement r, RunProps paraRPr, String? link, List<Object> out) {
    final props = _runProps(r, paraRPr);
    final hidden = props.hidden ?? false;
    final buf = StringBuffer();
    void flush() {
      if (buf.isNotEmpty) {
        if (!hidden) out.add(_makeRun(buf.toString(), props, link));
        buf.clear();
      }
    }

    void walk(Iterable<XmlElement> kids) {
      for (final e in kids) {
        switch (e.localName) {
          case 't':
            if (_fieldVisible) buf.write(e.innerText);
          case 'tab' || 'ptab':
            if (_fieldVisible) buf.write('\t');
          case 'noBreakHyphen':
            if (_fieldVisible) buf.write('-');
          case 'sym':
            final code = int.tryParse(e.attr('char') ?? '', radix: 16);
            if (code != null && _fieldVisible) {
              buf.writeCharCode(
                code >= 0xF000 && code <= 0xF0FF ? 0x2022 : code,
              );
            }
          case 'br':
            if (!_fieldVisible) break;
            flush();
            if (e.attr('type') == 'page') {
              out.add(_pageBreak);
            } else {
              out.add(const DocxBreak());
            }
          case 'cr':
            if (!_fieldVisible) break;
            flush();
            out.add(const DocxBreak());
          case 'drawing':
            if (!_fieldVisible) break;
            final img = _drawing(e);
            if (img != null) {
              flush();
              out.add(img);
            }
          case 'pict' || 'object':
            if (!_fieldVisible) break;
            final img = _vml(e);
            if (img != null) {
              flush();
              out.add(img);
            }
          case 'fldChar':
            final type = e.attr('fldCharType');
            if (type == 'begin') {
              flush();
              _fieldStack.add(true);
            } else if (type == 'separate') {
              flush();
              if (_fieldStack.isNotEmpty) {
                _fieldStack[_fieldStack.length - 1] = false;
              }
            } else if (type == 'end') {
              flush();
              if (_fieldStack.isNotEmpty) _fieldStack.removeLast();
            }
          case 'AlternateContent':
            final pick = _alternate(e);
            if (pick != null) walk(pick.childElements);
        }
      }
    }

    walk(r.childElements);
    flush();
  }

  DocxImage? _drawing(XmlElement drawing) {
    final holder = drawing.child('inline') ?? drawing.child('anchor');
    if (holder == null) return null;
    final ext = holder.child('extent');
    final blip = holder.descendant('blip');
    final id = blip?.attr('embed');
    if (id == null) return null;
    return _image(
      id,
      parseIntOrNull(ext?.attr('cx')) ?? 0,
      parseIntOrNull(ext?.attr('cy')) ?? 0,
      holder.localName == 'anchor',
    );
  }

  DocxImage? _vml(XmlElement pict) {
    final data = pict.descendant('imagedata');
    final id = data?.attr('id');
    if (id == null) return null;
    final shape = pict.descendant('shape');
    final style = shape?.getAttribute('style') ?? '';
    int emu(String key) {
      final m = RegExp(
        '$key\\s*:\\s*([0-9.]+)(pt|in|px|cm|mm)?',
      ).firstMatch(style);
      if (m == null) return 0;
      final v = double.parse(m.group(1)!);
      final unit = m.group(2) ?? 'px';
      final perUnit = switch (unit) {
        'pt' => 12700.0,
        'in' => 914400.0,
        'cm' => 360000.0,
        'mm' => 36000.0,
        _ => 9525.0,
      };
      return (v * perUnit).round();
    }

    return _image(id, emu('width'), emu('height'), false);
  }

  DocxImage? _image(String relId, int w, int h, bool floating) {
    final rel = rels[relId];
    if (rel == null || rel.external) return null;
    final bytes = pkg.bytes(rel.resolvedPath);
    if (bytes == null) return null;
    final path = rel.resolvedPath;
    final dot = path.lastIndexOf('.');
    final ext = dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
    return DocxImage(
      bytes: bytes,
      extension: ext,
      widthEmu: w,
      heightEmu: h,
      floating: floating,
    );
  }

  // ---------------------------------------------------------------- tables

  DocxTable _table(XmlElement tbl) {
    final tblPr = tbl.child('tblPr');
    final grid =
        tbl
            .child('tblGrid')
            ?.childrenNamed('gridCol')
            .map((c) => parseIntOrNull(c.attr('w')) ?? 0)
            .toList() ??
        <int>[];
    final styleId = tblPr?.childVal('tblStyle');
    final directBorders = tblPr?.child('tblBorders');
    var bordered =
        (directBorders != null ? hasVisibleBorder(directBorders) : null) ??
        styles.tableBorders(styleId) ??
        (styleId != null && styleId.toLowerCase().contains('grid'));

    final rows = <DocxTableRow>[];
    final starts = <List<int>>[]; // grid column start per cell
    for (final tr in _rowsOf(tbl)) {
      final trPr = tr.child('trPr');
      var col = parseIntOrNull(trPr?.childVal('gridBefore')) ?? 0;
      final cells = <DocxTableCell>[];
      final colStarts = <int>[];
      for (final tc in _cellsOf(tr)) {
        final tcPr = tc.child('tcPr');
        final span = (parseIntOrNull(tcPr?.childVal('gridSpan')) ?? 1).clamp(
          1,
          1000,
        );
        final vm = tcPr?.child('vMerge');
        final fill = tcPr?.child('shd')?.attr('fill');
        final tcW = tcPr?.child('tcW');
        final cellBorders = tcPr?.child('tcBorders');
        if (!bordered && cellBorders != null && hasVisibleBorder(cellBorders)) {
          bordered = true;
        }
        cells.add(
          DocxTableCell(
            blocks: _blocks(tc),
            gridSpan: span,
            vMergeContinue: vm != null && vm.attr('val') != 'restart',
            shadingArgb: fill == null || fill == 'auto'
                ? null
                : parseHexColor(fill),
            widthTwips: (tcW?.attr('type') ?? 'dxa') == 'dxa'
                ? parseIntOrNull(tcW?.attr('w'))
                : null,
          ),
        );
        colStarts.add(col);
        col += span;
      }
      final height = trPr?.child('trHeight');
      rows.add(
        DocxTableRow(
          cells: cells,
          isHeader:
              trPr?.child('tblHeader') != null &&
              ooxmlBool(trPr!.child('tblHeader')!.attr('val')),
          heightTwips: parseIntOrNull(height?.attr('val')),
        ),
      );
      starts.add(colStarts);
    }

    // Compute rowSpan for vMerge restart cells.
    for (var r = 0; r < rows.length; r++) {
      final cells = rows[r].cells;
      for (var c = 0; c < cells.length; c++) {
        if (cells[c].vMergeContinue) continue;
        var span = 1;
        for (var rr = r + 1; rr < rows.length; rr++) {
          final idx = starts[rr].indexOf(starts[r][c]);
          if (idx < 0 || !rows[rr].cells[idx].vMergeContinue) break;
          span++;
        }
        if (span > 1) cells[c] = cells[c].withRowSpan(span);
      }
    }
    return DocxTable(columnWidthsTwips: grid, rows: rows, bordered: bordered);
  }

  Iterable<XmlElement> _rowsOf(XmlElement tbl) sync* {
    for (final e in tbl.childElements) {
      if (e.localName == 'tr') {
        yield e;
      } else if (e.localName == 'sdt') {
        final c = e.child('sdtContent');
        if (c != null) yield* _rowsOf(c);
      } else if (e.localName == 'customXml') {
        yield* _rowsOf(e);
      }
    }
  }

  Iterable<XmlElement> _cellsOf(XmlElement tr) sync* {
    for (final e in tr.childElements) {
      if (e.localName == 'tc') {
        yield e;
      } else if (e.localName == 'sdt') {
        final c = e.child('sdtContent');
        if (c != null) yield* _cellsOf(c);
      } else if (e.localName == 'customXml') {
        yield* _cellsOf(e);
      }
    }
  }
}
