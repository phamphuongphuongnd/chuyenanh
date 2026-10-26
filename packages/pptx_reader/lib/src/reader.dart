import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:xml/xml.dart';

import 'color.dart';
import 'model.dart';
import 'package.dart';
import 'text.dart';
import 'xml_utils.dart';

/// Parses a .pptx file. Pure and synchronous, safe to call inside
/// `Isolate.run`. Throws [PptxFormatException] for unreadable input.
PptxDeck readPptx(Uint8List bytes) {
  try {
    return _Reader(OpcPackage.open(bytes)).read();
  } on PptxFormatException {
    rethrow;
  } catch (e) {
    throw PptxFormatException('Cannot read pptx: $e');
  }
}

// ------------------------------------------------------------------ parts

class _Part {
  _Part(this.path, this.root, this.rels);

  final String path;
  final XmlElement root;
  final Map<String, Rel> rels;

  Rel? relOfType(String suffix) =>
      rels.values.firstWhereOrNull((r) => r.type.endsWith(suffix));
}

class _Theme {
  _Theme(
    this.colors,
    this.majorFont,
    this.minorFont,
    this.lineWidths, {
    this.fillStyles = const [],
    this.bgFillStyles = const [],
    this.part,
  });

  /// `fmtScheme/fillStyleLst` and `bgFillStyleLst` children (fillRef idx 1..,
  /// bgRef idx 1001..), and the theme part (for image rels).
  final List<XmlElement> fillStyles;
  final List<XmlElement> bgFillStyles;
  final _Part? part;
  final Map<String, int> colors;
  final String? majorFont;
  final String? minorFont;
  final List<int> lineWidths;
}

const _officeColors = <String, int>{
  'dk1': 0x000000,
  'lt1': 0xFFFFFF,
  'dk2': 0x44546A,
  'lt2': 0xE7E6E6,
  'accent1': 0x4472C4,
  'accent2': 0xED7D31,
  'accent3': 0xA5A5A5,
  'accent4': 0xFFC000,
  'accent5': 0x5B9BD5,
  'accent6': 0x70AD47,
  'hlink': 0x0563C1,
  'folHlink': 0x954F72,
};

class _Ph {
  _Ph(this.type, this.idx, this.el);

  final String type;
  final String? idx;
  final XmlElement el;
}

class _Master {
  _Master(this.part, this.theme, this.clrMap, this.txStyles, this.phs);

  final _Part part;
  final _Theme theme;
  final Map<String, String> clrMap;
  final XmlElement? txStyles;
  final List<_Ph> phs;
}

class _Layout {
  _Layout(this.part, this.master, this.phs);

  final _Part part;
  final _Master master;
  final List<_Ph> phs;

  bool get showMasterSp => part.root.boolAttr('showMasterSp') ?? true;
}

/// Affine (scale + translate) transform from a group's child space to slide.
class _Xf {
  const _Xf(this.sx, this.sy, this.tx, this.ty);

  static const identity = _Xf(1, 1, 0, 0);

  final double sx, sy, tx, ty;

  _Xf then(_Xf local) =>
      _Xf(sx * local.sx, sy * local.sy, sx * local.tx + tx, sy * local.ty + ty);

  PptxRect rect(int x, int y, int cx, int cy) {
    final x0 = sx * x + tx;
    final y0 = sy * y + ty;
    return PptxRect(
      x0.round(),
      y0.round(),
      (x0 + sx * cx).round() - x0.round(),
      (y0 + sy * cy).round() - y0.round(),
    );
  }
}

/// A shape element together with the part it lives in (for rels lookups).
class _Src {
  _Src(this.el, this.part);

  final XmlElement el;
  final _Part part;
}

class _Ctx {
  _Ctx({
    required this.part,
    required this.colors,
    required this.master,
    required this.layout,
    required this.slideIndex,
    this.xf = _Xf.identity,
    this.groupFill,
    this.skipPlaceholders = false,
  });

  final _Part part;
  final ColorContext colors;
  final _Master master;

  /// Set for slide shapes only: enables placeholder inheritance.
  final _Layout? layout;
  final int slideIndex;
  final _Xf xf;
  final PptxFill? groupFill;
  final bool skipPlaceholders;

  _Ctx child(_Xf local, PptxFill? fill) => _Ctx(
    part: part,
    colors: colors,
    master: master,
    layout: layout,
    slideIndex: slideIndex,
    xf: xf.then(local),
    groupFill: fill,
    skipPlaceholders: skipPlaceholders,
  );
}

// ------------------------------------------------------------------ reader

class _Reader {
  _Reader(this.pkg);

  final OpcPackage pkg;
  final _masters = <String, _Master>{};
  final _layouts = <String, _Layout>{};
  XmlElement? _defaultTextStyle;
  String? _firstMasterPath;
  String? _tableStylesPath;
  Map<String, XmlElement>? _tableStyleMap;

