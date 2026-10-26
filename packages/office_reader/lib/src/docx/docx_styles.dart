import 'package:xml/xml.dart';

import '../common.dart';

/// Run-level formatting; null fields mean "inherit".
class RunProps {
  final bool? bold, italic, underline, strike, superscript, subscript, hidden;
  final double? sizePt;
  final int? color, highlight;
  final bool clearHighlight;
  final String? font;
  final String? charStyle;

  const RunProps({
    this.bold,
    this.italic,
    this.underline,
    this.strike,
    this.superscript,
    this.subscript,
    this.hidden,
    this.sizePt,
    this.color,
    this.highlight,
    this.clearHighlight = false,
    this.font,
    this.charStyle,
  });

  static const empty = RunProps();

  /// [o] overrides this.
  RunProps merge(RunProps o) => RunProps(
    bold: o.bold ?? bold,
    italic: o.italic ?? italic,
    underline: o.underline ?? underline,
    strike: o.strike ?? strike,
    superscript: o.superscript ?? superscript,
    subscript: o.subscript ?? subscript,
    hidden: o.hidden ?? hidden,
    sizePt: o.sizePt ?? sizePt,
    color: o.color ?? color,
    highlight: o.clearHighlight ? null : (o.highlight ?? highlight),
    font: o.font ?? font,
    charStyle: o.charStyle ?? charStyle,
  );

  static RunProps parse(XmlElement? rPr, ThemeFonts theme) {
    if (rPr == null) return empty;
    bool? toggle(String n) {
      final e = rPr.child(n);
      return e == null ? null : ooxmlBool(e.attr('val'));
    }

    final u = rPr.child('u');
    bool? strike = toggle('strike');
    final dstrike = toggle('dstrike');
    if (dstrike == true) strike = true;
    final va = rPr.childVal('vertAlign');
    final sz = parseDoubleOrNull(rPr.childVal('sz'));
    final colorVal = rPr.childVal('color');
    final hl = rPr.childVal('highlight');
    int? highlight;
    var clear = false;
    if (hl != null) {
      if (hl == 'none') {
        clear = true;
      } else {
        highlight = highlightColors[hl];
      }
    } else {
      final fill = rPr.child('shd')?.attr('fill');
      if (fill != null && fill != 'auto') highlight = parseHexColor(fill);
    }
    return RunProps(
      bold: toggle('b'),
      italic: toggle('i'),
      underline: u == null ? null : (u.attr('val') ?? 'single') != 'none',
      strike: strike,
      superscript: va == null ? null : va == 'superscript',
      subscript: va == null ? null : va == 'subscript',
      hidden: toggle('vanish'),
      sizePt: sz == null ? null : sz / 2,
      color: colorVal == null || colorVal == 'auto'
          ? null
          : parseHexColor(colorVal),
      highlight: highlight,
      clearHighlight: clear,
      font: _font(rPr.child('rFonts'), theme),
      charStyle: rPr.childVal('rStyle'),
    );
  }

  static String? _font(XmlElement? f, ThemeFonts theme) {
    if (f == null) return null;
    for (final n in ['ascii', 'hAnsi', 'eastAsia', 'cs']) {
      final v = f.attr(n);
      if (v != null && v.isNotEmpty) return v;
    }
    for (final n in ['asciiTheme', 'hAnsiTheme', 'eastAsiaTheme', 'cstheme']) {
      final v = f.attr(n);
      if (v == null) continue;
      final r = v.startsWith('major') ? theme.major : theme.minor;
      if (r != null) return r;
    }
    return null;
  }
}

const highlightColors = <String, int>{
  'black': 0xFF000000,
  'blue': 0xFF0000FF,
  'cyan': 0xFF00FFFF,
  'green': 0xFF00FF00,
  'magenta': 0xFFFF00FF,
  'red': 0xFFFF0000,
  'yellow': 0xFFFFFF00,
  'white': 0xFFFFFFFF,
  'darkBlue': 0xFF000080,
  'darkCyan': 0xFF008080,
  'darkGreen': 0xFF008000,
  'darkMagenta': 0xFF800080,
  'darkRed': 0xFF800000,
  'darkYellow': 0xFF808000,
  'darkGray': 0xFF808080,
  'lightGray': 0xFFC0C0C0,
};

/// Paragraph-level formatting; null fields mean "inherit". Values in pt.
class ParaProps {
  final String? jc;
  final double? indLeft, indRight, firstLine;
  final double? before, after, line;
  final int? numId, ilvl, outlineLvl;
  final bool? pageBreakBefore;

  const ParaProps({
    this.jc,
    this.indLeft,
    this.indRight,
    this.firstLine,
    this.before,
    this.after,
    this.line,
    this.numId,
    this.ilvl,
    this.outlineLvl,
    this.pageBreakBefore,
  });

  static const empty = ParaProps();

  ParaProps merge(ParaProps o) => ParaProps(
    jc: o.jc ?? jc,
    indLeft: o.indLeft ?? indLeft,
    indRight: o.indRight ?? indRight,
    firstLine: o.firstLine ?? firstLine,
    before: o.before ?? before,
    after: o.after ?? after,
    line: o.line ?? line,
    numId: o.numId ?? numId,
    ilvl: o.ilvl ?? ilvl,
    outlineLvl: o.outlineLvl ?? outlineLvl,
    pageBreakBefore: o.pageBreakBefore ?? pageBreakBefore,
  );

