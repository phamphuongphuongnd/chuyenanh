import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// Một mục trong mục lục (outline) PDF, đã dàn phẳng.
class OutlineEntry {
  const OutlineEntry({
    required this.title,
    required this.depth,
    required this.bookmark,
    this.pageNumber,
  });

  final String title;

  /// 0 = mục gốc, 1 = con, …
  final int depth;

  /// Trang đích, đánh số từ 1; null nếu không xác định được.
  final int? pageNumber;

  /// Dùng với `PdfViewerController.jumpToBookmark`.
  final sf.PdfBookmark bookmark;
}

/// Dàn phẳng cây mục lục của [document] (duyệt theo thứ tự đọc).
List<OutlineEntry> flattenOutline(sf.PdfDocument document) {
  final out = <OutlineEntry>[];

  int? pageOf(sf.PdfBookmark b) {
    try {
      final page = b.destination?.page;
      if (page == null) return null;
      final index = document.pages.indexOf(page);
      return index < 0 ? null : index + 1;
    } catch (_) {
      return null;
    }
  }

  void walk(sf.PdfBookmarkBase node, int depth) {
    for (var i = 0; i < node.count; i++) {
      final b = node[i];
      out.add(
        OutlineEntry(
          title: b.title.trim().isEmpty ? '—' : b.title.trim(),
          depth: depth,
          pageNumber: pageOf(b),
          bookmark: b,
        ),
      );
      walk(b, depth + 1);
    }
  }

  try {
    walk(document.bookmarks, 0);
  } catch (_) {
    // Mục lục hỏng: bỏ qua, vẫn đọc được tài liệu.
  }
  return out;
}