  /// `a:tblStyle` elements of ppt/tableStyles.xml keyed by styleId (lazy).
  Map<String, XmlElement> _tableStyles() {
    return _tableStyleMap ??= {
      for (final s
          in (_tableStylesPath == null ? null : pkg.xml(_tableStylesPath!))
                  ?.kids('tblStyle') ??
              <XmlElement>[])
        if (s.attr('styleId') != null) s.attr('styleId')!: s,
    };
  }

  _Part? _part(String path) {
    final root = pkg.xml(path);
    return root == null ? null : _Part(path, root, pkg.rels(path));
  }

  PptxDeck read() {
    final pkgRels = pkg.rels('');
    final presPath =
        pkgRels.values
            .firstWhereOrNull((r) => r.type.endsWith('/officeDocument'))
            ?.target ??
        'ppt/presentation.xml';
    final pres = _part(presPath);
    if (pres == null || pres.root.name.local != 'presentation') {
      throw const PptxFormatException('Missing ppt/presentation.xml');
    }
    _defaultTextStyle = pres.root.child('defaultTextStyle');
    _firstMasterPath = pres.relOfType('/slideMaster')?.target;
    _tableStylesPath = pres.relOfType('/tableStyles')?.target;
    final sz = pres.root.child('sldSz');
    final width = sz?.intAttr('cx') ?? 9144000;
    final height = sz?.intAttr('cy') ?? 6858000;

    final slides = <PptxSlide>[];
    for (final sid
        in pres.root.child('sldIdLst')?.kids('sldId') ?? <XmlElement>[]) {
      final rel = pres.rels[sid.nsAttr('id')];
      if (rel == null || rel.external) continue;
      final part = _part(rel.target);
      if (part == null) continue;
      slides.add(_slide(slides.length, part));
    }
    return PptxDeck(
      slideWidthEmu: width,
      slideHeightEmu: height,
      slides: slides,
    );
  }

  // ---------------------------------------------------------------- master

  _Master _master(String? path) {
    final key = path ?? '';
    return _masters.putIfAbsent(key, () {
      final part =
          (path == null ? null : _part(path)) ??
          _Part('', XmlElement.tag('sldMaster'), const {});
      final themeRel = part.relOfType('/theme');
      final theme = _theme(themeRel == null ? null : _part(themeRel.target));
      final clrMap = <String, String>{
        for (final a
            in part.root.child('clrMap')?.attributes ?? <XmlAttribute>[])
          a.name.local: a.value,
      };
      return _Master(
        part,
        theme,
        clrMap,
        part.root.child('txStyles'),
        _placeholders(part.root),
      );
    });
  }

  _Theme _theme(_Part? themePart) {
    final els = themePart?.root.child('themeElements');
    final colors = Map<String, int>.of(_officeColors);
    for (final c in els?.child('clrScheme')?.childElements ?? <XmlElement>[]) {
      final v = c.childElements.firstOrNull;
      if (v == null) continue;
      final hex = v.name.local == 'sysClr' ? v.attr('lastClr') : v.attr('val');
      final argb = ColorContext.parseHex(hex);
      if (argb != null) colors[c.name.local] = argb & 0xFFFFFF;
    }
    final fonts = els?.child('fontScheme');
    String? font(String which) {
      final t = fonts?.at([which, 'latin'])?.attr('typeface');
      return (t == null || t.isEmpty) ? null : t;
    }

    return _Theme(colors, font('majorFont'), font('minorFont'), [
      for (final ln
          in els?.at(['fmtScheme', 'lnStyleLst'])?.kids('ln') ?? <XmlElement>[])
        ln.intAttr('w') ?? 9525,
    ], fillStyles: [
      ...?els?.at(['fmtScheme', 'fillStyleLst'])?.childElements,
    ], bgFillStyles: [
      ...?els?.at(['fmtScheme', 'bgFillStyleLst'])?.childElements,
    ], part: themePart);
  }

  _Layout _layout(String? path) {
    final key = path ?? '';
    return _layouts.putIfAbsent(key, () {
      final part =
          (path == null ? null : _part(path)) ??
          _Part('', XmlElement.tag('sldLayout'), const {});
      final masterPath =
          part.relOfType('/slideMaster')?.target ?? _firstMasterPath;
      return _Layout(part, _master(masterPath), _placeholders(part.root));
    });
  }

  List<_Ph> _placeholders(XmlElement root) {
    final tree = root.at(['cSld', 'spTree']);
    if (tree == null) return const [];
    final out = <_Ph>[];
    for (final e in tree.childElements) {
      final ph = _phElement(e);
      if (ph != null) out.add(_Ph(ph.attr('type') ?? 'obj', ph.attr('idx'), e));
    }
    return out;
  }

  // ---------------------------------------------------------------- slide