  static ParaProps parse(XmlElement? pPr) {
    if (pPr == null) return empty;
    double? tw(String? v) {
      final d = parseDoubleOrNull(v);
      return d == null ? null : d / 20;
    }

    final ind = pPr.child('ind');
    double? firstLine;
    if (ind != null) {
      final h = tw(ind.attr('hanging'));
      firstLine = h != null ? -h : tw(ind.attr('firstLine'));
    }
    final sp = pPr.child('spacing');
    double? line;
    if (sp != null) {
      final rule = sp.attr('lineRule') ?? 'auto';
      final l = parseDoubleOrNull(sp.attr('line'));
      if (l != null && rule == 'auto') line = l / 240;
    }
    final numPr = pPr.child('numPr');
    final pbb = pPr.child('pageBreakBefore');
    return ParaProps(
      jc: pPr.childVal('jc'),
      indLeft: ind == null ? null : tw(ind.attr('left') ?? ind.attr('start')),
      indRight: ind == null ? null : tw(ind.attr('right') ?? ind.attr('end')),
      firstLine: firstLine,
      before: sp == null ? null : tw(sp.attr('before')),
      after: sp == null ? null : tw(sp.attr('after')),
      line: line,
      numId: parseIntOrNull(numPr?.childVal('numId')),
      ilvl: parseIntOrNull(numPr?.childVal('ilvl')),
      outlineLvl: parseIntOrNull(pPr.childVal('outlineLvl')),
      pageBreakBefore: pbb == null ? null : ooxmlBool(pbb.attr('val')),
    );
  }
}

class ThemeFonts {
  final String? major, minor;
  const ThemeFonts({this.major, this.minor});

  static ThemeFonts parse(XmlDocument? theme) {
    if (theme == null) return const ThemeFonts();
    String? latin(String scheme) =>
        theme.rootElement.descendant(scheme)?.child('latin')?.attr('typeface');
    return ThemeFonts(major: latin('majorFont'), minor: latin('minorFont'));
  }
}

class _Style {
  final String id, type;
  final String? name, basedOn;
  final ParaProps pPr;
  final RunProps rPr;
  final bool? tblBorders;
  _Style(
    this.id,
    this.type,
    this.name,
    this.basedOn,
    this.pPr,
    this.rPr,
    this.tblBorders,
  );
}

/// Resolved `styles.xml`.
class DocxStyles {
  final Map<String, _Style> _styles = {};
  ParaProps defaultPPr = ParaProps.empty;
  RunProps defaultRPr = RunProps.empty;
  String? defaultParagraphStyle;
  final _pCache = <String, (ParaProps, RunProps, int?)>{};

  DocxStyles(XmlDocument? doc, ThemeFonts theme) {
    if (doc == null) return;
    final root = doc.rootElement;
    final dd = root.child('docDefaults');
    if (dd != null) {
      defaultRPr = RunProps.parse(dd.child('rPrDefault')?.child('rPr'), theme);
      defaultPPr = ParaProps.parse(dd.child('pPrDefault')?.child('pPr'));
    }
    for (final s in root.childrenNamed('style')) {
      final id = s.attr('styleId');
      if (id == null) continue;
      final type = s.attr('type') ?? 'paragraph';
      final tb = s.child('tblPr')?.child('tblBorders');
      final st = _Style(
        id,
        type,
        s.childVal('name'),
        s.childVal('basedOn'),
        ParaProps.parse(s.child('pPr')),
        RunProps.parse(s.child('rPr'), theme),
        tb == null ? null : hasVisibleBorder(tb),
      );
      _styles[id] = st;
      if (type == 'paragraph' &&
          ooxmlBool(s.attr('default'), ifMissing: false)) {
        defaultParagraphStyle = id;
      }
    }
  }

  List<_Style> _chain(String? id) {
    final out = <_Style>[];
    final seen = <String>{};
    var cur = id;
    while (cur != null && seen.add(cur)) {
      final s = _styles[cur];
      if (s == null) break;
      out.add(s);
      cur = s.basedOn;
    }
    return out.reversed.toList(); // root first
  }

  /// Effective (pPr, rPr, headingLevel) of a paragraph style incl. defaults.
  (ParaProps, RunProps, int?) paragraph(String? styleId) {
    final key = styleId ?? '';
    final cached = _pCache[key];
    if (cached != null) return cached;
    var p = defaultPPr;
    var r = defaultRPr;
    int? heading;
    for (final s in _chain(styleId)) {
      p = p.merge(s.pPr);
      r = r.merge(s.rPr);
      final h = _headingFromName(s);
      if (h != null) heading = h;
    }
    if (heading == null && p.outlineLvl != null && p.outlineLvl! < 6) {
      heading = p.outlineLvl! + 1;
    }
    return _pCache[key] = (p, r, heading);
  }

  /// Merged rPr of a character style chain (no defaults).
  RunProps character(String? styleId) {
    var r = RunProps.empty;
    for (final s in _chain(styleId)) {
      r = r.merge(s.rPr);
    }
    return r;
  }

  bool? tableBorders(String? styleId) {
    bool? b;
    for (final s in _chain(styleId)) {
      if (s.tblBorders != null) b = s.tblBorders;
    }
    return b;
  }

  static final _headingName = RegExp(
    r'^heading\s*([1-9])$',
    caseSensitive: false,
  );

  static int? _headingFromName(_Style s) {
    for (final n in [s.name, s.id]) {
      if (n == null) continue;
      final m = _headingName.firstMatch(n.trim());
      if (m != null) {
        final lvl = int.parse(m.group(1)!);
        return lvl <= 6 ? lvl : null;
      }
    }
    return null;
  }
}

bool hasVisibleBorder(XmlElement borders) {
  for (final b in borders.childElements) {
    final v = b.attr('val');
    if (v != null && v != 'none' && v != 'nil') return true;
  }
  return false;
}
