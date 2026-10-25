// Excel number-format rendering (subset): General, digit placeholders,
// grouping/scaling commas, percent, scientific, simple fractions, sections,
// colours/locales (ignored), literals, dates/times incl. elapsed time.
//
// Output uses "." as decimal and "," as grouping separator (en-US style),
// and English month/day names.

import 'dart:math' as math;

/// Built-in number formats. 14 and 22 use day-first order (d/m/yyyy), which
/// is what Excel shows on Vietnamese / most non-US systems.
const Map<int, String> builtInNumberFormats = {
  0: 'General',
  1: '0',
  2: '0.00',
  3: '#,##0',
  4: '#,##0.00',
  5: r'"$"#,##0_);\("$"#,##0\)',
  6: r'"$"#,##0_);[Red]\("$"#,##0\)',
  7: r'"$"#,##0.00_);\("$"#,##0.00\)',
  8: r'"$"#,##0.00_);[Red]\("$"#,##0.00\)',
  9: '0%',
  10: '0.00%',
  11: '0.00E+00',
  12: '# ?/?',
  13: '# ??/??',
  14: 'd/m/yyyy',
  15: 'd-mmm-yy',
  16: 'd-mmm',
  17: 'mmm-yy',
  18: 'h:mm AM/PM',
  19: 'h:mm:ss AM/PM',
  20: 'h:mm',
  21: 'h:mm:ss',
  22: 'd/m/yyyy h:mm',
  37: '#,##0 ;(#,##0)',
  38: '#,##0 ;[Red](#,##0)',
  39: '#,##0.00;(#,##0.00)',
  40: '#,##0.00;[Red](#,##0.00)',
  41: r'_(* #,##0_);_(* \(#,##0\);_(* "-"_);_(@_)',
  42: r'_("$"* #,##0_);_("$"* \(#,##0\);_("$"* "-"_);_(@_)',
  43: r'_(* #,##0.00_);_(* \(#,##0.00\);_(* "-"??_);_(@_)',
  44: r'_("$"* #,##0.00_);_("$"* \(#,##0.00\);_("$"* "-"??_);_(@_)',
  45: 'mm:ss',
  46: '[h]:mm:ss',
  47: 'mm:ss.0',
  48: '##0.0E+0',
  49: '@',
};

/// Format code for a built-in id (East-Asian date ids map to yyyy-mm-dd).
String builtInFormat(int id) {
  final f = builtInNumberFormats[id];
  if (f != null) return f;
  if ((id >= 27 && id <= 31) || (id >= 50 && id <= 58)) return 'yyyy-mm-dd';
  if (id >= 32 && id <= 35) return 'h:mm:ss';
  return 'General';
}

/// Converts an Excel serial date to a UTC [DateTime]. In the 1900 system the
/// fictitious 29 Feb 1900 (serial 60) maps to 28 Feb 1900.
DateTime excelSerialToDate(double serial, {bool date1904 = false}) {
  final days = serial.floor();
  final ms = ((serial - days) * 86400000).round();
  DateTime base;
  if (date1904) {
    base = DateTime.utc(1904, 1, 1);
  } else if (days < 60) {
    base = DateTime.utc(1899, 12, 31);
  } else if (days == 60) {
    return DateTime.utc(1900, 2, 28).add(Duration(milliseconds: ms));
  } else {
    base = DateTime.utc(1899, 12, 30);
  }
  return base.add(Duration(days: days, milliseconds: ms));
}

/// Inverse of [excelSerialToDate].
double dateToExcelSerial(DateTime d, {bool date1904 = false}) {
  final u = DateTime.utc(
    d.year,
    d.month,
    d.day,
    d.hour,
    d.minute,
    d.second,
    d.millisecond,
  );
  final base = date1904 ? DateTime.utc(1904, 1, 1) : DateTime.utc(1899, 12, 30);
  var v = u.difference(base).inMilliseconds / 86400000;
  if (!date1904 && v < 61) v -= 1;
  return v;
}

