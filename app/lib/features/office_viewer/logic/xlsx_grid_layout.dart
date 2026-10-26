import 'dart:math' as math;

import 'package:office_reader/office_reader.dart' as rd;

import '../data/xlsx_mapping.dart';

/// Vùng ô gộp cần vẽ (toạ độ 0-based theo sheet, chưa tính hàng/cột tiêu đề).
class MergeRegion {
  const MergeRegion(this.firstRow, this.firstCol, this.rowSpan, this.colSpan);

  final int firstRow;
  final int firstCol;
  final int rowSpan;
  final int colSpan;

  @override
  bool operator ==(Object other) =>
      other is MergeRegion &&
      other.firstRow == firstRow &&
      other.firstCol == firstCol &&
      other.rowSpan == rowSpan &&
      other.colSpan == colSpan;

  @override
  int get hashCode => Object.hash(firstRow, firstCol, rowSpan, colSpan);

  @override
  String toString() => 'MergeRegion($firstRow,$firstCol ${rowSpan}x$colSpan)';
}

/// Nhãn cột kiểu Excel: 0 → A, 25 → Z, 26 → AA.
String columnLabel(int col) {
  var n = col + 1;
  final sb = StringBuffer();
  while (n > 0) {
    final r = (n - 1) % 26;
    sb.write(String.fromCharCode(65 + r));
    n = (n - 1) ~/ 26;
  }
  return sb.toString().split('').reversed.join();
}

/// Hình học của lưới một sheet: số hàng/cột, độ rộng/cao (pixel logic, zoom 1),
/// số hàng/cột cố định (freeze) và vùng gộp đã cắt theo ranh giới freeze
/// (`TableView` không cho ô gộp vắt qua vùng ghim).
class XlsxGridLayout {
  XlsxGridLayout(
    this.sheet, {
    int maxPinnedRows = 10,
    int maxPinnedCols = 5,
  }) : pinnedRows = math.min(
         math.min(sheet.frozenRows, maxPinnedRows),
         math.max(sheet.maxRow - 1, 0),
       ),
       pinnedCols = math.min(
         math.min(sheet.frozenCols, maxPinnedCols),
         math.max(sheet.maxCol - 1, 0),
       ) {
    for (final m in sheet.merges) {
      final lastRow = math.min(m.lastRow, sheet.maxRow - 1);
      for (var r = m.firstRow; r <= lastRow; r++) {
        (_byRow[r] ??= []).add(m);
      }
    }
  }

  final rd.XlsxSheet sheet;
  final int pinnedRows;
  final int pinnedCols;
  final Map<int, List<rd.XlsxRange>> _byRow = {};

  int get rowCount => sheet.maxRow;
  int get colCount => sheet.maxCol;

  double columnWidth(int c) => columnWidthPx(
    sheet.columnWidthsChars[c] ?? sheet.defaultColumnWidthChars,
  );

  double rowHeight(int r) =>
      rowHeightPx(sheet.rowHeightsPt[r] ?? sheet.defaultRowHeightPt);

  /// Vùng gộp chứa ô ([row], [col]) hoặc `null` nếu ô không thuộc vùng gộp nào
  /// (hoặc vùng gộp chỉ còn 1×1 sau khi cắt).
  MergeRegion? mergeAt(int row, int col) {
    final list = _byRow[row];
    if (list == null) return null;
    for (final m in list) {
      if (col < m.firstCol || col > m.lastCol) continue;
      var lastRow = math.min(m.lastRow, sheet.maxRow - 1);
      var lastCol = math.min(m.lastCol, sheet.maxCol - 1);
      if (m.firstRow < pinnedRows && lastRow >= pinnedRows) {
        lastRow = pinnedRows - 1;
      }
      if (m.firstCol < pinnedCols && lastCol >= pinnedCols) {
        lastCol = pinnedCols - 1;
      }
      // Phần bị cắt không còn thuộc vùng gộp.
      if (row > lastRow || col > lastCol) return null;
      final rowSpan = lastRow - m.firstRow + 1;
      final colSpan = lastCol - m.firstCol + 1;
      if (rowSpan == 1 && colSpan == 1) return null;
      return MergeRegion(m.firstRow, m.firstCol, rowSpan, colSpan);
    }
    return null;
  }
}