  PptxSlide _slide(int index, _Part part) {
    final layout = _layout(part.relOfType('/slideLayout')?.target);
    final master = layout.master;
    final clrMap =
        _clrOverride(part.root) ??
        _clrOverride(layout.part.root) ??
        master.clrMap;
    final colors = ColorContext(
      themeColors: master.theme.colors,
      clrMap: clrMap,
    );

    final showMaster = part.root.boolAttr('showMasterSp') ?? true;
    final shapes = <PptxShape>[];
    if (showMaster && layout.showMasterSp) {
      _treeShapes(
        master.part,
        _Ctx(
          part: master.part,
          colors: colors,
          master: master,
          layout: null,
          slideIndex: index,
          skipPlaceholders: true,
        ),
        shapes,
      );
    }
    if (showMaster) {
      _treeShapes(
        layout.part,
        _Ctx(
          part: layout.part,
          colors: colors,
          master: master,
          layout: null,
          slideIndex: index,
          skipPlaceholders: true,
        ),
        shapes,
      );
    }
    _treeShapes(
      part,
      _Ctx(
        part: part,
        colors: colors,
        master: master,
        layout: layout,
        slideIndex: index,
      ),
      shapes,
    );

    return PptxSlide(
      index: index,
      background: _background(
        [part, layout.part, master.part],
        colors,
        master.theme,
      ),
      shapes: shapes,
      notesText: _notes(part),
      hidden: part.root.boolAttr('show') == false,
    );
  }

  Map<String, String>? _clrOverride(XmlElement root) {
    final o = root.at(['clrMapOvr', 'overrideClrMapping']);
    if (o == null) return null;
    return {for (final a in o.attributes) a.name.local: a.value};
  }

  void _treeShapes(_Part part, _Ctx ctx, List<PptxShape> out) {
    final tree = part.root.at(['cSld', 'spTree']);
    if (tree == null) return;
    for (final e in tree.childElements) {
      _shape(e, ctx, out);
    }
  }

  PptxFill? _background(
    List<_Part> parts,
    ColorContext colors,
    _Theme theme,
  ) {
    for (final p in parts) {
      final bg = p.root.at(['cSld', 'bg']);
      if (bg == null) continue;
      final bgPr = bg.child('bgPr');
      if (bgPr != null) {
        final (specified, fill) = _fill(bgPr, p, colors, null);
        if (specified) return fill;
      }
      final ref = bg.child('bgRef');
      if (ref != null) return _refFill(ref, colors, theme);
    }
    return null;
  }

  String? _notes(_Part slide) {
    final rel = slide.relOfType('/notesSlide');
    if (rel == null) return null;
    final notes = pkg.xml(rel.target);
    final tree = notes?.at(['cSld', 'spTree']);
    if (tree == null) return null;
    final lines = <String>[];
    for (final e in tree.childElements) {
      if (_phElement(e)?.attr('type') != 'body') continue;
      for (final p in e.child('txBody')?.kids('p') ?? <XmlElement>[]) {
        lines.add(plainText(p));
      }
    }
    final text = lines.join('\n').trim();
    return text.isEmpty ? null : text;
  }

  // ---------------------------------------------------------------- shapes

  static XmlElement? _nvPr(XmlElement shape) {
    for (final c in shape.childElements) {
      final n = c.name.local;
      if (n.startsWith('nv') && n.endsWith('Pr')) return c;
    }
    return null;
  }

  static XmlElement? _phElement(XmlElement shape) =>
      _nvPr(shape)?.at(['nvPr', 'ph']);

  static String _phCategory(String type) => switch (type) {
    'title' || 'ctrTitle' => 'title',
    'dt' || 'ftr' || 'sldNum' || 'hdr' => type,
    _ => 'body',
  };

  /// [shape, layout placeholder?, master placeholder?] for inheritance.
  List<_Src> _chain(XmlElement shape, _Ctx ctx) {
    final out = [_Src(shape, ctx.part)];
    final ph = _phElement(shape);
    final layout = ctx.layout;
    if (ph == null || layout == null) return out;
    final type = ph.attr('type') ?? 'obj';
    final idx = ph.attr('idx');
    _Ph? lp;
    if (idx != null) lp = layout.phs.firstWhereOrNull((p) => p.idx == idx);
    lp ??= layout.phs.firstWhereOrNull((p) => p.type == type);
    lp ??= layout.phs.firstWhereOrNull(
      (p) => _phCategory(p.type) == _phCategory(type),
    );
    if (lp != null) out.add(_Src(lp.el, layout.part));
    final mType = lp?.type ?? type;
    final phs = layout.master.phs;
    final mp =
        phs.firstWhereOrNull((p) => p.type == mType) ??
        phs.firstWhereOrNull((p) => _phCategory(p.type) == _phCategory(mType));
    if (mp != null) out.add(_Src(mp.el, layout.master.part));
    return out;
  }

  static XmlElement? _xfrmOf(XmlElement shape) =>
      shape.name.local == 'graphicFrame'
      ? shape.child('xfrm')
      : shape.child('spPr')?.child('xfrm');