// ---------------------------------------------------------------- sections

List<String> _splitSections(String code) {
  final out = <String>[];
  final b = StringBuffer();
  var inQuote = false, inBracket = false;
  for (var i = 0; i < code.length; i++) {
    final c = code[i];
    if (inQuote) {
      b.write(c);
      if (c == '"') inQuote = false;
      continue;
    }
    if (inBracket) {
      b.write(c);
      if (c == ']') inBracket = false;
      continue;
    }
    if (c == '\\' || c == '_' || c == '*') {
      b.write(c);
      if (i + 1 < code.length) b.write(code[++i]);
      continue;
    }
    if (c == '"') inQuote = true;
    if (c == '[') inBracket = true;
    if (c == ';') {
      out.add(b.toString());
      b.clear();
      continue;
    }
    b.write(c);
  }
  out.add(b.toString());
  return out;
}

enum _K { lit, digit, dot, comma, percent, exp, slash, general, at, date }

class _Tok {
  final _K k;
  final String s;
  const _Tok(this.k, this.s);
}

class _Section {
  final List<_Tok> toks;
  final bool isDate;
  final String? condOp;
  final double? condVal;
  _Section(this.toks, this.isDate, this.condOp, this.condVal);

  bool get isTextOnly => toks.any((t) => t.k == _K.at);
}

final _condRe = RegExp(r'^\[(<=|>=|<>|<|>|=)\s*(-?[0-9.]+)\]$');

