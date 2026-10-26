import 'package:xml/xml.dart';

import '../common.dart';
import 'docx_styles.dart';

class _Level {
  final int start;
  final String fmt;
  final String text;
  final bool isLgl;
  final ParaProps pPr;
  const _Level(this.start, this.fmt, this.text, this.isLgl, this.pPr);

  static _Level parse(XmlElement lvl) => _Level(
    parseIntOrNull(lvl.childVal('start')) ?? 1,
    lvl.childVal('numFmt') ?? 'decimal',
    lvl.childVal('lvlText') ?? '',
    lvl.child('isLgl') != null,
    ParaProps.parse(lvl.child('pPr')),
  );

  _Level withStart(int s) => _Level(s, fmt, text, isLgl, pPr);
}

class _Num {
  final int abstractId;
  final Map<int, _Level> overrides;
  const _Num(this.abstractId, this.overrides);
}

/// Resolves `numbering.xml` and produces list labels with running counters.
class DocxNumbering {
  final Map<int, Map<int, _Level>> _abstract = {};
  final Map<int, _Num> _nums = {};
  final Map<int, List<int?>> _counters = {};

  DocxNumbering(XmlDocument? doc) {
    if (doc == null) return;
    final root = doc.rootElement;
    for (final a in root.childrenNamed('abstractNum')) {
      final id = parseIntOrNull(a.attr('abstractNumId'));
      if (id == null) continue;
      final levels = <int, _Level>{};
      for (final l in a.childrenNamed('lvl')) {
        final ilvl = parseIntOrNull(l.attr('ilvl')) ?? 0;
        levels[ilvl] = _Level.parse(l);
      }
      _abstract[id] = levels;
    }
    for (final n in root.childrenNamed('num')) {
      final id = parseIntOrNull(n.attr('numId'));
      final aid = parseIntOrNull(n.childVal('abstractNumId'));
      if (id == null || aid == null) continue;
      final ov = <int, _Level>{};
      for (final o in n.childrenNamed('lvlOverride')) {
        final ilvl = parseIntOrNull(o.attr('ilvl')) ?? 0;
        final lvl = o.child('lvl');
        final base = lvl != null
            ? _Level.parse(lvl)
            : _abstract[aid]?[ilvl] ??
                  const _Level(1, 'decimal', '', false, ParaProps.empty);
        final so = parseIntOrNull(o.childVal('startOverride'));
        ov[ilvl] = so == null ? base : base.withStart(so);
      }
      _nums[id] = _Num(aid, ov);
    }
  }

  _Level? _level(int numId, int ilvl) {
    final n = _nums[numId];
    if (n == null) return null;
    return n.overrides[ilvl] ?? _abstract[n.abstractId]?[ilvl];
  }

  /// Paragraph properties contributed by the numbering level (indents).
  ParaProps levelProps(int numId, int ilvl) =>
      _level(numId, ilvl)?.pPr ?? ParaProps.empty;

  bool exists(int numId) => _nums.containsKey(numId);

  /// Advances the counter for ([numId], [ilvl]) and returns
  /// (label, ordered). Returns null when the list is undefined.
  (String?, bool)? next(int numId, int ilvl) {
    final lvl = _level(numId, ilvl);
    if (lvl == null) return null;
    final c = _counters.putIfAbsent(numId, () => List<int?>.filled(9, null));
    final i = ilvl.clamp(0, 8);
    c[i] = c[i] == null ? lvl.start : c[i]! + 1;
    for (var k = i + 1; k < 9; k++) {
      c[k] = null;
    }
    final ordered = lvl.fmt != 'bullet' && lvl.fmt != 'none';
    if (lvl.fmt == 'bullet') {
      final t = _bulletText(lvl.text);
      return (t.isEmpty ? null : t, false);
    }
    if (lvl.fmt == 'none' && !lvl.text.contains('%')) {
      return (lvl.text.isEmpty ? null : lvl.text, ordered);
    }
    final label = lvl.text.replaceAllMapped(RegExp(r'%([1-9])'), (m) {
      final k = int.parse(m.group(1)!) - 1;
      final kl = _level(numId, k);
      final value = c[k] ?? kl?.start ?? 1;
      final fmt = (lvl.isLgl ? 'decimal' : kl?.fmt) ?? 'decimal';
      return formatListNumber(value, fmt);
    });
    return (label.isEmpty ? null : label, ordered);
  }
}

String _bulletText(String t) {
  if (t.isEmpty) return '•';
  final b = StringBuffer();
  for (final r in t.runes) {
    if (r >= 0xF000 && r <= 0xF0FF) {
      b.write(switch (r) {
        0xF0A7 => '▪',
        0xF0D8 => '➢',
        0xF076 => '❖',
        0xF0FC => '✓',
        0xF06F => 'o',
        _ => '•',
      });
    } else {
      b.writeCharCode(r);
    }
  }
  return b.toString();
}

String formatListNumber(int n, String fmt) {
  switch (fmt) {
    case 'decimalZero':
      return n < 10 ? '0$n' : '$n';
    case 'upperRoman':
      return _roman(n);
    case 'lowerRoman':
      return _roman(n).toLowerCase();
    case 'upperLetter':
      return _letters(n);
    case 'lowerLetter':
      return _letters(n).toLowerCase();
    case 'none':
      return '';
    default:
      return '$n';
  }
}

String _roman(int n) {
  if (n <= 0 || n >= 4000) return '$n';
  const vals = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
  const syms = [
    'M',
    'CM',
    'D',
    'CD',
    'C',
    'XC',
    'L',
    'XL',
    'X',
    'IX',
    'V',
    'IV',
    'I',
  ];
  final b = StringBuffer();
  var x = n;
  for (var i = 0; i < vals.length; i++) {
    while (x >= vals[i]) {
      b.write(syms[i]);
      x -= vals[i];
    }
  }
  return b.toString();
}

/// Word style: A..Z, then AA..ZZ, AAA...
String _letters(int n) {
  if (n <= 0) return '$n';
  final letter = String.fromCharCode(0x41 + (n - 1) % 26);
  return letter * ((n - 1) ~/ 26 + 1);
}