  void _shape(XmlElement e, _Ctx ctx, List<PptxShape> out) {
    final kind = e.name.local;
    if (kind == 'AlternateContent') {
      final fb = e.child('Fallback');
      final pick = (fb != null && fb.childElements.isNotEmpty)
          ? fb
          : e.child('Choice');
      for (final c in pick?.childElements ?? <XmlElement>[]) {
        _shape(c, ctx, out);
      }
      return;
    }
    if (!const {'sp', 'cxnSp', 'pic', 'graphicFrame', 'grpSp'}.contains(kind)) {
      return;
    }
    final cNvPr = _nvPr(e)?.child('cNvPr');
    if (cNvPr?.boolAttr('hidden') == true) return;
    if (ctx.skipPlaceholders && _phElement(e) != null) return;
    final name = cNvPr?.attr('name') ?? '';

    if (kind == 'grpSp') {
      out.add(_group(e, ctx, name));
      return;
    }
    final chain = _chain(e, ctx);
    final xfrm = chain.map((s) => _xfrmOf(s.el)).nonNulls.firstOrNull;
    final off = xfrm?.child('off');
    final ext = xfrm?.child('ext');
    if (off == null || ext == null) return; // nothing to place
    final g = _Geom(
      ctx.xf.rect(
        off.intAttr('x') ?? 0,
        off.intAttr('y') ?? 0,
        ext.intAttr('cx') ?? 0,
        ext.intAttr('cy') ?? 0,
      ),
      (xfrm!.intAttr('rot') ?? 0) / 60000.0,
      xfrm.boolAttr('flipH') ?? false,
      xfrm.boolAttr('flipV') ?? false,
      name,
    );
    switch (kind) {
      case 'sp':
        out.add(_sp(e, chain, g, ctx, connector: false));
      case 'cxnSp':
        out.add(_sp(e, chain, g, ctx, connector: true));
      case 'pic':
        out.add(_pic(e, g, ctx));
      case 'graphicFrame':
        out.add(_graphicFrame(e, g, ctx));
    }
  }

  PptxShape _group(XmlElement e, _Ctx ctx, String name) {
    final x = e.at(['grpSpPr', 'xfrm']);
    var frame = const PptxRect(0, 0, 0, 0);
    var local = _Xf.identity;
    if (x != null) {
      final ox = x.child('off')?.intAttr('x') ?? 0;
      final oy = x.child('off')?.intAttr('y') ?? 0;
      final cx = x.child('ext')?.intAttr('cx') ?? 0;
      final cy = x.child('ext')?.intAttr('cy') ?? 0;
      final chx = x.child('chOff')?.intAttr('x') ?? ox;
      final chy = x.child('chOff')?.intAttr('y') ?? oy;
      final chcx = x.child('chExt')?.intAttr('cx') ?? cx;
      final chcy = x.child('chExt')?.intAttr('cy') ?? cy;
      final sx = chcx == 0 ? 1.0 : cx / chcx;
      final sy = chcy == 0 ? 1.0 : cy / chcy;
      local = _Xf(sx, sy, ox - chx * sx, oy - chy * sy);
      frame = ctx.xf.rect(ox, oy, cx, cy);
    }
    final grpSpPr = e.child('grpSpPr');
    final fill = grpSpPr == null
        ? ctx.groupFill
        : _fill(grpSpPr, ctx.part, ctx.colors, ctx.groupFill).$2;
    final childCtx = ctx.child(local, fill);
    final children = <PptxShape>[];
    for (final c in e.childElements) {
      _shape(c, childCtx, children);
    }
    return PptxGroupShape(
      frame: frame,
      rotationDeg: (x?.intAttr('rot') ?? 0) / 60000.0,
      flipH: x?.boolAttr('flipH') ?? false,
      flipV: x?.boolAttr('flipV') ?? false,
      name: name,
      children: children,
    );
  }