_Section _parseSection(String sec) {
  // Pass 1: decide whether this is a date/time section.
  var isDate = false;
  {
    var inQ = false;
    for (var i = 0; i < sec.length; i++) {
      final c = sec[i];
      if (inQ) {
        if (c == '"') inQ = false;
        continue;
      }
      if (c == '"') {
        inQ = true;
      } else if (c == '\\' || c == '_' || c == '*') {
        i++;
      } else if (c == '[') {
        final end = sec.indexOf(']', i);
        if (end < 0) break;
        final inner = sec.substring(i + 1, end).toLowerCase();
        if (RegExp(r'^(h+|m+|s+)$').hasMatch(inner)) isDate = true;
        i = end;
      } else if ('yYmMdDhHsS'.contains(c)) {
        isDate = true;
      } else if (c == 'G' || c == 'g') {
        if (sec.substring(i).toLowerCase().startsWith('general')) {
          i += 6;
        }
      } else if (c == 'E' || c == 'e') {
        // exponent marker, not a date letter
      }
    }
  }

  final toks = <_Tok>[];
  String? condOp;
  double? condVal;
  for (var i = 0; i < sec.length; i++) {
    final c = sec[i];
    if (c == '"') {
      final end = sec.indexOf('"', i + 1);
      final e = end < 0 ? sec.length : end;
      toks.add(_Tok(_K.lit, sec.substring(i + 1, e)));
      i = e;
    } else if (c == '\\') {
      if (i + 1 < sec.length) toks.add(_Tok(_K.lit, sec[++i]));
    } else if (c == '_') {
      i++;
      toks.add(const _Tok(_K.lit, ' '));
    } else if (c == '*') {
      i++; // fill character: ignored
    } else if (c == '[') {
      final end = sec.indexOf(']', i);
      final e = end < 0 ? sec.length - 1 : end;
      final full = sec.substring(i, e + 1);
      final inner = sec.substring(i + 1, e);
      final cm = _condRe.firstMatch(full);
      if (cm != null) {
        condOp = cm.group(1);
        condVal = double.tryParse(cm.group(2)!);
      } else if (inner.startsWith(r'$')) {
        final dash = inner.indexOf('-');
        final sym = inner.substring(1, dash < 0 ? inner.length : dash);
        if (sym.isNotEmpty) toks.add(_Tok(_K.lit, sym));
      } else if (RegExp(
        r'^(h+|m+|s+)$',
        caseSensitive: false,
      ).hasMatch(inner)) {
        toks.add(_Tok(_K.date, '[${inner.toLowerCase()}]'));
      }
      // colours and other modifiers are ignored
      i = e;
    } else if (sec.substring(i).toLowerCase().startsWith('general')) {
      toks.add(const _Tok(_K.general, 'General'));
      i += 6;
    } else if (isDate) {
      final lower = c.toLowerCase();
      if (sec.substring(i).toUpperCase().startsWith('AM/PM')) {
        toks.add(_Tok(_K.date, sec.substring(i, i + 5)));
        i += 4;
      } else if (sec.substring(i).toUpperCase().startsWith('A/P')) {
        toks.add(_Tok(_K.date, sec.substring(i, i + 3)));
        i += 2;
      } else if ('ymdhs'.contains(lower)) {
        var j = i;
        while (j < sec.length && sec[j].toLowerCase() == lower) {
          j++;
        }
        toks.add(_Tok(_K.date, sec.substring(i, j).toLowerCase()));
        i = j - 1;
      } else if (c == '.' &&
          i + 1 < sec.length &&
          sec[i + 1] == '0' &&
          toks.isNotEmpty &&
          toks.last.k == _K.date &&
          toks.last.s.contains('s')) {
        var j = i + 1;
        while (j < sec.length && sec[j] == '0') {
          j++;
        }
        toks.add(_Tok(_K.date, sec.substring(i, j)));
        i = j - 1;
      } else if (c == '@') {
        toks.add(const _Tok(_K.at, '@'));
      } else {
        toks.add(_Tok(_K.lit, c));
      }
    } else {
      switch (c) {
        case '0' || '#' || '?':
          toks.add(_Tok(_K.digit, c));
        case '.':
          toks.add(const _Tok(_K.dot, '.'));
        case ',':
          toks.add(const _Tok(_K.comma, ','));
        case '%':
          toks.add(const _Tok(_K.percent, '%'));
        case '/':
          toks.add(const _Tok(_K.slash, '/'));
        case '@':
          toks.add(const _Tok(_K.at, '@'));
        case 'E' || 'e':
          if (i + 1 < sec.length && (sec[i + 1] == '+' || sec[i + 1] == '-')) {
            toks.add(_Tok(_K.exp, 'E${sec[i + 1]}'));
            i++;
          } else {
            toks.add(_Tok(_K.lit, c));
          }
        default:
          if (RegExp(r'[1-9]').hasMatch(c) &&
              toks.isNotEmpty &&
              toks.any((t) => t.k == _K.slash)) {
            toks.add(_Tok(_K.digit, c)); // fixed denominator digit
          } else {
            toks.add(_Tok(_K.lit, c));
          }
      }
    }
  }
  return _Section(toks, isDate, condOp, condVal);
}

final _cache = <String, List<_Section>>{};

List<_Section> _sections(String code) =>
    _cache[code] ??= _splitSections(code).map(_parseSection).toList();

/// True when [code] formats numbers as dates/times.
bool isDateFormat(String code) {
  final s = _sections(code);
  return s.isNotEmpty && s.first.isDate;
}

bool _cond(String op, double a, double b) => switch (op) {
  '<' => a < b,
  '<=' => a <= b,
  '>' => a > b,
  '>=' => a >= b,
  '=' => a == b,
  '<>' => a != b,
  _ => false,
};

