class XlsxWorkbook {
  final List<XlsxSheet> sheets;
  final bool date1904;
  const XlsxWorkbook({required this.sheets, this.date1904 = false});
}

/// One worksheet. All indices are **0-based** (`A1` is `(0, 0)`);
/// [maxRow] / [maxCol] are exclusive bounds (number of used rows / columns,
/// including merged areas).
class XlsxSheet {
  final String name;
  final int maxRow, maxCol;

  /// Keyed by (row, col).
  final Map<(int, int), XlsxCell> cells;
  final List<XlsxRange> merges;

  /// Explicit widths in Excel "characters" (0 = hidden column).
  final Map<int, double> columnWidthsChars;

  /// Explicit heights in points (0 = hidden row).
  final Map<int, double> rowHeightsPt;
  final double defaultColumnWidthChars;
  final double defaultRowHeightPt;
  final int frozenRows, frozenCols;
  final bool hidden;

  const XlsxSheet({
    required this.name,
    required this.maxRow,
    required this.maxCol,
    required this.cells,
    this.merges = const [],
    this.columnWidthsChars = const {},
    this.rowHeightsPt = const {},
    this.defaultColumnWidthChars = 8.43,
    this.defaultRowHeightPt = 15,
    this.frozenRows = 0,
    this.frozenCols = 0,
    this.hidden = false,
  });

  XlsxCell? cell(int row, int col) => cells[(row, col)];
}

/// Inclusive, 0-based cell range.
class XlsxRange {
  final int firstRow, firstCol, lastRow, lastCol;
  const XlsxRange(this.firstRow, this.firstCol, this.lastRow, this.lastCol);

  bool contains(int row, int col) =>
      row >= firstRow && row <= lastRow && col >= firstCol && col <= lastCol;

  @override
  String toString() => 'XlsxRange($firstRow,$firstCol..$lastRow,$lastCol)';
}

enum XlsxCellType { blank, number, string, boolean, error, date }

class XlsxCell {
  /// Value formatted with the cell's number format.
  final String display;

  /// double for numbers, DateTime (UTC) for dates, String, bool, or null.
  final Object? raw;
  final XlsxCellType type;
  final XlsxStyle style;

  /// Formula text without `=` when the cell holds a formula (the value is
  /// the cached result).
  final String? formula;
  const XlsxCell({
    required this.display,
    required this.raw,
    required this.type,
    required this.style,
    this.formula,
  });

  @override
  String toString() => 'XlsxCell($display)';
}

enum XlsxHAlign {
  general,
  left,
  center,
  right,
  justify,
  fill,
  centerContinuous,
  distributed,
}

enum XlsxVAlign { top, center, bottom, justify, distributed }

class XlsxStyle {
  final bool bold, italic, underline, strike;
  final int? fontColorArgb, fillArgb;
  final double? fontSizePt;
  final String? fontFamily;
  final XlsxHAlign hAlign;
  final XlsxVAlign vAlign;
  final bool wrap;
  final bool hasBorder;

  /// Effective number format code (e.g. `0.00%`).
  final String numberFormat;
  final int indent;

  const XlsxStyle({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.fontColorArgb,
    this.fillArgb,
    this.fontSizePt,
    this.fontFamily,
    this.hAlign = XlsxHAlign.general,
    this.vAlign = XlsxVAlign.bottom,
    this.wrap = false,
    this.hasBorder = false,
    this.numberFormat = 'General',
    this.indent = 0,
  });

  static const plain = XlsxStyle();
}