  PptxShape _sp(
    XmlElement e,
    List<_Src> chain,
    _Geom g,
    _Ctx ctx, {
    required bool connector,
  }) {
    final style = e.child('style');

    // Geometry.
    var geometry = PptxGeometry.rect;
    String? preset;
    var customPaths = const <PptxCustomPath>[];
    for (final s in chain) {
      final spPr = s.el.child('spPr');
      final pg = spPr?.child('prstGeom');
      if (pg != null) {
        preset = pg.attr('prst');
        geometry = _geometry(preset);
        break;
      }
      final cg = spPr?.child('custGeom');
      if (cg != null) {
        geometry = PptxGeometry.other;
        customPaths = _customPaths(cg, g);
        break;
      }
    }
    if (connector) geometry = PptxGeometry.line;

    // Fill.
    PptxFill? fill;
    var fillSpecified = false;
    for (final s in chain) {
      final spPr = s.el.child('spPr');
      if (spPr == null) continue;
      final (spec, f) = _fill(spPr, s.part, ctx.colors, ctx.groupFill);
      if (spec) {
        fill = f;
        fillSpecified = true;
        break;
      }
    }
    if (!fillSpecified && !connector) {
      final ref = style?.child('fillRef');
      if (ref != null) fill = _refFill(ref, ctx.colors, ctx.master.theme);
    }
    if (connector) fill = null;

    final line = _line(
      chain.map((s) => s.el.child('spPr')?.child('ln')).nonNulls,
      style,
      ctx,
    );

    // Body properties, merged master -> layout -> shape.
    final bodyAttrs = <String, String>{};
    for (final s in chain.reversed) {
      final bp = s.el.at(['txBody', 'bodyPr']);
      if (bp == null) continue;
      for (final a in bp.attributes) {
        bodyAttrs[a.name.local] = a.value;
      }
    }
    int ins(String k, int d) => int.tryParse(bodyAttrs[k] ?? '') ?? d;
    final autofit = e.at(['txBody', 'bodyPr', 'normAutofit']);
    final fontScale = (autofit?.intAttr('fontScale') ?? 100000) / 100000.0;
    final lnReduction = (autofit?.intAttr('lnSpcReduction') ?? 0) / 1000.0;

    // Text styles.
    final ph = _phElement(e);
    final category = ph == null
        ? 'other'
        : _phCategory(ph.attr('type') ?? 'obj');
    final txStyles = ctx.master.txStyles;
    final baseStyle = switch (category) {
      'title' => txStyles?.child('titleStyle'),
      'body' => txStyles?.child('bodyStyle'),
      _ => txStyles?.child('otherStyle'),
    };
    RunProps? styleRun;
    final fontRef = style?.child('fontRef');
    if (fontRef != null) {
      styleRun = RunProps()
        ..color = ctx.colors.colorIn(fontRef)
        ..font = switch (fontRef.attr('idx')) {
          'major' => ctx.master.theme.majorFont,
          'minor' => ctx.master.theme.minorFont,
          _ => null,
        };
    }
    final text = TextContext(
      levels: [
        _defaultTextStyle,
        baseStyle,
        for (final s in chain.reversed.take(chain.length - 1))
          s.el.at(['txBody', 'lstStyle']),
      ],
      styleRun: styleRun,
      own: e.at(['txBody', 'lstStyle']),
      colors: ctx.colors,
      majorFont: ctx.master.theme.majorFont,
      minorFont: ctx.master.theme.minorFont,
      rels: ctx.part.rels,
      fontScale: fontScale,
      lineSpacingReductionPct: lnReduction,
      slideNumber: ctx.slideIndex + 1,
    );
    final paragraphs = [
      for (final p in e.child('txBody')?.kids('p') ?? <XmlElement>[])
        text.paragraph(p),
    ];

    final vert = bodyAttrs['vert'];
    return PptxTextShape(
      frame: g.frame,
      rotationDeg: g.rot,
      flipH: g.flipH,
      flipV: g.flipV,
      name: g.name,
      geometry: geometry,
      presetGeometry: preset,
      customPaths: customPaths,
      fill: fill,
      line: line,
      paragraphs: paragraphs,
      insets: PptxInsets(
        left: ins('lIns', 91440),
        top: ins('tIns', 45720),
        right: ins('rIns', 91440),
        bottom: ins('bIns', 45720),
      ),
      verticalAnchor: anchorOf(bodyAttrs['anchor']),
      wrap: bodyAttrs['wrap'] != 'none',
      verticalText: vert != null && vert != 'horz',
    );
  }

  /// Reads `a:custGeom/a:pathLst`. Coordinates that are guide names (formulas
  /// in `a:gdLst`) are not evaluated: such a path is skipped.
  static List<PptxCustomPath> _customPaths(XmlElement cg, _Geom g) {
    final paths = <PptxCustomPath>[];
    for (final path in cg.child('pathLst')?.kids('path') ?? <XmlElement>[]) {
      var w = path.intAttr('w') ?? 0;
      var h = path.intAttr('h') ?? 0;
      if (w <= 0) w = g.frame.cx;
      if (h <= 0) h = g.frame.cy;
      var ok = true;
      double? num(String? v) {
        final d = v == null ? null : double.tryParse(v);
        if (d == null) ok = false;
        return d;
      }

      List<double> pts(XmlElement c) => [
        for (final p in c.kids('pt')) ...[
          num(p.attr('x')) ?? 0,
          num(p.attr('y')) ?? 0,
        ],
      ];
      final cmds = <PptxPathCommand>[];
      for (final c in path.childElements) {
        switch (c.name.local) {
          case 'moveTo':
            cmds.add(PptxPathCommand(PptxPathOp.moveTo, pts(c)));
          case 'lnTo':
            cmds.add(PptxPathCommand(PptxPathOp.lineTo, pts(c)));
          case 'cubicBezTo':
            cmds.add(PptxPathCommand(PptxPathOp.cubicTo, pts(c)));
          case 'quadBezTo':
            cmds.add(PptxPathCommand(PptxPathOp.quadTo, pts(c)));
          case 'arcTo':
            cmds.add(
              PptxPathCommand(PptxPathOp.arcTo, [
                num(c.attr('wR')) ?? 0,
                num(c.attr('hR')) ?? 0,
                (num(c.attr('stAng')) ?? 0) / 60000.0,
                (num(c.attr('swAng')) ?? 0) / 60000.0,
              ]),
            );
          case 'close':
            cmds.add(const PptxPathCommand(PptxPathOp.close));
        }
      }
      if (!ok || cmds.isEmpty) continue;
      paths.add(
        PptxCustomPath(
          widthEmu: w,
          heightEmu: h,
          commands: cmds,
          filled: path.attr('fill') != 'none',
          stroked: path.boolAttr('stroke') ?? true,
        ),
      );
    }
    return paths;
  }