/// Formats a numeric cell value with Excel format [code].
String formatNumber(double v, String code, {bool date1904 = false}) {
  if (v.isNaN || v.isInfinite) return '#NUM!';
  final secs = _sections(code.isEmpty ? 'General' : code);
  final numSecs = secs.where((s) => !s.isTextOnly).toList();
  if (numSecs.isEmpty) return _general(v);

  _Section sec;
  var value = v;
  var signHandled = false;
  if (numSecs.any((s) => s.condOp != null)) {
    sec = numSecs.firstWhere(
      (s) => s.condOp != null && _cond(s.condOp!, v, s.condVal ?? 0),
      orElse: () => numSecs.lastWhere(
        (s) => s.condOp == null,
        orElse: () => numSecs.last,
      ),
    );
    if (sec != numSecs.first && v < 0) {
      value = -v;
      signHandled = true;
    }
  } else if (numSecs.length == 1 || v > 0) {
    sec = numSecs[0];
  } else if (v < 0) {
    sec = numSecs[1];
    value = -v;
    signHandled = true;
  } else {
    sec = numSecs.length >= 3 ? numSecs[2] : numSecs[0];
  }
  if (sec.toks.isEmpty) return '';

  if (sec.isDate) {
    if (value < 0) return _general(v);
    return _formatDate(value, sec.toks, date1904);
  }
  return _formatNum(value, sec.toks, signHandled);
}

/// Formats a text cell value; only an `@` text section changes it.
String formatText(String s, String code) {
  final secs = _sections(code);
  _Section? sec;
  if (secs.length >= 4) {
    sec = secs[3];
  } else if (secs.length == 1 && secs[0].isTextOnly) {
    sec = secs[0];
  } else {
    sec = secs.where((x) => x.isTextOnly).firstOrNull;
  }
  if (sec == null) return s;
  final b = StringBuffer();
  for (final t in sec.toks) {
    if (t.k == _K.at) {
      b.write(s);
    } else if (t.k == _K.lit) {
      b.write(t.s);
    }
  }
  return b.toString();
}

// ----------------------------------------------------------------- numbers

double _round15(double v) =>
    v == 0 ? 0 : double.parse(v.toStringAsPrecision(15));

String _stripZeros(String s) {
  if (!s.contains('.')) return s;
  var r = s.replaceFirst(RegExp(r'0+$'), '');
  if (r.endsWith('.')) r = r.substring(0, r.length - 1);
  return r;
}

String _general(double v) {
  if (v == 0) return '0';
  final neg = v < 0;
  final a = _round15(v.abs());
  String body;
  if (a >= 1e11 || a < 1e-9) {
    var exp = (math.log(a) / math.ln10).floor();
    var mant = a / math.pow(10.0, exp);
    if (double.parse(mant.toStringAsFixed(5)) >= 10) {
      exp++;
      mant /= 10;
    } else if (mant < 1) {
      exp--;
      mant *= 10;
    }
    final m = _stripZeros(mant.toStringAsFixed(5));
    final e = exp.abs().toString().padLeft(2, '0');
    body = '${m}E${exp < 0 ? '-' : '+'}$e';
  } else if (a == a.roundToDouble()) {
    body = a.toStringAsFixed(0);
  } else {
    final intLen = a.floor().toString().length;
    final dec = math.max(0, 10 - intLen);
    body = _stripZeros(a.toStringAsFixed(dec));
  }
  return neg && body != '0' ? '-$body' : body;
}

String _formatNum(double value, List<_Tok> toks, bool signHandled) {
  final neg = value < 0 && !signHandled;
  var a = value.abs();

  if (toks.any((t) => t.k == _K.general)) {
    final b = StringBuffer();
    for (final t in toks) {
      if (t.k == _K.general) b.write(_general(a));
      if (t.k == _K.lit) b.write(t.s);
    }
    final s = b.toString();
    return neg ? '-$s' : s;
  }

  final percents = toks.where((t) => t.k == _K.percent).length;
  for (var i = 0; i < percents; i++) {
    a *= 100;
  }

  final firstDigit = toks.indexWhere((t) => t.k == _K.digit);
  if (firstDigit < 0) {
    // Only literals (e.g. `"-"` in accounting zero section).
    final s = toks
        .where((t) => t.k == _K.lit || t.k == _K.percent)
        .map((t) => t.s)
        .join();
    return neg ? '-$s' : s;
  }

  String out;
  if (toks.any((t) => t.k == _K.exp)) {
    out = _scientific(a, toks);
  } else if (toks.any((t) => t.k == _K.slash)) {
    out = _fraction(a, toks);
  } else {
    out = _fixed(a, toks);
  }
  if (neg && RegExp(r'[1-9]').hasMatch(out)) return '-$out';
  return out;
}

