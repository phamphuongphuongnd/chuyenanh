import 'analysis.dart';
import 'model.dart';
import 'options.dart';

/// Rows `firstRow .. firstRow + rowCount - 1` (0-based) of a [SheetGrid]
/// hold a detected table with [columnCount] columns.
class SheetTableRange {
  final int firstRow;
  final int rowCount;
  final int columnCount;

  const SheetTableRange({
    required this.firstRow,
    required this.rowCount,
    required this.columnCount,
  });

  int get lastRow => firstRow + rowCount - 1;

  @override
  String toString() =>
      'SheetTableRange(row $firstRow, $rowCount x $columnCount)';
}

/// One worksheet per PDF page.
class SheetGrid {
  final String name;

  /// Cell texts, top to bottom; rows may be ragged. Text outside tables is a
  /// single cell in column A.
  final List<List<String>> rows;
  final List<SheetTableRange> tableRanges;

  const SheetGrid({
    required this.name,
    required this.rows,
    this.tableRanges = const [],
  });
}

/// Detects tables page by page for spreadsheet export.
///
/// Pure and synchronous; safe to run inside `Isolate.run`.
List<SheetGrid> detectSheets(
  List<LayoutPage> pages, {
  RebuildOptions options = const RebuildOptions(),
}) {
  final analysis = analyzePages(pages, options);
  return [for (final page in analysis) _sheet(page)];
}

SheetGrid _sheet(PageAnalysis page) {
  final rows = <List<String>>[];
  final ranges = <SheetTableRange>[];
  for (final flow in page.flows) {
    for (final item in flow.items) {
      switch (item) {
        case TableItem t:
          ranges.add(
            SheetTableRange(
              firstRow: rows.length,
              rowCount: t.cells.length,
              columnCount: t.columnCount,
            ),
          );
          rows.addAll(t.cells.map((r) => List<String>.of(r)));
        case RowItem r:
          rows.add([r.row.text]);
      }
    }
  }
  return SheetGrid(
    name: 'Page ${page.page.index + 1}',
    rows: rows,
    tableRanges: ranges,
  );
}