  static PptxGeometry _geometry(String? prst) => switch (prst) {
    'rect' || null => PptxGeometry.rect,
    'roundRect' => PptxGeometry.roundRect,
    'ellipse' => PptxGeometry.ellipse,
    'triangle' || 'rtTriangle' => PptxGeometry.triangle,
    'line' || 'straightConnector1' => PptxGeometry.line,
    final p when p.contains('Connector') => PptxGeometry.line,
    _ => PptxGeometry.other,
  };

  PptxLine? _line(Iterable<XmlElement> lns, XmlElement? style, _Ctx ctx) {
    int? width;
    int? color;
    var colorSpecified = false;
    for (final ln in lns) {
      width ??= ln.intAttr('w');
      if (colorSpecified) continue;
      if (ln.child('noFill') != null) {
        colorSpecified = true;
      } else if (ln.child('solidFill') != null) {
        color = ctx.colors.colorIn(ln.child('solidFill'));
        colorSpecified = true;
      } else if (ln.child('gradFill') != null) {
        color = _firstStop(ln.child('gradFill')!, ctx.colors);
        colorSpecified = true;
      }
    }
    final ref = style?.child('lnRef');
    final refIdx = ref?.intAttr('idx') ?? 0;
    if (!colorSpecified && refIdx > 0) {
      color = ctx.colors.colorIn(ref);
    }
    if (width == null && refIdx > 0) {
      final widths = ctx.master.theme.lineWidths;
      if (refIdx <= widths.length) width = widths[refIdx - 1];
    }
    if (color == null) return null;
    return PptxLine(colorArgb: color, widthEmu: width ?? 9525);
  }

  static int? _firstStop(XmlElement grad, ColorContext cc) {
    final gs = grad.child('gsLst')?.kids('gs').firstOrNull;
    return gs == null ? null : cc.colorIn(gs);
  }

  /// Returns (specified, fill). `specified` is false when [container] has no
  /// fill element at all, so the caller should keep inheriting.
  (bool, PptxFill?) _fill(
    XmlElement container,
    _Part part,
    ColorContext cc,
    PptxFill? groupFill,
  ) {
    for (final f in container.childElements) {
      final r = _fillOf(f, part, cc, groupFill);
      if (r.$1) return r;
    }
    return (false, null);
  }

  /// One fill element (`a:solidFill`, `a:gradFill`, ...). `specified` is false
  /// when [f] is not a fill element.
  (bool, PptxFill?) _fillOf(
    XmlElement f,
    _Part part,
    ColorContext cc,
    PptxFill? groupFill,
  ) {
    switch (f.name.local) {
      case 'noFill':
        return (true, null);
      case 'solidFill':
        final c = cc.colorIn(f);
        return (true, c == null ? null : PptxFill.solid(c));
      case 'gradFill':
        final c = _firstStop(f, cc);
        return (true, c == null ? null : PptxFill.solid(c));
      case 'pattFill':
        final c = cc.colorIn(f.child('fgClr'));
        return (true, c == null ? null : PptxFill.solid(c));
      case 'grpFill':
        return (true, groupFill);
      case 'blipFill':
        final img = _image(f.child('blip'), part);
        return (true, img == null ? null : PptxFill.picture(img.$1, img.$2));
    }
    return (false, null);
  }

  /// Fill of a `fillRef` / `bgRef` (idx 1.. = theme fillStyleLst, 1001.. =
  /// bgFillStyleLst, 0 = none). The theme style is applied with the reference
  /// colour as `phClr`; without a matching theme style the colour is used as a
  /// solid fill.
  PptxFill? _refFill(XmlElement ref, ColorContext cc, _Theme theme) {
    final idx = ref.intAttr('idx') ?? 0;
    if (idx == 0) return null;
    final c = cc.colorIn(ref);
    final bg = idx >= 1001;
    final styles = bg ? theme.bgFillStyles : theme.fillStyles;
    final i = bg ? idx - 1001 : idx - 1;
    if (i >= 0 && i < styles.length) {
      final (spec, f) = _fillOf(
        styles[i],
        theme.part ?? _Part('', XmlElement.tag('theme'), const {}),
        cc.withPhClr(c),
        null,
      );
      if (spec && (f != null || styles[i].name.local == 'noFill')) return f;
    }
    return c == null ? null : PptxFill.solid(c);
  }