String _fixed(double a, List<_Tok> toks) {
  final dotIdx = toks.indexWhere((t) => t.k == _K.dot);
  final lastDigit = toks.lastIndexWhere((t) => t.k == _K.digit);
  final intEnd = dotIdx < 0 ? lastDigit + 1 : dotIdx;
  final intPh = <String>[];
  final decPh = <String>[];
  var grouping = false;
  var scale = 0;
  int? lastIntDigit;
  for (var i = 0; i < toks.length; i++) {
    final t = toks[i];
    if (t.k == _K.digit) {
      if (i < intEnd) {
        intPh.add(t.s);
        lastIntDigit = i;
      } else {
        decPh.add(t.s);
      }
    }
  }
  // Commas: between integer placeholders => grouping; trailing => scaling.
  for (var i = 0; i < toks.length; i++) {
    if (toks[i].k != _K.comma) continue;
    final digitBefore = toks.take(i).any((t) => t.k == _K.digit);
    final digitAfterInInt = toks
        .skip(i + 1)
        .take(math.max(0, intEnd - i - 1))
        .any((t) => t.k == _K.digit);
    if (digitBefore && digitAfterInInt) {
      grouping = true;
    } else if (digitBefore && lastIntDigit != null && i > lastIntDigit) {
      scale++;
    }
  }
  for (var i = 0; i < scale; i++) {
    a /= 1000;
  }

  final fixedStr = _round15(a).toStringAsFixed(decPh.length);
  final parts = fixedStr.split('.');
  var intDigits = parts[0];
  final decDigits = parts.length > 1 ? parts[1] : '';

  // Integer part.
  if (intDigits == '0') intDigits = '';
  final ib = StringBuffer();
  final padCount = intPh.length - intDigits.length;
  if (padCount > 0) {
    for (var i = 0; i < padCount; i++) {
      final ph = intPh[i];
      if (ph == '0') ib.write('0');
      if (ph == '?') ib.write(' ');
    }
  }
  var intStr = ib.toString() + intDigits;
  if (grouping) {
    final m = RegExp(r'^(\s*)(\d+)$').firstMatch(intStr);
    if (m != null) {
      final d = m.group(2)!;
      final g = StringBuffer();
      for (var i = 0; i < d.length; i++) {
        if (i > 0 && (d.length - i) % 3 == 0) g.write(',');
        g.write(d[i]);
      }
      intStr = m.group(1)! + g.toString();
    }
  }

  // Decimal part: trim optional trailing digits.
  final dec = decDigits.split('');
  for (var i = dec.length - 1; i >= 0; i--) {
    if (dec[i] != '0') break;
    if (decPh[i] == '#') {
      dec[i] = '';
    } else if (decPh[i] == '?') {
      dec[i] = ' ';
    } else {
      break;
    }
  }
  final decStr = dec.join();

  final b = StringBuffer();
  var intWritten = false, decWritten = false;
  for (var i = 0; i < toks.length; i++) {
    final t = toks[i];
    switch (t.k) {
      case _K.digit:
        if (i < intEnd) {
          if (!intWritten) b.write(intStr);
          intWritten = true;
        } else {
          if (!decWritten) b.write(decStr);
          decWritten = true;
        }
      case _K.dot:
        if (!intWritten) {
          b.write(intStr);
          intWritten = true;
        }
        b.write('.');
      case _K.lit || _K.percent:
        b.write(t.s);
      default:
        break;
    }
  }
  return b.toString();
}

