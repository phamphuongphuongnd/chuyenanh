import 'package:xml/xml.dart';

import '../common.dart';
import 'number_format.dart';
import 'xlsx_model.dart';

/// Default Office theme colours, used when the workbook has no theme part.
const _defaultTheme = [
  0xFFFFFFFF, // lt1
  0xFF000000, // dk1
  0xFFE7E6E6, // lt2
  0xFF44546A, // dk2
  0xFF4472C4, 0xFFED7D31, 0xFFA5A5A5, 0xFFFFC000, 0xFF5B9BD5, 0xFF70AD47,
  0xFF0563C1, 0xFF954F72,
];

/// Legacy indexed palette (0-63).
const _indexed = [
  0x000000,
  0xFFFFFF,
  0xFF0000,
  0x00FF00,
  0x0000FF,
  0xFFFF00,
  0xFF00FF,
  0x00FFFF, //
  0x000000,
  0xFFFFFF,
  0xFF0000,
  0x00FF00,
  0x0000FF,
  0xFFFF00,
  0xFF00FF,
  0x00FFFF,
  0x800000,
  0x008000,
  0x000080,
  0x808000,
  0x800080,
  0x008080,
  0xC0C0C0,
  0x808080,
  0x9999FF,
  0x993366,
  0xFFFFCC,
  0xCCFFFF,
  0x660066,
  0xFF8080,
  0x0066CC,
  0xCCCCFF,
  0x000080,
  0xFF00FF,
  0xFFFF00,
  0x00FFFF,
  0x800080,
  0x800000,
  0x008080,
  0x0000FF,
  0x00CCFF,
  0xCCFFFF,
  0xCCFFCC,
  0xFFFF99,
  0x99CCFF,
  0xFF99CC,
  0xCC99FF,
  0xFFCC99,
  0x3366FF,
  0x33CCCC,
  0x99CC00,
  0xFFCC00,
  0xFF9900,
  0xFF6600,
  0x666699,
  0x969696,
  0x003366,
  0x339966,
  0x003300,
  0x333300,
  0x993300,
  0x993366,
  0x333399,
  0x333333,
];

class XlsxColors {
  final List<int> theme;
  XlsxColors(this.theme);

  static XlsxColors parse(XmlDocument? themeDoc) {
    if (themeDoc == null) return XlsxColors(_defaultTheme);
    final scheme = themeDoc.rootElement.descendant('clrScheme');
    if (scheme == null) return XlsxColors(_defaultTheme);
    int? col(String name) {
      final e = scheme.child(name);
      if (e == null) return null;
      final srgb = e.child('srgbClr')?.attr('val');
      if (srgb != null) return parseHexColor(srgb);
      final sys = e.child('sysClr');
      return parseHexColor(sys?.attr('lastClr'));
    }

    // Excel's theme index order swaps dk/lt pairs.
    const order = [
      'lt1', 'dk1', 'lt2', 'dk2', 'accent1', 'accent2', 'accent3', //
      'accent4', 'accent5', 'accent6', 'hlink', 'folHlink',
    ];
    return XlsxColors([
      for (var i = 0; i < order.length; i++) col(order[i]) ?? _defaultTheme[i],
    ]);
  }

  /// Resolves a `<color>`/`<fgColor>` element to ARGB, or null for auto.
  int? resolve(XmlElement? e) {
    if (e == null) return null;
    if (ooxmlBool(e.attr('auto'), ifMissing: false)) return null;
    int? base;
    final rgb = e.attr('rgb');
    final th = parseIntOrNull(e.attr('theme'));
    final idx = parseIntOrNull(e.attr('indexed'));
    if (rgb != null) {
      base = parseHexColor(rgb);
    } else if (th != null) {
      base = th >= 0 && th < theme.length ? theme[th] : null;
    } else if (idx != null) {
      if (idx >= 0 && idx < _indexed.length) base = 0xFF000000 | _indexed[idx];
      // 64 = system foreground, 65 = system background -> auto
    }
    if (base == null) return null;
    final tint = parseDoubleOrNull(e.attr('tint'));
    if (tint == null || tint == 0) return base;
    int ch(int c) => (tint < 0 ? c * (1 + tint) : c + (255 - c) * tint)
        .round()
        .clamp(0, 255);
    final r = ch((base >> 16) & 0xFF),
        g = ch((base >> 8) & 0xFF),
        b = ch(base & 0xFF);
    return 0xFF000000 | (r << 16) | (g << 8) | b;
  }
}

class _Font {
  final bool b, i, u, s;
  final double? sz;
  final int? color;
  final String? name;
  const _Font(this.b, this.i, this.u, this.s, this.sz, this.color, this.name);
}