  (Uint8List, String)? _image(XmlElement? blip, _Part part) {
    final id = blip?.nsAttr('embed');
    final rel = id == null ? null : part.rels[id];
    if (rel == null || rel.external) return null;
    final bytes = pkg.media(rel.target);
    if (bytes == null || bytes.isEmpty) return null;
    final dot = rel.target.lastIndexOf('.');
    final ext = dot < 0 ? '' : rel.target.substring(dot + 1).toLowerCase();
    return (bytes, ext);
  }

  PptxShape _pic(XmlElement e, _Geom g, _Ctx ctx) {
    final blipFill = e.child('blipFill');
    final img = _image(blipFill?.child('blip'), ctx.part);
    final line = _line(
      [e.child('spPr')?.child('ln')].nonNulls,
      e.child('style'),
      ctx,
    );
    if (img == null) {
      return PptxTextShape(
        frame: g.frame,
        rotationDeg: g.rot,
        flipH: g.flipH,
        flipV: g.flipV,
        name: g.name,
        line: line,
        unsupportedKind: 'image',
      );
    }
    final src = blipFill?.child('srcRect');
    PptxCrop? crop;
    if (src != null && src.attributes.isNotEmpty) {
      double v(String k) => (src.intAttr(k) ?? 0) / 100000.0;
      crop = PptxCrop(left: v('l'), top: v('t'), right: v('r'), bottom: v('b'));
    }
    return PptxPictureShape(
      frame: g.frame,
      rotationDeg: g.rot,
      flipH: g.flipH,
      flipV: g.flipV,
      name: g.name,
      bytes: img.$1,
      extension: img.$2,
      crop: crop,
      line: line,
    );
  }

  PptxShape _graphicFrame(XmlElement e, _Geom g, _Ctx ctx) {
    final data = e.at(['graphic', 'graphicData']);
    final tbl = data?.child('tbl');
    if (tbl != null) return _table(tbl, g, ctx);
    final uri = data?.attr('uri') ?? '';
    final kind = uri.endsWith('/chart') || uri.contains('chart')
        ? 'chart'
        : uri.contains('diagram')
        ? 'diagram'
        : uri.contains('ole')
        ? 'ole'
        : 'graphic';
    return PptxTextShape(
      frame: g.frame,
      rotationDeg: g.rot,
      flipH: g.flipH,
      flipV: g.flipV,
      name: g.name,
      unsupportedKind: kind,
    );
  }

