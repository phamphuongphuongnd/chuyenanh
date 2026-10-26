import 'package:office_reader/office_reader.dart' as rd;

import '../../../engines/office/xlsx_engine.dart' as eng;

/// Pixel logic của độ rộng cột Excel: ký tự × 7 + 5 (0 = cột ẩn).
double columnWidthPx(double chars) => chars <= 0 ? 0 : chars * 7 + 5;

/// Pixel logic của chiều cao hàng: point × 4/3 (0 = hàng ẩn).
double rowHeightPx(double pt) => pt <= 0 ? 0 : pt * 4 / 3;

/// Đổi model `office_reader` sang model của interface `XlsxEngine` (XLSX→PDF).
/// Màn xem XLSX dùng thẳng model `office_reader` (có freeze panes, cỡ chữ...).
eng.XlsxWorkbook mapXlsx(rd.XlsxWorkbook wb) =>
    eng.XlsxWorkbook([for (final s in wb.sheets) _mapSheet(s)]);

eng.XlsxHAlign _align(rd.XlsxHAlign a) => switch (a) {
  rd.XlsxHAlign.general => eng.XlsxHAlign.general,
  rd.XlsxHAlign.right => eng.XlsxHAlign.right,
  rd.XlsxHAlign.center ||
  rd.XlsxHAlign.centerContinuous => eng.XlsxHAlign.center,
  _ => eng.XlsxHAlign.left,
};

eng.XlsxSheet _mapSheet(rd.XlsxSheet s) {
  final cells = <eng.XlsxCell>[
    for (final e in s.cells.entries)
      eng.XlsxCell(
        row: e.key.$1,
        col: e.key.$2,
        text: e.value.display,
        bold: e.value.style.bold,
        italic: e.value.style.italic,
        fontColorArgb: e.value.style.fontColorArgb,
        fillArgb: e.value.style.fillArgb,
        hAlign: _align(e.value.style.hAlign),
        isNumeric:
            e.value.type == rd.XlsxCellType.number ||
            e.value.type == rd.XlsxCellType.date,
      ),
  ];
  // Điền đủ độ rộng mọi cột (engine không có "độ rộng mặc định").
  final widths = <int, double>{
    for (var c = 0; c < s.maxCol; c++)
      c: columnWidthPx(s.columnWidthsChars[c] ?? s.defaultColumnWidthChars),
  };
  return eng.XlsxSheet(
    name: s.name,
    rowCount: s.maxRow,
    colCount: s.maxCol,
    cells: cells,
    merges: [
      for (final m in s.merges)
        eng.XlsxMergedRange(m.firstRow, m.firstCol, m.lastRow, m.lastCol),
    ],
    columnWidths: widths,
    rowHeights: {
      for (final e in s.rowHeightsPt.entries) e.key: rowHeightPx(e.value),
    },
    hidden: s.hidden,
  );
}
