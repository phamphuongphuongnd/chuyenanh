/// Output model of [rebuildDocument] and input of [writeDocx].
library;

/// A run of text with uniform formatting.
class DocSpan {
  final String text;
  final bool bold;

  /// Font size in points; `null` means "body text size".
  final double? fontSizePt;

  const DocSpan(this.text, {this.bold = false, this.fontSizePt});

  @override
  bool operator ==(Object other) =>
      other is DocSpan &&
      other.text == text &&
      other.bold == bold &&
      other.fontSizePt == fontSizePt;

  @override
  int get hashCode => Object.hash(text, bold, fontSizePt);

  @override
  String toString() =>
      'DocSpan("$text"${bold ? ', bold' : ''}'
      '${fontSizePt != null ? ', ${fontSizePt}pt' : ''})';
}

String _joinSpans(List<DocSpan> spans) => spans.map((s) => s.text).join();

/// A block-level element of a rebuilt document.
sealed class DocBlock {
  const DocBlock();
}

/// Heading, level 1..3.
class DocHeading extends DocBlock {
  final int level;
  final List<DocSpan> spans;

  const DocHeading({required this.level, required this.spans});

  String get text => _joinSpans(spans);

  @override
  String toString() => 'DocHeading($level, "$text")';
}

enum DocAlign { left, center, right, justify }

/// Body paragraph.
class DocParagraph extends DocBlock {
  final List<DocSpan> spans;
  final DocAlign align;

  /// Left indent of the paragraph body relative to the text column, in points.
  final double indentPt;

  /// Extra indent of the first line relative to [indentPt]; negative for a
  /// hanging first line.
  final double firstLineIndentPt;

  const DocParagraph({
    required this.spans,
    this.align = DocAlign.left,
    this.indentPt = 0,
    this.firstLineIndentPt = 0,
  });

  String get text => _joinSpans(spans);

  @override
  String toString() => 'DocParagraph($align, "$text")';
}

/// List item. [marker] is the original marker (`•`, `1.`, `a)`, ...);
/// [spans] hold the text after it.
class DocListItem extends DocBlock {
  final bool ordered;
  final String marker;
  final List<DocSpan> spans;

  const DocListItem({
    required this.ordered,
    required this.marker,
    required this.spans,
  });

  String get text => _joinSpans(spans);

  @override
  String toString() => 'DocListItem($marker "$text")';
}

/// Table as rows of cell texts (rows may be ragged).
class DocTable extends DocBlock {
  final List<List<String>> cells;

  const DocTable({required this.cells});

  int get columnCount => cells.fold(0, (m, r) => r.length > m ? r.length : m);

  @override
  String toString() => 'DocTable(${cells.length}x$columnCount)';
}

/// Hard page break (inserted between source pages).
class DocPageBreak extends DocBlock {
  const DocPageBreak();

  @override
  String toString() => 'DocPageBreak()';
}