(String, String) _prefixSuffix(List<_Tok> toks) {
  final first = toks.indexWhere((t) => t.k != _K.lit);
  final last = toks.lastIndexWhere((t) => t.k != _K.lit);
  String lit(Iterable<_Tok> ts) => ts
      .where((t) => t.k == _K.lit || t.k == _K.percent)
      .map((t) => t.s)
      .join();
  return (lit(toks.take(first)), lit(toks.skip(last + 1)));
}

String _scientific(double a, List<_Tok> toks) {
  final ei = toks.indexWhere((t) => t.k == _K.exp);
  final mant = toks.take(ei).toList();
  final dot = mant.indexWhere((t) => t.k == _K.dot);
  final intPh = (dot < 0 ? mant : mant.take(dot))
      .where((t) => t.k == _K.digit)
      .length;
  final decPh = dot < 0
      ? 0
      : mant.skip(dot + 1).where((t) => t.k == _K.digit).length;
  final expDigits = toks.skip(ei + 1).where((t) => t.k == _K.digit).length;
  final plus = toks[ei].s == 'E+';

  var exp = 0;
  var m = a;
  if (a != 0) {
    exp = (math.log(a) / math.ln10).floor();
    if (intPh > 1 && toks.take(ei).any((t) => t.s == '#')) {
      exp = (exp / intPh).floor() * intPh; // engineering
    }
    m = a / math.pow(10.0, exp);
    if (double.parse(m.toStringAsFixed(decPh)) >=
        math.pow(10, math.max(1, intPh == 1 ? 1 : intPh))) {
      exp += intPh > 1 ? intPh : 1;
      m = a / math.pow(10.0, exp);
    }
  }
  final ms = _round15(m).toStringAsFixed(decPh);
  final es = exp.abs().toString().padLeft(math.max(1, expDigits), '0');
  final sign = exp < 0 ? '-' : (plus ? '+' : '');
  final (pre, suf) = _prefixSuffix(toks);
  return '$pre${ms}E$sign$es$suf';
}

String _fraction(double a, List<_Tok> toks) {
  final si = toks.indexWhere((t) => t.k == _K.slash);
  final before = toks.take(si).toList();
  final after = toks.skip(si + 1).toList();
  // Integer part exists when digit placeholders are separated from the
  // numerator by a literal (usually a space).
  final numStart = before.lastIndexWhere((t) => t.k != _K.digit) + 1;
  final hasLitGap =
      before.take(numStart).any((t) => t.k == _K.lit) &&
      before.take(numStart).any((t) => t.k == _K.digit);
  final denTok = after.where((t) => t.k == _K.digit).map((t) => t.s).join();
  final fixedDen = int.tryParse(denTok);

  var whole = 0;
  var frac = a;
  if (hasLitGap) {
    whole = a.floor();
    frac = a - whole;
  }
  int num, den;
  if (fixedDen != null && fixedDen > 0) {
    den = fixedDen;
    num = (frac * den).round();
  } else {
    final maxDen = math.min(9999, math.pow(10, denTok.length).toInt() - 1);
    var bestN = 0, bestD = 1;
    var bestErr = double.infinity;
    for (var d = 1; d <= maxDen; d++) {
      final n = (frac * d).round();
      final err = (frac - n / d).abs();
      if (err < bestErr - 1e-12) {
        bestErr = err;
        bestN = n;
        bestD = d;
      }
    }
    num = bestN;
    den = bestD;
  }
  if (hasLitGap && num == den) {
    whole++;
    num = 0;
  }
  final (pre, suf) = _prefixSuffix(toks);
  final parts = <String>[];
  if (hasLitGap && (whole != 0 || num == 0)) parts.add('$whole');
  if (num != 0 || !hasLitGap) parts.add('$num/$den');
  return '$pre${parts.join(' ')}$suf'.trim();
}

