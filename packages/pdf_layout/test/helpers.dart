import 'package:pdf_layout/pdf_layout.dart';

const double pageW = 595;
const double pageH = 842;
const double marginL = 72;
const double fullWidth = 451; // 72 .. 523

bool _isWide(int rune) =>
    (rune >= 0x2E80 && rune <= 0x9FFF) ||
    (rune >= 0xF900 && rune <= 0xFAFF) ||
    (rune >= 0xFF00 && rune <= 0xFFEF);

double _naturalWidth(String word, double size) {
  var w = 0.0;
  for (final r in word.runes) {
    w += _isWide(r) ? size : size * 0.5;
  }
  return w;
}

/// Builds a line whose words are laid out left to right starting at [x].
/// When [width] is given the words are scaled so the line spans exactly it.
LayoutLine mkLine(
  String text,
  double x,
  double y, {
  double size = 10,
  bool bold = false,
  int page = 0,
  double? width,
  bool splitWords = true,
}) {
  final parts = splitWords
      ? text.split(' ').where((p) => p.isNotEmpty).toList()
      : [text];
  final space = size * 0.25;
  final natural =
      parts.fold<double>(0, (s, p) => s + _naturalWidth(p, size)) +
      space * (parts.length - 1);
  final scale = width == null || natural == 0 ? 1.0 : width / natural;
  final words = <LayoutWord>[];
  var cx = x;
  for (final p in parts) {
    final w = _naturalWidth(p, size) * scale;
    words.add(
      LayoutWord(
        text: p,
        bounds: LayoutRect(left: cx, top: y, width: w, height: size),
        fontSize: size,
        bold: bold,
      ),
    );
    cx += w + space * scale;
  }
  final total = width ?? natural;
  return LayoutLine(
    pageIndex: page,
    text: text,
    bounds: LayoutRect(left: x, top: y, width: total, height: size),
    fontSize: size,
    words: words,
  );
}

/// One extracted line covering several cells (as Syncfusion often returns a
/// table row): each cell is `(text, x)`.
LayoutLine mkRow(
  List<(String, double)> cells,
  double y, {
  double size = 10,
  int page = 0,
}) {
  final words = <LayoutWord>[];
  for (final (text, x) in cells) {
    words.addAll(mkLine(text, x, y, size: size, page: page).words);
  }
  final left = words.first.bounds.left;
  final right = words.last.bounds.left + words.last.bounds.width;
  return LayoutLine(
    pageIndex: page,
    text: cells.map((c) => c.$1).where((t) => t.isNotEmpty).join(' '),
    bounds: LayoutRect(left: left, top: y, width: right - left, height: size),
    fontSize: size,
    words: words,
  );
}

LayoutPage mkPage(List<LayoutLine> lines, {int index = 0}) =>
    LayoutPage(index: index, width: pageW, height: pageH, lines: lines);

String blockText(DocBlock b) => switch (b) {
  DocHeading h => h.text,
  DocParagraph p => p.text,
  DocListItem l => l.text,
  DocTable t => t.cells.map((r) => r.join('|')).join('\n'),
  DocPageBreak _ => '<pb>',
};