  PptxShape _table(XmlElement tbl, _Geom g, _Ctx ctx) {
    final cols = [
      for (final c in tbl.child('tblGrid')?.kids('gridCol') ?? <XmlElement>[])
        c.intAttr('w') ?? 0,
    ];
    final theme = ctx.master.theme;
    final cc = ctx.colors;

    // Explicit cell border: (specified, line).
    (bool, PptxLine?) border(XmlElement? ln) {
      if (ln == null) return (false, null);
      if (ln.child('noFill') != null) return (true, null);
      final c = cc.colorIn(ln.child('solidFill'));
      if (c == null) return (false, null);
      return (true, PptxLine(colorArgb: c, widthEmu: ln.intAttr('w') ?? 12700));
    }

    // Border from a table-style tcBdr side (`a:ln` or `a:lnRef`).
    PptxLine? styleBorder(XmlElement? side) {
      if (side == null) return null;
      final ln = side.child('ln');
      if (ln != null) return border(ln).$2;
      final ref = side.child('lnRef');
      final idx = ref?.intAttr('idx') ?? 0;
      final c = cc.colorIn(ref);
      if (c == null || idx <= 0) return null;
      final w = idx <= theme.lineWidths.length
          ? theme.lineWidths[idx - 1]
          : 12700;
      return PptxLine(colorArgb: c, widthEmu: w);
    }

    final tblPr = tbl.child('tblPr');
    final styleId = tblPr?.child('tableStyleId')?.innerText.trim();
    final tblStyle = styleId == null ? null : _tableStyles()[styleId];
    bool flag(String k) => tblPr?.boolAttr(k) ?? false;
    final trs = tbl.kids('tr').toList();
    final nRows = trs.length;
    final nCols = cols.length;

    final rows = <PptxTableRow>[];
    for (var r = 0; r < nRows; r++) {
      final tr = trs[r];
      final cells = <PptxTableCell>[];
      var c = 0;
      for (final tc in tr.kids('tc')) {
        final tcPr = tc.child('tcPr');

        // Table style parts, lowest priority first: (element, row-region?, col-region?).
        final parts = <(XmlElement, bool, bool)>[];
        if (tblStyle != null) {
          void add(String name, bool rowRegion, bool colRegion) {
            final e = tblStyle.child(name);
            if (e != null) parts.add((e, rowRegion, colRegion));
          }

          final isFirstRow = flag('firstRow') && r == 0;
          final isLastRow = flag('lastRow') && r == nRows - 1;
          final isFirstCol = flag('firstCol') && c == 0;
          final isLastCol = flag('lastCol') && c == nCols - 1;
          add('wholeTbl', false, false);
          if (flag('bandRow') && !isFirstRow && !isLastRow) {
            final band = r - (flag('firstRow') ? 1 : 0);
            add(band.isEven ? 'band1H' : 'band2H', true, false);
          }
          if (flag('bandCol') && !isFirstCol && !isLastCol) {
            final band = c - (flag('firstCol') ? 1 : 0);
            add(band.isEven ? 'band1V' : 'band2V', false, true);
          }
          if (isFirstCol) add('firstCol', false, true);
          if (isLastCol) add('lastCol', false, true);
          if (isLastRow) add('lastRow', true, false);
          if (isFirstRow) add('firstRow', true, false);
        }

        PptxFill? fill;
        PptxLine? bl, bt, br, bb;
        final run = RunProps();
        for (final (part, rowRegion, colRegion) in parts) {
          final tcStyle = part.child('tcStyle');
          final f = tcStyle?.child('fill');
          if (f != null) {
            final (spec, v) = _fill(f, ctx.part, cc, null);
            if (spec) fill = v;
          }
          final fr = tcStyle?.child('fillRef');
          if (fr != null) {
            final col = cc.colorIn(fr);
            fill = (fr.intAttr('idx') ?? 0) > 0 && col != null
                ? PptxFill.solid(col)
                : null;
          }
          final bdr = tcStyle?.child('tcBdr');
          if (bdr != null) {
            final leftEdge = rowRegion || c == 0;
            final rightEdge = rowRegion || c == nCols - 1;
            final topEdge = colRegion || r == 0;
            final bottomEdge = colRegion || r == nRows - 1;
            PptxLine? side(bool edge, String outer, String inner) =>
                styleBorder(bdr.child(edge ? outer : inner));
            bl = side(leftEdge, 'left', 'insideV') ?? bl;
            br = side(rightEdge, 'right', 'insideV') ?? br;
            bt = side(topEdge, 'top', 'insideH') ?? bt;
            bb = side(bottomEdge, 'bottom', 'insideH') ?? bb;
          }
          final tx = part.child('tcTxStyle');
          if (tx != null) {
            final b = tx.attr('b');
            if (b != null) run.bold = b == 'on';
            final i = tx.attr('i');
            if (i != null) run.italic = i == 'on';
            final fontRef = tx.child('fontRef');
            run.color = cc.colorIn(tx) ?? cc.colorIn(fontRef) ?? run.color;
            run.font = switch (fontRef?.attr('idx')) {
              'major' => theme.majorFont,
              'minor' => theme.minorFont,
              _ => run.font,
            };
          }
        }
        if (tcPr != null) {
          final (spec, f) = _fill(tcPr, ctx.part, cc, null);
          if (spec) fill = f;
          PptxLine? explicit(String tag, PptxLine? fallback) {
            final (spec, l) = border(tcPr.child(tag));
            return spec ? l : fallback;
          }

          bl = explicit('lnL', bl);
          bt = explicit('lnT', bt);
          br = explicit('lnR', br);
          bb = explicit('lnB', bb);
        }

        final text = TextContext(
          levels: [_defaultTextStyle, ctx.master.txStyles?.child('otherStyle')],
          styleRun: parts.isEmpty ? null : run,
          colors: cc,
          majorFont: theme.majorFont,
          minorFont: theme.minorFont,
          rels: ctx.part.rels,
          slideNumber: ctx.slideIndex + 1,
        );
        cells.add(
          PptxTableCell(
            paragraphs: [
              for (final p in tc.child('txBody')?.kids('p') ?? <XmlElement>[])
                text.paragraph(p),
            ],
            fill: fill,
            gridSpan: tc.intAttr('gridSpan') ?? 1,
            rowSpan: tc.intAttr('rowSpan') ?? 1,
            hMerge: tc.boolAttr('hMerge') ?? false,
            vMerge: tc.boolAttr('vMerge') ?? false,
            insets: PptxInsets(
              left: tcPr?.intAttr('marL') ?? 91440,
              top: tcPr?.intAttr('marT') ?? 45720,
              right: tcPr?.intAttr('marR') ?? 91440,
              bottom: tcPr?.intAttr('marB') ?? 45720,
            ),
            verticalAnchor: anchorOf(tcPr?.attr('anchor')),
            borderLeft: bl,
            borderTop: bt,
            borderRight: br,
            borderBottom: bb,
          ),
        );
        c++;
      }
      rows.add(PptxTableRow(heightEmu: tr.intAttr('h') ?? 0, cells: cells));
    }
    return PptxTableShape(
      frame: g.frame,
      rotationDeg: g.rot,
      flipH: g.flipH,
      flipV: g.flipV,
      name: g.name,
      columnWidthsEmu: cols,
      rows: rows,
    );
  }
}

class _Geom {
  _Geom(this.frame, this.rot, this.flipH, this.flipV, this.name);

  final PptxRect frame;
  final double rot;
  final bool flipH;
  final bool flipV;
  final String name;
}
