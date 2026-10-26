/// Lý do khoảng trang không hợp lệ.
enum PageRangeIssue { empty, syntax, outOfRange, reversed }

sealed class PageRangeResult {
  const PageRangeResult();
}

/// Danh sách trang 0-based, tăng dần, không trùng.
final class PageRangeOk extends PageRangeResult {
  const PageRangeOk(this.pages);
  final List<int> pages;
}

final class PageRangeInvalid extends PageRangeResult {
  const PageRangeInvalid(this.issue);
  final PageRangeIssue issue;
}

/// Đọc khoảng trang người dùng gõ, vd. `1-3,5`, `8-` (từ trang 8 đến hết).
/// Trang người dùng đánh số từ 1; kết quả 0-based. Dấu phân cách: `,` hoặc `;`.
PageRangeResult parsePageRange(String input, int pageCount) {
  final text = input.replaceAll(RegExp(r'[–—−]'), '-').trim();
  if (text.isEmpty) return const PageRangeInvalid(PageRangeIssue.empty);

  final pages = <int>{};
  for (final rawToken in text.split(RegExp(r'[,;]'))) {
    final token = rawToken.replaceAll(RegExp(r'\s+'), '');
    if (token.isEmpty) return const PageRangeInvalid(PageRangeIssue.syntax);
    final parts = token.split('-');
    if (parts.length > 2) return const PageRangeInvalid(PageRangeIssue.syntax);

    final from = _parseInt(parts[0]);
    if (from == _syntax) return const PageRangeInvalid(PageRangeIssue.syntax);

    int to;
    if (parts.length == 1) {
      to = from;
    } else if (parts[1].isEmpty) {
      to = pageCount; // "8-" = đến hết
    } else {
      to = _parseInt(parts[1]);
      if (to == _syntax) {
        return const PageRangeInvalid(PageRangeIssue.syntax);
      }
    }

    if (from < 1 || to < 1 || from > pageCount || to > pageCount) {
      return const PageRangeInvalid(PageRangeIssue.outOfRange);
    }
    if (to < from) return const PageRangeInvalid(PageRangeIssue.reversed);
    for (var i = from; i <= to; i++) {
      pages.add(i - 1);
    }
  }
  return PageRangeOk(pages.toList()..sort());
}

const int _syntax = -1;
const int _huge = 1 << 40;

/// Số nguyên không âm; chuỗi không phải toàn chữ số → [_syntax]; quá lớn → [_huge].
int _parseInt(String s) {
  if (s.isEmpty || !RegExp(r'^\d+$').hasMatch(s)) return _syntax;
  if (s.length > 9) return _huge;
  return int.parse(s);
}

/// Số trang người dùng gõ để nhảy (1..[pageCount]); không hợp lệ → null.
int? parseJumpPage(String input, int pageCount) {
  final s = input.trim();
  if (!RegExp(r'^\d{1,9}$').hasMatch(s)) return null;
  final n = int.parse(s);
  return (n >= 1 && n <= pageCount) ? n : null;
}

/// `[0,1,2,4]` → `1-3, 5` (trang 1-based, gộp các trang liên tiếp).
String formatPageRanges(List<int> pagesZeroBased) {
  if (pagesZeroBased.isEmpty) return '';
  final sorted = [...pagesZeroBased]..sort();
  final out = <String>[];
  var start = sorted.first;
  var prev = start;
  void flush() => out.add(start == prev ? '${start + 1}' : '${start + 1}-${prev + 1}');
  for (final p in sorted.skip(1)) {
    if (p == prev + 1) {
      prev = p;
    } else {
      flush();
      start = prev = p;
    }
  }
  flush();
  return out.join(', ');
}