// ------------------------------------------------------------------- dates

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', //
  'August', 'September', 'October', 'November', 'December',
];
const _days = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String _formatDate(double v, List<_Tok> toks, bool date1904) {
  final subDigits = toks
      .where((t) => t.k == _K.date && t.s.startsWith('.'))
      .fold<int>(0, (m, t) => math.max(m, t.s.length - 1));
  var totalMs = (v * 86400000).round();
  if (subDigits == 0) {
    totalMs = (totalMs / 1000).round() * 1000;
  } else {
    final unit = math.pow(10, 3 - math.min(3, subDigits)).toInt();
    totalMs = (totalMs / unit).round() * unit;
  }
  final dayCount = totalMs ~/ 86400000;
  final msOfDay = totalMs - dayCount * 86400000;
  final date = excelSerialToDate(dayCount.toDouble(), date1904: date1904);
  final hour = msOfDay ~/ 3600000;
  final minute = (msOfDay ~/ 60000) % 60;
  final second = (msOfDay ~/ 1000) % 60;
  final millis = msOfDay % 1000;
  final ampm = toks.any(
    (t) =>
        t.k == _K.date &&
        (t.s.toUpperCase() == 'AM/PM' || t.s.toUpperCase() == 'A/P'),
  );

  // Resolve month/minute ambiguity.
  final dateIdx = [
    for (var i = 0; i < toks.length; i++)
      if (toks[i].k == _K.date) i,
  ];
  bool isMinute(int pos) {
    final k = dateIdx.indexOf(pos);
    if (k > 0) {
      final prev = toks[dateIdx[k - 1]].s;
      if (prev.startsWith('h') || prev == '[h]' || prev.startsWith('[h')) {
        return true;
      }
    }
    if (k >= 0 && k + 1 < dateIdx.length) {
      final next = toks[dateIdx[k + 1]].s;
      if (next.startsWith('s') || next.startsWith('[s')) return true;
    }
    return false;
  }

  String two(int n) => n.toString().padLeft(2, '0');
  final b = StringBuffer();
  for (var i = 0; i < toks.length; i++) {
    final t = toks[i];
    if (t.k == _K.lit) {
      b.write(t.s);
      continue;
    }
    if (t.k != _K.date) continue;
    final s = t.s;
    if (s.startsWith('[')) {
      final inner = s.substring(1, s.length - 1);
      final n = switch (inner[0]) {
        'h' => totalMs ~/ 3600000,
        'm' => totalMs ~/ 60000,
        _ => totalMs ~/ 1000,
      };
      b.write(n.toString().padLeft(inner.length, '0'));
    } else if (s.startsWith('.')) {
      final digits = s.length - 1;
      b.write('.');
      b.write(
        millis.toString().padLeft(3, '0').substring(0, math.min(3, digits)),
      );
    } else if (s.toUpperCase() == 'AM/PM') {
      b.write(hour < 12 ? 'AM' : 'PM');
    } else if (s.toUpperCase() == 'A/P') {
      final up = s[0] == 'A';
      final r = hour < 12 ? 'a' : 'p';
      b.write(up ? r.toUpperCase() : r);
    } else {
      switch (s[0]) {
        case 'y':
          b.write(s.length <= 2 ? two(date.year % 100) : date.year.toString());
        case 'm':
          if (s.length <= 2 && isMinute(i)) {
            b.write(s.length == 1 ? '$minute' : two(minute));
          } else {
            b.write(switch (s.length) {
              1 => '${date.month}',
              2 => two(date.month),
              3 => _months[date.month - 1].substring(0, 3),
              5 => _months[date.month - 1][0],
              _ => _months[date.month - 1],
            });
          }
        case 'd':
          b.write(switch (s.length) {
            1 => '${date.day}',
            2 => two(date.day),
            3 => _days[date.weekday - 1].substring(0, 3),
            _ => _days[date.weekday - 1],
          });
        case 'h':
          var h = hour;
          if (ampm) {
            h = hour % 12;
            if (h == 0) h = 12;
          }
          b.write(s.length == 1 ? '$h' : two(h));
        case 's':
          b.write(s.length == 1 ? '$second' : two(second));
      }
    }
  }
  return b.toString();
}
