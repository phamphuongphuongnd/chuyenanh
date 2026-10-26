import 'dart:math' as math;

import 'package:xml/xml.dart';

import 'xml_utils.dart';

/// Resolves DrawingML colour elements to ARGB ints.
class ColorContext {
  ColorContext({required this.themeColors, required this.clrMap, this.phClr});

  /// Theme colour scheme: dk1, lt1, dk2, lt2, accent1..6, hlink, folHlink -> RGB.
  final Map<String, int> themeColors;

  /// Master `p:clrMap` (bg1 -> lt1 ...), possibly overridden.
  final Map<String, String> clrMap;

  /// Placeholder colour for `schemeClr val="phClr"` inside style references.
  final int? phClr;

  ColorContext withPhClr(int? c) =>
      ColorContext(themeColors: themeColors, clrMap: clrMap, phClr: c);

  static const _colorTags = {
    'srgbClr',
    'schemeClr',
    'sysClr',
    'prstClr',
    'scrgbClr',
    'hslClr',
  };

  /// Finds the first colour child of [container] (e.g. `a:solidFill`).
  int? colorIn(XmlElement? container) {
    if (container == null) return null;
    for (final e in container.childElements) {
      if (_colorTags.contains(e.name.local)) return resolve(e);
    }
    return null;
  }

  int? scheme(String name) {
    if (name == 'phClr') return phClr;
    final mapped = clrMap[name] ?? _defaultMap[name] ?? name;
    final rgb = themeColors[mapped];
    return rgb == null ? null : 0xFF000000 | rgb;
  }

  static const _defaultMap = {
    'bg1': 'lt1',
    'tx1': 'dk1',
    'bg2': 'lt2',
    'tx2': 'dk2',
  };

  /// Resolves a single colour element including its modifiers.
  int? resolve(XmlElement e) {
    int? argb;
    switch (e.name.local) {
      case 'srgbClr':
        argb = parseHex(e.attr('val'));
      case 'schemeClr':
        argb = scheme(e.attr('val') ?? '');
      case 'sysClr':
        argb =
            parseHex(e.attr('lastClr')) ??
            (e.attr('val') == 'window' ? 0xFFFFFFFF : 0xFF000000);
      case 'prstClr':
        final v = presetColors[e.attr('val')];
        argb = v == null ? null : 0xFF000000 | v;
      case 'scrgbClr':
        int ch(String n) =>
            ((e.intAttr(n) ?? 0) / 100000 * 255).round().clamp(0, 255);
        argb = 0xFF000000 | ch('r') << 16 | ch('g') << 8 | ch('b');
      case 'hslClr':
        final h = (e.intAttr('hue') ?? 0) / 60000 / 360;
        final s = (e.intAttr('sat') ?? 0) / 100000;
        final l = (e.intAttr('lum') ?? 0) / 100000;
        argb = 0xFF000000 | _hslToRgb(h, s, l);
    }
    if (argb == null) return null;
    return applyModifiers(argb, e);
  }

  static int? parseHex(String? hex) {
    if (hex == null || hex.length != 6) return null;
    final v = int.tryParse(hex, radix: 16);
    return v == null ? null : 0xFF000000 | v;
  }

  static int applyModifiers(int argb, XmlElement e) {
    var a = ((argb >> 24) & 0xFF) / 255.0;
    var r = ((argb >> 16) & 0xFF) / 255.0;
    var g = ((argb >> 8) & 0xFF) / 255.0;
    var b = (argb & 0xFF) / 255.0;
    for (final m in e.childElements) {
      final val = (m.intAttr('val') ?? 0) / 100000.0;
      switch (m.name.local) {
        case 'alpha':
          a = val;
        case 'alphaMod':
          a *= val;
        case 'alphaOff':
          a += val;
        case 'tint':
          r = 1 - (1 - r) * val;
          g = 1 - (1 - g) * val;
          b = 1 - (1 - b) * val;
        case 'shade':
          r *= val;
          g *= val;
          b *= val;
        case 'inv':
          r = 1 - r;
          g = 1 - g;
          b = 1 - b;
        case 'gray':
          final y = 0.3 * r + 0.59 * g + 0.11 * b;
          r = g = b = y;
        case 'comp':
        case 'lumMod':
        case 'lumOff':
        case 'satMod':
        case 'satOff':
        case 'hueMod':
        case 'hueOff':
          var (h, s, l) = _rgbToHsl(r, g, b);
          switch (m.name.local) {
            case 'lumMod':
              l *= val;
            case 'lumOff':
              l += val;
            case 'satMod':
              s *= val;
            case 'satOff':
              s += val;
            case 'hueMod':
              h = (h * val) % 1.0;
            case 'hueOff':
              h = (h + (m.intAttr('val') ?? 0) / 60000 / 360) % 1.0;
            case 'comp':
              h = (h + 0.5) % 1.0;
          }
          (r, g, b) = _hsl(h, s.clamp(0, 1), l.clamp(0, 1));
      }
      r = r.clamp(0, 1);
      g = g.clamp(0, 1);
      b = b.clamp(0, 1);
      a = a.clamp(0, 1);
    }
    int c(double v) => (v * 255).round();
    return c(a) << 24 | c(r) << 16 | c(g) << 8 | c(b);
  }

