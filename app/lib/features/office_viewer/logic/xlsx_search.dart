import 'package:office_reader/office_reader.dart' as rd;

/// Một ô khớp từ khoá: [sheetIndex] là chỉ số trong danh sách sheet truyền vào
/// [findXlsxHits]; [row]/[col] 0-based theo sheet (chưa tính hàng/cột tiêu đề).
class XlsxHit {
  const XlsxHit(this.sheetIndex, this.row, this.col);

  final int sheetIndex;
  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      other is XlsxHit &&
      other.sheetIndex == sheetIndex &&
      other.row == row &&
      other.col == col;

  @override
  int get hashCode => Object.hash(sheetIndex, row, col);

  @override
  String toString() => 'XlsxHit($sheetIndex,$row,$col)';
}

/// Tìm [query] (không phân biệt hoa thường) trong chuỗi hiển thị của mọi ô,
/// theo thứ tự sheet → hàng → cột. Truy vấn rỗng → danh sách rỗng.
List<XlsxHit> findXlsxHits(List<rd.XlsxSheet> sheets, String query) {
  if (query.isEmpty) return const [];
  final q = query.toLowerCase();
  final hits = <XlsxHit>[];
  for (var i = 0; i < sheets.length; i++) {
    final sheet = sheets[i];
    final keys = sheet.cells.keys.toList()
      ..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
    for (final k in keys) {
      final display = sheet.cells[k]!.display;
      if (display.isNotEmpty && display.toLowerCase().contains(q)) {
        hits.add(XlsxHit(i, k.$1, k.$2));
      }
    }
  }
  return hits;
}
