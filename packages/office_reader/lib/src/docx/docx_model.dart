import 'dart:typed_data';

/// A parsed Word document. Units: twips (1/20 pt), EMU (1/914400 inch), pt.
class DocxDocument {
  final List<DocxBlock> blocks;
  final DocxPageSetup page;
  const DocxDocument({required this.blocks, required this.page});
}

/// Page size and margins of the (last) section, in twips.
class DocxPageSetup {
  final int widthTwips, heightTwips;
  final int marginTopTwips,
      marginRightTwips,
      marginBottomTwips,
      marginLeftTwips;
  const DocxPageSetup({
    this.widthTwips = 11906,
    this.heightTwips = 16838,
    this.marginTopTwips = 1440,
    this.marginRightTwips = 1440,
    this.marginBottomTwips = 1440,
    this.marginLeftTwips = 1440,
  });

  /// A4 portrait with 1 inch margins.
  static const a4 = DocxPageSetup();
}

enum DocxAlign { left, center, right, justify }

sealed class DocxBlock {
  const DocxBlock();
}

class DocxParagraph extends DocxBlock {
  /// 1..6 for headings (from style name / outline level), else null.
  final int? headingLevel;
  final String? styleId;
  final DocxAlign align;

  /// 0-based list level, null when the paragraph is not a list item.
  final int? listLevel;
  final bool listOrdered;

  /// Rendered label, e.g. `1.`, `a)`, `1.2.`, `•`.
  final String? listLabel;
  final double? indentLeftPt, indentRightPt, firstLineIndentPt;
  final double? spaceBeforePt, spaceAfterPt;

  /// Line spacing multiple (1.0 = single) when given as `auto`.
  final double? lineSpacing;
  final List<DocxInline> inlines;
  final bool pageBreakBefore;

  const DocxParagraph({
    this.headingLevel,
    this.styleId,
    this.align = DocxAlign.left,
    this.listLevel,
    this.listOrdered = false,
    this.listLabel,
    this.indentLeftPt,
    this.indentRightPt,
    this.firstLineIndentPt,
    this.spaceBeforePt,
    this.spaceAfterPt,
    this.lineSpacing,
    this.inlines = const [],
    this.pageBreakBefore = false,
  });

  /// Concatenated text of all runs (images/breaks ignored, line break = \n).
  String get plainText => inlines
      .map(
        (e) => switch (e) {
          DocxRun r => r.text,
          DocxBreak() => '\n',
          DocxImage() => '',
        },
      )
      .join();

  DocxParagraph copyWith({
    List<DocxInline>? inlines,
    String? listLabel,
    bool clearList = false,
    bool? pageBreakBefore,
  }) => DocxParagraph(
    headingLevel: headingLevel,
    styleId: styleId,
    align: align,
    listLevel: clearList ? null : listLevel,
    listOrdered: clearList ? false : listOrdered,
    listLabel: clearList ? null : (listLabel ?? this.listLabel),
    indentLeftPt: indentLeftPt,
    indentRightPt: indentRightPt,
    firstLineIndentPt: firstLineIndentPt,
    spaceBeforePt: spaceBeforePt,
    spaceAfterPt: spaceAfterPt,
    lineSpacing: lineSpacing,
    inlines: inlines ?? this.inlines,
    pageBreakBefore: pageBreakBefore ?? this.pageBreakBefore,
  );
}

/// An explicit page break (`w:br w:type="page"`), hoisted out of paragraphs.
class DocxPageBreak extends DocxBlock {
  const DocxPageBreak();
}

class DocxTable extends DocxBlock {
  final List<int> columnWidthsTwips;
  final List<DocxTableRow> rows;

  /// True when the table (or its style) declares visible borders.
  final bool bordered;
  const DocxTable({
    required this.columnWidthsTwips,
    required this.rows,
    this.bordered = false,
  });
}

class DocxTableRow {
  final List<DocxTableCell> cells;
  final bool isHeader;
  final int? heightTwips;
  const DocxTableRow({
    required this.cells,
    this.isHeader = false,
    this.heightTwips,
  });
}

class DocxTableCell {
  final List<DocxBlock> blocks;

  /// Number of grid columns this cell spans horizontally.
  final int gridSpan;

  /// True when the cell continues a vertical merge from the row above
  /// (renderers should skip drawing it; the restart cell has [rowSpan] > 1).
  final bool vMergeContinue;

  /// Rows covered by this cell (>1 only on the cell that starts a vMerge).
  final int rowSpan;
  final int? shadingArgb;
  final int? widthTwips;
  const DocxTableCell({
    required this.blocks,
    this.gridSpan = 1,
    this.vMergeContinue = false,
    this.rowSpan = 1,
    this.shadingArgb,
    this.widthTwips,
  });

  DocxTableCell withRowSpan(int span) => DocxTableCell(
    blocks: blocks,
    gridSpan: gridSpan,
    vMergeContinue: vMergeContinue,
    rowSpan: span,
    shadingArgb: shadingArgb,
    widthTwips: widthTwips,
  );
}

sealed class DocxInline {
  const DocxInline();
}

class DocxRun extends DocxInline {
  /// Text; `w:tab` becomes `\t`.
  final String text;
  final bool bold, italic, underline, strike;
  final bool superscript, subscript;

  /// `w:smallCaps`: [text] is already upper-cased (also for `w:caps`); a
  /// renderer may draw the originally lower-case letters smaller.
  final bool smallCaps;
  final double? fontSizePt;
  final int? colorArgb, highlightArgb;
  final String? fontFamily;

  /// External URL, or `#bookmark` for internal anchors.
  final String? hyperlink;

  const DocxRun({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.superscript = false,
    this.subscript = false,
    this.smallCaps = false,
    this.fontSizePt,
    this.colorArgb,
    this.highlightArgb,
    this.fontFamily,
    this.hyperlink,
  });

  @override
  String toString() => 'DocxRun("$text")';
}

class DocxImage extends DocxInline {
  final Uint8List bytes;

  /// Lower-case file extension without dot (png, jpeg, gif, emf...).
  final String extension;
  final int widthEmu, heightEmu;

  /// True for floating (`wp:anchor`) images; rendered inline anyway.
  final bool floating;
  const DocxImage({
    required this.bytes,
    required this.extension,
    required this.widthEmu,
    required this.heightEmu,
    this.floating = false,
  });

  double get widthPt => widthEmu / 12700;
  double get heightPt => heightEmu / 12700;
}

/// A line break (`w:br`, `w:cr`; column breaks are treated as line breaks).
/// [readDocx] hoists page breaks into [DocxPageBreak] blocks, so it always
/// produces `page == false`; the flag exists for code that builds models.
class DocxBreak extends DocxInline {
  final bool page;
  const DocxBreak({this.page = false});
}
