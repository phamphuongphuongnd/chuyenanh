/// Script-aware helpers for joining extracted text.
library;

/// Scripts written without spaces between words: CJK ideographs, kana,
/// CJK punctuation, full-width forms, Thai, Lao, Khmer, Myanmar.
bool isNoSpaceScript(int rune) =>
    (rune >= 0x0E00 && rune <= 0x0EFF) || // Thai, Lao
    (rune >= 0x1000 && rune <= 0x109F) || // Myanmar
    (rune >= 0x1780 && rune <= 0x17FF) || // Khmer
    (rune >= 0x2E80 && rune <= 0x312F) || // CJK radicals .. bopomofo, kana
    (rune >= 0x3190 && rune <= 0x9FFF) || // kanbun .. CJK unified
    (rune >= 0xF900 && rune <= 0xFAFF) || // CJK compatibility ideographs
    (rune >= 0xFE30 && rune <= 0xFE4F) || // CJK compatibility forms
    (rune >= 0xFF00 && rune <= 0xFFEF) || // half/full-width forms
    (rune >= 0x20000 && rune <= 0x3FFFF); // CJK extensions B..

bool _isLatin(int r) =>
    (r >= 0x61 && r <= 0x7A) ||
    (r >= 0xC0 && r <= 0x24F && r != 0xD7 && r != 0xF7) ||
    (r >= 0x1E00 && r <= 0x1EFF);

/// Lower-case Latin letter, including Vietnamese and other accented letters.
bool isLowerLatin(int rune) {
  if (!_isLatin(rune)) return false;
  final s = String.fromCharCode(rune);
  return s.toLowerCase() == s && s.toUpperCase() != s;
}

const _hyphens = {0x2D, 0xAD, 0x2010}; // '-', soft hyphen, hyphen

/// Result of joining the end of one line with the start of the next.
class LineJoin {
  /// Characters to drop from the end of the previous text.
  final int trimEnd;
  final String separator;
  const LineJoin(this.trimEnd, this.separator);
}

/// Decides how to join `prev` (end of a line) and `next` (start of the
/// following line): drop a trailing hyphen before a lower-case Latin letter,
/// no space between no-space scripts, a single space otherwise.
LineJoin lineJoin(String prev, String next) {
  if (prev.isEmpty || next.isEmpty) return const LineJoin(0, '');
  final pr = prev.runes.toList();
  final first = next.runes.first;
  final last = pr.last;
  if (pr.length >= 2 &&
      _hyphens.contains(last) &&
      !_isSpace(pr[pr.length - 2]) &&
      isLowerLatin(first)) {
    return const LineJoin(1, '');
  }
  if (_isSpace(last) || _isSpace(first)) return const LineJoin(0, '');
  if (isNoSpaceScript(last) || isNoSpaceScript(first)) {
    return const LineJoin(0, '');
  }
  return const LineJoin(0, ' ');
}

bool _isSpace(int r) => r == 0x20 || r == 0x09 || r == 0xA0 || r == 0x3000;

/// Separator between two words of the same line separated by [gap] points.
String wordSeparator(String prev, String next, double gap, double fontSize) {
  if (prev.isEmpty || next.isEmpty) return '';
  final last = prev.runes.last;
  final first = next.runes.first;
  if (isNoSpaceScript(last) || isNoSpaceScript(first)) {
    return gap > fontSize * 0.25 ? ' ' : '';
  }
  return ' ';
}

/// List markers: `•`, `-`, `*`, `–`, `1.` / `1)`, `a.` / `a)` followed by
/// white space.
final RegExp listMarkerPattern = RegExp(
  r'^\s*([•\-*–]|\d{1,3}[.)]|[a-z][.)])\s+(?=\S)',
);

/// Returns `(marker, prefixLength)` or `null`.
(String, int)? matchListMarker(String text) {
  final m = listMarkerPattern.firstMatch(text);
  if (m == null) return null;
  return (m.group(1)!, m.end);
}

bool isOrderedMarker(String marker) =>
    !const {'•', '-', '*', '–'}.contains(marker);

/// True when [text] ends a sentence: `.:!?` optionally followed by closing
/// quotes or brackets.
bool endsWithTerminal(String text) =>
    RegExp(r'''[.:!?。！？：][\s"'”’»)\]]*$''').hasMatch(text);

/// Normalises a header/footer candidate: digits (page numbers) collapsed,
/// white space squeezed, lower-cased.
String headerFooterKey(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r'\d+'), '#')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
