import 'dart:typed_data';

/// Căn ngang ô.
enum XlsxHAlign { general, left, center, right }

/// Một ô (row/col 0-based). [text] là giá trị đã định dạng để hiển thị.
class XlsxCell {
  const XlsxCell({
    required this.row,
    required this.col,
    required this.text,
    this.bold = false,
    this.italic = false,
    this.fontColorArgb,
    this.fillArgb,
    this.hAlign = XlsxHAlign.general,
    this.isNumeric = false,
  });

  final int row;
  final int col;
  final String text;
  final bool bold;
  final bool italic;
  final int? fontColorArgb;
  final int? fillArgb;
  final XlsxHAlign hAlign;

  /// Giá trị số (căn phải khi `general`).
  final bool isNumeric;
}

/// Vùng ô gộp, 0-based, gồm cả hai đầu.
class XlsxMergedRange {
  const XlsxMergedRange(
    this.firstRow,
    this.firstCol,
    this.lastRow,
    this.lastCol,
  );
  final int firstRow;
  final int firstCol;
  final int lastRow;
  final int lastCol;

  bool contains(int row, int col) =>
      row >= firstRow && row <= lastRow && col >= firstCol && col <= lastCol;
}

/// Một sheet. Ô thưa: chỉ ô có dữ liệu/định dạng mới có trong [cells].
class XlsxSheet {
  XlsxSheet({
    required this.name,
    required this.rowCount,
    required this.colCount,
    required List<XlsxCell> cells,
    this.merges = const [],
    this.columnWidths = const {},
    this.rowHeights = const {},
    this.hidden = false,
  }) : _index = {for (final c in cells) (c.row, c.col): c},
       cells = List.unmodifiable(cells);

  final String name;

  /// Số hàng/cột (tới ô có dữ liệu xa nhất, +1).
  final int rowCount;
  final int colCount;
  final List<XlsxCell> cells;
  final List<XlsxMergedRange> merges;

  /// col → độ rộng (pixel logic, đã đổi từ đơn vị Excel ≈ ký tự × 7 + 5).
  final Map<int, double> columnWidths;

  /// row → chiều cao (pixel logic, đã đổi từ point × 4/3).
  final Map<int, double> rowHeights;
  final bool hidden;

  final Map<(int, int), XlsxCell> _index;

  XlsxCell? cellAt(int row, int col) => _index[(row, col)];
}

class XlsxWorkbook {
  const XlsxWorkbook(this.sheets);
  final List<XlsxSheet> sheets;
}

/// Đọc .xlsx thành [XlsxWorkbook] (Office viewer + XLSX→PDF).
/// Ghi chú: gói `excel` bị bỏ (xung đột `xml` 7 của Syncfusion 35) — impl tự parse bằng
/// `archive` + `xml` (sharedStrings, styles, sheetN.xml, mergeCells).
abstract interface class XlsxEngine {
  /// Lỗi: `CorruptFile`.
  Future<XlsxWorkbook> parseFile(String path);

  Future<XlsxWorkbook> parseBytes(Uint8List bytes);
}