/// Parsed `styles.xml`: one [XlsxStyle] per cellXfs index.
class XlsxStyles {
  final List<XlsxStyle> xfs = [];

  XlsxStyles(XmlDocument? doc, XlsxColors colors) {
    if (doc == null) return;
    final root = doc.rootElement;
    final numFmts = <int, String>{};
    for (final f
        in root.child('numFmts')?.childrenNamed('numFmt') ??
            const <XmlElement>[]) {
      final id = parseIntOrNull(f.attr('numFmtId'));
      final code = f.attr('formatCode');
      if (id != null && code != null) numFmts[id] = code;
    }
    bool flag(XmlElement font, String n) {
      final e = font.child(n);
      if (e == null) return false;
      if (n == 'u') return (e.attr('val') ?? 'single') != 'none';
      return ooxmlBool(e.attr('val'));
    }

    final fonts = [
      for (final f
          in root.child('fonts')?.childrenNamed('font') ?? const <XmlElement>[])
        _Font(
          flag(f, 'b'),
          flag(f, 'i'),
          flag(f, 'u'),
          flag(f, 'strike'),
          parseDoubleOrNull(f.child('sz')?.attr('val')),
          colors.resolve(f.child('color')),
          f.child('name')?.attr('val'),
        ),
    ];
    final fills = <int?>[
      for (final f
          in root.child('fills')?.childrenNamed('fill') ?? const <XmlElement>[])
        _fill(f, colors),
    ];
    final borders = <bool>[
      for (final b
          in root.child('borders')?.childrenNamed('border') ??
              const <XmlElement>[])
        ['left', 'right', 'top', 'bottom', 'start', 'end'].any((side) {
          final s = b.child(side)?.attr('style');
          return s != null && s != 'none';
        }),
    ];
    for (final xf
        in root.child('cellXfs')?.childrenNamed('xf') ?? const <XmlElement>[]) {
      final numId = parseIntOrNull(xf.attr('numFmtId')) ?? 0;
      final font = _at(fonts, parseIntOrNull(xf.attr('fontId')) ?? 0);
      final fill = _at(fills, parseIntOrNull(xf.attr('fillId')) ?? 0);
      final border =
          _at(borders, parseIntOrNull(xf.attr('borderId')) ?? 0) ?? false;
      final al = xf.child('alignment');
      xfs.add(
        XlsxStyle(
          bold: font?.b ?? false,
          italic: font?.i ?? false,
          underline: font?.u ?? false,
          strike: font?.s ?? false,
          fontSizePt: font?.sz,
          fontColorArgb: font?.color,
          fontFamily: font?.name,
          fillArgb: fill,
          hasBorder: border,
          hAlign: _h(al?.attr('horizontal')),
          vAlign: _v(al?.attr('vertical')),
          wrap: ooxmlBool(al?.attr('wrapText'), ifMissing: false),
          indent: parseIntOrNull(al?.attr('indent')) ?? 0,
          numberFormat: numFmts[numId] ?? builtInFormat(numId),
        ),
      );
    }
  }

  static T? _at<T>(List<T> l, int i) => i >= 0 && i < l.length ? l[i] : null;

  static int? _fill(XmlElement fill, XlsxColors colors) {
    final p = fill.child('patternFill');
    if (p != null) {
      final type =
          p.attr('patternType') ??
          (p.child('fgColor') != null ? 'solid' : 'none');
      if (type == 'none' || type == 'gray125' || type == 'gray0625') {
        return null;
      }
      return colors.resolve(p.child('fgColor')) ??
          colors.resolve(p.child('bgColor'));
    }
    final g = fill.child('gradientFill');
    if (g != null) return colors.resolve(g.descendant('color'));
    return null;
  }

  static XlsxHAlign _h(String? v) => switch (v) {
    'left' => XlsxHAlign.left,
    'center' => XlsxHAlign.center,
    'right' => XlsxHAlign.right,
    'justify' => XlsxHAlign.justify,
    'fill' => XlsxHAlign.fill,
    'centerContinuous' => XlsxHAlign.centerContinuous,
    'distributed' => XlsxHAlign.distributed,
    _ => XlsxHAlign.general,
  };

  static XlsxVAlign _v(String? v) => switch (v) {
    'top' => XlsxVAlign.top,
    'center' => XlsxVAlign.center,
    'justify' => XlsxVAlign.justify,
    'distributed' => XlsxVAlign.distributed,
    _ => XlsxVAlign.bottom,
  };

  XlsxStyle at(int? i) {
    if (i == null || i < 0 || i >= xfs.length) {
      return xfs.isNotEmpty ? xfs.first : XlsxStyle.plain;
    }
    return xfs[i];
  }
}
