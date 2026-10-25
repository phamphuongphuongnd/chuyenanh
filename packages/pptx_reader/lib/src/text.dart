import 'package:xml/xml.dart';

import 'color.dart';
import 'model.dart';
import 'package.dart';
import 'xml_utils.dart';

PptxAnchor anchorOf(String? v) => switch (v) {
  'ctr' => PptxAnchor.middle,
  'b' => PptxAnchor.bottom,
  _ => PptxAnchor.top,
};

PptxAlign _alignOf(String? v) => switch (v) {
  'ctr' => PptxAlign.center,
  'r' => PptxAlign.right,
  'just' || 'dist' || 'justLow' || 'thaiDist' => PptxAlign.justify,
  _ => PptxAlign.left,
};

/// Plain text of an `a:p` (used for notes).
String plainText(XmlElement p) {
  final b = StringBuffer();
  for (final c in p.childElements) {
    switch (c.name.local) {
      case 'r' || 'fld':
        b.write(c.child('t')?.innerText ?? '');
      case 'br':
        b.write('\n');
    }
  }
  return b.toString();
}

/// Mergeable run properties (null = not set at this level).
class RunProps {
  bool? bold, italic, underline, strike;
  double? sizePt;
  int? color;
  String? font;
  double? baseline;
  String? link;

  RunProps copy() => RunProps()
    ..bold = bold
    ..italic = italic
    ..underline = underline
    ..strike = strike
    ..sizePt = sizePt
    ..color = color
    ..font = font
    ..baseline = baseline
    ..link = link;

  void merge(RunProps o) {
    bold = o.bold ?? bold;
    italic = o.italic ?? italic;
    underline = o.underline ?? underline;
    strike = o.strike ?? strike;
    sizePt = o.sizePt ?? sizePt;
    color = o.color ?? color;
    font = o.font ?? font;
    baseline = o.baseline ?? baseline;
    link = o.link ?? link;
  }
}

class _ParaProps {
  PptxAlign? align;
  int? marL, indent;
  String? bulletKind; // none | char | num
  String? bulletChar;
  String? bulletScheme;
  double? spcBefPt, spcBefPct, spcAftPt, spcAftPct, lnPct, lnPt;

  void apply(XmlElement? pPr) {
    if (pPr == null) return;
    final a = pPr.attr('algn');
    if (a != null) align = _alignOf(a);
    marL = pPr.intAttr('marL') ?? marL;
    indent = pPr.intAttr('indent') ?? indent;
    for (final c in pPr.childElements) {
      switch (c.name.local) {
        case 'buNone':
          bulletKind = 'none';
        case 'buChar':
          bulletKind = 'char';
          bulletChar = c.attr('char');
        case 'buAutoNum':
          bulletKind = 'num';
          bulletScheme = c.attr('type');
        case 'spcBef':
          final (pt, pct) = _spacing(c, spcBefPt, spcBefPct);
          spcBefPt = pt;
          spcBefPct = pct;
        case 'spcAft':
          final (pt, pct) = _spacing(c, spcAftPt, spcAftPct);
          spcAftPt = pt;
          spcAftPct = pct;
        case 'lnSpc':
          final pct = c.child('spcPct')?.intAttr('val');
          final pts = c.child('spcPts')?.intAttr('val');
          if (pct != null) {
            lnPct = pct / 1000.0;
            lnPt = null;
          } else if (pts != null) {
            lnPt = pts / 100.0;
            lnPct = null;
          }
      }
    }
  }

  static (double?, double?) _spacing(XmlElement c, double? pt, double? pct) {
    final pts = c.child('spcPts')?.intAttr('val');
    if (pts != null) return (pts / 100.0, null);
    final p = c.child('spcPct')?.intAttr('val');
    if (p != null) return (null, p / 1000.0);
    return (pt, pct);
  }
}

/// Resolves paragraph/run formatting through a chain of list styles.
class TextContext {
  TextContext({
    required this.levels,
    this.styleRun,
    this.own,
    required this.colors,
    this.majorFont,
    this.minorFont,
    required this.rels,
    this.fontScale = 1,
    this.lineSpacingReductionPct = 0,
    this.slideNumber = 1,
  });

  /// List-style-like elements (containing `a:lvlNpPr`), base first.
  final List<XmlElement?> levels;

  /// Run defaults from `p:style/a:fontRef`, applied after [levels].
  final RunProps? styleRun;

  /// The shape's own `a:lstStyle`, applied last.
  final XmlElement? own;
  final ColorContext colors;
  final String? majorFont;
  final String? minorFont;
  final Map<String, Rel> rels;
  final double fontScale;
  final double lineSpacingReductionPct;
  final int slideNumber;

  static const defaultFontSizePt = 18.0;

