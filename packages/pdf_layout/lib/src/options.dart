/// Tunable heuristics for [rebuildDocument] and [detectSheets].
///
/// Factors suffixed `Factor` multiply the font size (or line height where
/// noted) of the text being examined.
class RebuildOptions {
  // --- header / footer -----------------------------------------------------

  /// A line is a running header/footer when the same text (digits ignored)
  /// appears at the same height on at least this share of pages.
  final double headerFooterMinPageRatio;

  /// Minimum number of pages before header/footer removal is attempted.
  final int headerFooterMinPages;

  /// Only lines within this share of the page height from the top or bottom
  /// edge can be headers/footers.
  final double headerFooterZone;

  /// Allowed difference of the line top between pages, in points.
  final double headerFooterYTolerance;

  // --- paragraphs ----------------------------------------------------------

  /// Two lines can belong to one paragraph when the distance between their
  /// tops is at most this many line heights ...
  final double lineGapFactor;

  /// ... or at most this multiple of the document's typical line pitch
  /// (25th percentile), which adapts to 1.5 / double line spacing ...
  final double typicalPitchFactor;

  /// ... but never more than this many line heights.
  final double maxLineGapFactor;

  /// Max difference of left edges (x font size) for lines of one paragraph.
  final double leftToleranceFactor;

  /// Max first-line / hanging indent (x font size).
  final double maxIndentFactor;

  /// Max font size difference (points) inside one paragraph.
  final double fontSizeTolerance;

  /// A line narrower than this share of the column ending with `.:!?`
  /// closes its paragraph.
  final double shortLineRatio;

  // --- headings ------------------------------------------------------------

  /// Font size / body median ratio from which a block is a heading.
  final double headingRatio;
  final double heading1Ratio;
  final double heading2Ratio;

  /// Max length of a stand-alone bold line treated as heading (level 3).
  final int boldHeadingMaxChars;

  // --- columns -------------------------------------------------------------

  final bool detectColumns;

  /// A vertical gutter must stay free for this share of the page height.
  final double columnGutterMinHeightRatio;

  /// Gutter search band, as shares of the page width.
  final double columnSearchFrom;
  final double columnSearchTo;

  /// Minimum number of text runs on each side of the gutter.
  final int minColumnLines;

  // --- tables --------------------------------------------------------------

  final bool detectTables;

  /// Gap between words (x font size) that splits a line into cells.
  final double cellGapFactor;

  /// Row grouping tolerance on the vertical centre (x line height).
  final double rowToleranceFactor;

  /// Column clustering tolerance on cell left edges (x font size).
  final double columnToleranceFactor;

  /// A column must appear in at least this share of the region's rows.
  final double columnMinRowRatio;

  final int tableMinRows;
  final int tableMinColumns;

  /// Max white space between table rows (x row height).
  final double tableMaxRowGapFactor;

  // --- output --------------------------------------------------------------

  /// Insert [DocPageBreak] between source pages.
  final bool insertPageBreaks;

  const RebuildOptions({
    this.headerFooterMinPageRatio = 0.6,
    this.headerFooterMinPages = 2,
    this.headerFooterZone = 0.15,
    this.headerFooterYTolerance = 6,
    this.lineGapFactor = 1.5,
    this.typicalPitchFactor = 1.15,
    this.maxLineGapFactor = 2.2,
    this.leftToleranceFactor = 0.5,
    this.maxIndentFactor = 6,
    this.fontSizeTolerance = 0.5,
    this.shortLineRatio = 0.7,
    this.headingRatio = 1.2,
    this.heading1Ratio = 1.6,
    this.heading2Ratio = 1.35,
    this.boldHeadingMaxChars = 80,
    this.detectColumns = true,
    this.columnGutterMinHeightRatio = 0.5,
    this.columnSearchFrom = 0.3,
    this.columnSearchTo = 0.7,
    this.minColumnLines = 3,
    this.detectTables = true,
    this.cellGapFactor = 1.0,
    this.rowToleranceFactor = 0.5,
    this.columnToleranceFactor = 0.8,
    this.columnMinRowRatio = 0.6,
    this.tableMinRows = 3,
    this.tableMinColumns = 2,
    this.tableMaxRowGapFactor = 2.0,
    this.insertPageBreaks = true,
  });
}

/// Options for [writeDocx]. Defaults: A4 portrait, 2.54 cm margins,
/// Arial 11 pt with "Noto Sans" for East Asian / complex scripts.
class DocxWriteOptions {
  final double pageWidthPt;
  final double pageHeightPt;
  final double marginPt;
  final String fontFamily;

  /// Font used for East Asian and complex scripts (CJK, Thai, ...).
  final String fallbackFontFamily;
  final double fontSizePt;
  final String? title;
  final String author;

  /// `dcterms:created`; current time when `null`.
  final DateTime? created;

  const DocxWriteOptions({
    this.pageWidthPt = 595.3,
    this.pageHeightPt = 841.9,
    this.marginPt = 72,
    this.fontFamily = 'Arial',
    this.fallbackFontFamily = 'Noto Sans',
    this.fontSizePt = 11,
    this.title,
    this.author = 'PDF Office',
    this.created,
  });
}
