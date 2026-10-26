import '../../../engines/pdf/pdf_tools_engine.dart';

/// Số trang tối đa khi tạo tài liệu trắng.
const int maxBlankPages = 1000;

/// Đọc chuỗi khoảng trang do người dùng gõ: `1-3, 5, 7-9` (phân cách `,` hoặc `;`).
///
/// Trang 1-based, phải nằm trong `1..pageCount`, mỗi khoảng `start <= end`.
/// Sai cú pháp / ngoài phạm vi → [FormatException] (UI hiện thông báo).
List<PageRange> parsePageRanges(String text, int pageCount) {
  final parts = text
      .split(RegExp(r'[,;]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (parts.isEmpty) throw const FormatException('empty');
  final result = <PageRange>[];
  for (final part in parts) {
    final m = RegExp(r'^(\d+)\s*(?:-\s*(\d+))?$').firstMatch(part);
    if (m == null) throw FormatException('invalid range: $part');
    final start = int.parse(m.group(1)!);
    final end = m.group(2) == null ? start : int.parse(m.group(2)!);
    if (start < 1 || end < start) throw FormatException('invalid range: $part');
    result.add(PageRange(start, end));
  }
  validateRanges(result, pageCount);
  return result;
}

/// Kiểm các khoảng nằm trong `1..pageCount`; rỗng → [ArgumentError], sai → [FormatException].
void validateRanges(List<PageRange> ranges, int pageCount) {
  if (ranges.isEmpty) throw ArgumentError('ranges must not be empty');
  for (final r in ranges) {
    if (r.start < 1 || r.end < r.start || r.end > pageCount) {
      throw FormatException('range $r out of 1..$pageCount');
    }
  }
}

/// Đổi [mode] thành danh sách khoảng trang cụ thể (mỗi khoảng = một file kết quả).
List<PageRange> planSplit(SplitMode mode, int pageCount) {
  if (pageCount < 1) throw ArgumentError('pageCount must be >= 1');
  switch (mode) {
    case SplitEveryPage():
      return [for (var i = 1; i <= pageCount; i++) PageRange(i, i)];
    case SplitEveryN(:final pagesPerFile):
      return [
        for (var s = 1; s <= pageCount; s += pagesPerFile)
          PageRange(s, (s + pagesPerFile - 1).clamp(s, pageCount)),
      ];
    case SplitByRanges(:final ranges):
      validateRanges(ranges, pageCount);
      return List.of(ranges);
  }
}

/// Nhãn trong tên file: `1-3` hoặc `4` (khoảng một trang).
String rangeLabel(PageRange r) =>
    r.start == r.end ? '${r.start}' : '${r.start}-${r.end}';

/// Kiểm danh sách [PageOp] với số trang nguồn [pageCount]: không rỗng, chỉ số hợp lệ,
/// góc xoay là bội của 90.
void validatePageOps(List<PageOp> ops, int pageCount) {
  if (ops.isEmpty) throw ArgumentError('pages must not be empty');
  for (final op in ops) {
    if (op.sourceIndex < 0 || op.sourceIndex >= pageCount) {
      throw RangeError.range(op.sourceIndex, 0, pageCount - 1, 'sourceIndex');
    }
    if (op.rotation % 90 != 0) {
      throw ArgumentError.value(
        op.rotation,
        'rotation',
        'must be 0/90/180/270',
      );
    }
  }
}
