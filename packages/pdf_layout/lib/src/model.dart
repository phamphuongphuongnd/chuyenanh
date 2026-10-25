/// Input model: text extracted from PDF pages.
///
/// Coordinates are PDF points with the origin at the top-left corner of the
/// page and `y` growing downwards (the convention used by Syncfusion's
/// `PdfTextExtractor.extractTextLines()`).
library;

/// Axis-aligned rectangle in page points.
class LayoutRect {
  final double left;
  final double top;
  final double width;
  final double height;

  const LayoutRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  double get right => left + width;
  double get bottom => top + height;
  double get centerX => left + width / 2;
  double get centerY => top + height / 2;

  @override
  String toString() => 'LayoutRect($left, $top, $width x $height)';
}

/// A single word inside a [LayoutLine].
class LayoutWord {
  final String text;
  final LayoutRect bounds;
  final double fontSize;
  final bool bold;

  const LayoutWord({
    required this.text,
    required this.bounds,
    required this.fontSize,
    this.bold = false,
  });

  @override
  String toString() => 'LayoutWord("$text" @ $bounds)';
}

/// One visual line of text as reported by the PDF text extractor.
///
/// [words] may be empty; the line is then treated as a single text run.
class LayoutLine {
  final int pageIndex;
  final String text;
  final LayoutRect bounds;
  final double fontSize;
  final List<LayoutWord> words;

  const LayoutLine({
    required this.pageIndex,
    required this.text,
    required this.bounds,
    required this.fontSize,
    this.words = const [],
  });

  @override
  String toString() => 'LayoutLine(p$pageIndex "$text" @ $bounds)';
}

/// A page and the text lines found on it.
class LayoutPage {
  final int index;
  final double width;
  final double height;
  final List<LayoutLine> lines;

  const LayoutPage({
    required this.index,
    required this.width,
    required this.height,
    required this.lines,
  });
}