  static (double, double, double) _rgbToHsl(double r, double g, double b) {
    final mx = math.max(r, math.max(g, b));
    final mn = math.min(r, math.min(g, b));
    final l = (mx + mn) / 2;
    if (mx == mn) return (0, 0, l);
    final d = mx - mn;
    final s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
    double h;
    if (mx == r) {
      h = (g - b) / d + (g < b ? 6 : 0);
    } else if (mx == g) {
      h = (b - r) / d + 2;
    } else {
      h = (r - g) / d + 4;
    }
    return (h / 6, s, l);
  }

  static int _hslToRgb(double h, double s, double l) {
    final (r, g, b) = _hsl(h, s, l);
    int c(double v) => (v.clamp(0, 1) * 255).round();
    return c(r) << 16 | c(g) << 8 | c(b);
  }

  static (double, double, double) _hsl(double h, double s, double l) {
    double r, g, b;
    if (s == 0) {
      r = g = b = l;
    } else {
      double hue2rgb(double p, double q, double t) {
        if (t < 0) t += 1;
        if (t > 1) t -= 1;
        if (t < 1 / 6) return p + (q - p) * 6 * t;
        if (t < 1 / 2) return q;
        if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
        return p;
      }

      final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
      final p = 2 * l - q;
      r = hue2rgb(p, q, h + 1 / 3);
      g = hue2rgb(p, q, h);
      b = hue2rgb(p, q, h - 1 / 3);
    }
    return (r, g, b);
  }
}

/// Subset of DrawingML preset colours (ST_PresetColorVal).
const presetColors = <String, int>{
  'black': 0x000000,
  'white': 0xFFFFFF,
  'red': 0xFF0000,
  'green': 0x008000,
  'lime': 0x00FF00,
  'blue': 0x0000FF,
  'yellow': 0xFFFF00,
  'cyan': 0x00FFFF,
  'aqua': 0x00FFFF,
  'magenta': 0xFF00FF,
  'fuchsia': 0xFF00FF,
  'gray': 0x808080,
  'grey': 0x808080,
  'silver': 0xC0C0C0,
  'maroon': 0x800000,
  'olive': 0x808000,
  'navy': 0x000080,
  'purple': 0x800080,
  'teal': 0x008080,
  'orange': 0xFFA500,
  'brown': 0xA52A2A,
  'pink': 0xFFC0CB,
  'gold': 0xFFD700,
  'darkGray': 0xA9A9A9,
  'dkGray': 0xA9A9A9,
  'lightGray': 0xD3D3D3,
  'ltGray': 0xD3D3D3,
  'darkBlue': 0x00008B,
  'dkBlue': 0x00008B,
  'darkRed': 0x8B0000,
  'dkRed': 0x8B0000,
  'darkGreen': 0x006400,
  'dkGreen': 0x006400,
  'lightBlue': 0xADD8E6,
  'ltBlue': 0xADD8E6,
  'lightGreen': 0x90EE90,
  'ltGreen': 0x90EE90,
  'indigo': 0x4B0082,
  'violet': 0xEE82EE,
  'beige': 0xF5F5DC,
  'tan': 0xD2B48C,
  'coral': 0xFF7F50,
  'salmon': 0xFA8072,
  'crimson': 0xDC143C,
  'turquoise': 0x40E0D0,
  'skyBlue': 0x87CEEB,
};
