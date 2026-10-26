import 'package:office_reader/office_reader.dart' as rd;

/// Một ô bảng DOCX đã đặt vào lưới: bắt đầu ở ([row], [col]), phủ [rowSpan]×[colSpan].
class PlacedCell {
  const PlacedCell(this.row, this.col, this.rowSpan, this.colSpan, this.cell);

  final int row;
  final int col;
  final int rowSpan;
  final int colSpan;
  final rd.DocxTableCell cell;
}

class TableGrid {
  const TableGrid(this.cells, this.rowCount, this.colCount);

  final List<PlacedCell> cells;
  final int rowCount;
  final int colCount;
}

/// Đặt các ô của [table] vào lưới (gridSpan = số cột phủ, rowSpan lấy từ ô bắt đầu vMerge).
/// Ô `vMergeContinue` chỉ chiếm chỗ, không được vẽ.
TableGrid buildTableGrid(rd.DocxTable table) {
  final placed = <PlacedCell>[];
  var colCount = table.columnWidthsTwips.length;
  final rowCount = table.rows.length;
  for (var r = 0; r < rowCount; r++) {
    var c = 0;
    for (final cell in table.rows[r].cells) {
      final span = cell.gridSpan < 1 ? 1 : cell.gridSpan;
      if (!cell.vMergeContinue) {
        var rs = cell.rowSpan < 1 ? 1 : cell.rowSpan;
        if (r + rs > rowCount) rs = rowCount - r;
        placed.add(PlacedCell(r, c, rs, span, cell));
      }
      c += span;
    }
    if (c > colCount) colCount = c;
  }
  return TableGrid(placed, rowCount, colCount);
}

/// Độ rộng từng cột (đã nhân [factor]). Cột thiếu số liệu chia đều [fallback].
List<double> tableColumnWidths(
  rd.DocxTable table,
  int colCount,
  double factor, {
  double fallback = 80,
}) {
  final given = table.columnWidthsTwips;
  return [
    for (var i = 0; i < colCount; i++)
      (i < given.length && given[i] > 0 ? given[i] / 20 : fallback) * factor,
  ];
}