  String? _font(String? typeface) {
    if (typeface == null || typeface.isEmpty) return null;
    if (typeface.startsWith('+mj')) return majorFont;
    if (typeface.startsWith('+mn')) return minorFont;
    return typeface;
  }

  RunProps runProps(XmlElement? rPr) {
    final r = RunProps();
    if (rPr == null) return r;
    r.bold = rPr.boolAttr('b');
    r.italic = rPr.boolAttr('i');
    final u = rPr.attr('u');
    if (u != null) r.underline = u != 'none';
    final s = rPr.attr('strike');
    if (s != null) r.strike = s != 'noStrike';
    final sz = rPr.intAttr('sz');
    if (sz != null) r.sizePt = sz / 100.0;
    final bl = rPr.intAttr('baseline');
    if (bl != null) r.baseline = bl / 1000.0;
    final fill = rPr.child('solidFill');
    if (fill != null) {
      r.color = colors.colorIn(fill);
    } else {
      final grad = rPr.child('gradFill')?.child('gsLst')?.child('gs');
      if (grad != null) r.color = colors.colorIn(grad);
    }
    r.font =
        _font(rPr.child('latin')?.attr('typeface')) ??
        _font(rPr.child('ea')?.attr('typeface'));
    final link = rPr.child('hlinkClick')?.nsAttr('id');
    if (link != null) {
      final rel = rels[link];
      if (rel != null && rel.external) r.link = rel.target;
    }
    return r;
  }

  PptxParagraph paragraph(XmlElement p) {
    final pPr = p.child('pPr');
    final level = (pPr?.intAttr('lvl') ?? 0).clamp(0, 8);
    final para = _ParaProps();
    final base = RunProps();
    void applyList(XmlElement? list) {
      if (list == null) return;
      for (final tag in ['defPPr', 'lvl${level + 1}pPr']) {
        final lvl = list.child(tag);
        if (lvl == null) continue;
        para.apply(lvl);
        base.merge(runProps(lvl.child('defRPr')));
      }
    }

    levels.forEach(applyList);
    if (styleRun != null) base.merge(styleRun!);
    applyList(own);
    para.apply(pPr);

    final runs = <PptxRun>[];
    for (final c in p.childElements) {
      final kind = c.name.local;
      if (kind != 'r' && kind != 'br' && kind != 'fld') continue;
      final rp = base.copy()..merge(runProps(c.child('rPr')));
      final String text;
      if (kind == 'br') {
        text = '\n';
      } else if (kind == 'fld' && c.attr('type') == 'slidenum') {
        text = '$slideNumber';
      } else {
        text = c.child('t')?.innerText ?? '';
      }
      runs.add(_run(rp, text, isBreak: kind == 'br'));
    }

    final endRp = base.copy()..merge(runProps(p.child('endParaRPr')));
    final firstSize = runs.isEmpty
        ? _size(endRp)
        : (runs.first.fontSizePt ?? defaultFontSizePt);
    double? spacing(double? pt, double? pct) =>
        pt ?? (pct == null ? null : pct / 100.0 * firstSize);

    var lnPct = para.lnPct;
    if (lineSpacingReductionPct > 0 && para.lnPt == null) {
      lnPct = (lnPct ?? 100) - lineSpacingReductionPct;
    }
    final hasBullet = runs.any((r) => !r.isLineBreak && r.text.isNotEmpty);
    return PptxParagraph(
      align: para.align ?? PptxAlign.left,
      level: level,
      bulletChar: hasBullet && para.bulletKind == 'char'
          ? para.bulletChar
          : null,
      numbered: hasBullet && para.bulletKind == 'num',
      numberingScheme: para.bulletKind == 'num' ? para.bulletScheme : null,
      runs: runs,
      spaceBeforePt: spacing(para.spcBefPt, para.spcBefPct),
      spaceAfterPt: spacing(para.spcAftPt, para.spcAftPct),
      lineSpacingPct: lnPct,
      lineSpacingPt: para.lnPt,
      marginLeftEmu: para.marL ?? 0,
      indentEmu: para.indent ?? 0,
      endFontSizePt: _size(endRp),
    );
  }

  double _size(RunProps r) => (r.sizePt ?? defaultFontSizePt) * fontScale;

  PptxRun _run(RunProps r, String text, {required bool isBreak}) => PptxRun(
    text: text,
    bold: r.bold ?? false,
    italic: r.italic ?? false,
    underline: r.underline ?? false,
    strike: r.strike ?? false,
    fontSizePt: _size(r),
    colorArgb: r.color,
    fontFamily: r.font,
    isLineBreak: isBreak,
    baselineOffsetPct: r.baseline ?? 0,
    hyperlink: r.link,
  );
}
