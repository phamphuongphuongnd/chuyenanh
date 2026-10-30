// Biến khối tài liệu dựng lại từ PDF (`rebuildDocument`) thành danh sách dòng hiển thị của chế độ
// đọc dàn chữ + danh sách đoạn chữ cho đọc to / dịch. Thuần Dart, chạy được trong isolate.
import 'package:pdf_layout/pdf_layout.dart';

import '../../convert/text/vietnamese_nfc.dart';

/// Loại một dòng trong màn đọc dàn chữ.
enum ReflowKind {
  heading,
  paragraph,
  listItem,

  /// Một hàng của bảng, các ô nối thành một dòng chữ.
  tableRow,

  /// Ngăn trang "— Trang n —".
  pageMarker,

  /// Trang không có chữ (ảnh quét) giữa các trang có chữ.
  imagePage,
}

/// Một dòng hiển thị. [text] là chữ hiện ra và chữ để tìm (vị trí kết quả tìm tính trên [text]).
class ReflowItem {
  const ReflowItem({
    required this.kind,
    required this.page,
    this.text = '',
    this.level = 0,
    this.marker = '',
    this.ordered = false,
    this.bold = false,
    this.cells = const [],
  });

  final ReflowKind kind;

  /// Trang nguồn, 0-based.
  final int page;
  final String text;

  /// Cấp tiêu đề 1..3 (chỉ [ReflowKind.heading]).
  final int level;

  /// Dấu đầu dòng gốc (`•`, `1.`, `a)`…) của [ReflowKind.listItem].
  final String marker;
  final bool ordered;

  /// Cả đoạn in đậm.
  final bool bold;

  /// Các ô (đã làm sạch) của [ReflowKind.tableRow].
  final List<String> cells;

  /// Dòng có chữ đọc được (đọc to / dịch / tìm)?
  bool get hasText =>
      kind != ReflowKind.pageMarker && kind != ReflowKind.imagePage;

  /// Chữ đưa cho đọc to / dịch: bảng nối ô bằng dấu phẩy, danh sách đánh số giữ số thứ tự.
  String get speech => switch (kind) {
    ReflowKind.tableRow => cells.join(', '),
    ReflowKind.listItem when ordered => '$marker $text',
    _ => text,
  };

  @override
  String toString() => 'ReflowItem($kind, p$page, "$text")';
}

/// Kết quả dàn chữ: các dòng hiển thị + danh sách đoạn (chỉ dòng có chữ) cho đọc to / dịch.
class ReflowDocument {
  factory ReflowDocument({
    required List<ReflowItem> items,
    required int pageCount,
  }) {
    final idx = [
      for (var i = 0; i < items.length; i++)
        if (items[i].hasText) i,
    ];
    return ReflowDocument._(items, pageCount, idx, [
      for (final i in idx) items[i].speech,
    ]);
  }

  const ReflowDocument._(
    this.items,
    this.pageCount,
    this.paragraphItems,
    this.paragraphs,
  );

  /// Tài liệu không có chữ nào (PDF quét).
  const ReflowDocument.empty({this.pageCount = 0})
    : items = const [],
      paragraphItems = const [],
      paragraphs = const [];

  final List<ReflowItem> items;
  final int pageCount;

  /// `paragraphs[k]` là chữ của `items[paragraphItems[k]]`.
  final List<int> paragraphItems;
  final List<String> paragraphs;

  bool get hasText => paragraphs.isNotEmpty;

  /// Chữ hiển thị từng dòng (đầu vào cho tìm kiếm).
  List<String> get itemTexts => [for (final i in items) i.text];

  /// Dòng hiển thị của đoạn thứ [paragraph]; ngoài khoảng → null.
  int? itemOfParagraph(int paragraph) =>
      paragraph < 0 || paragraph >= paragraphItems.length
      ? null
      : paragraphItems[paragraph];

  /// Dòng đầu tiên của trang [page] (0-based; ngăn trang nếu có). Ngoài khoảng → kẹp về trang gần nhất.
  int firstItemOfPage(int page) {
    if (items.isEmpty) return 0;
    for (var i = 0; i < items.length; i++) {
      if (items[i].page >= page) return i;
    }
    return items.length - 1;
  }

  /// Các đoạn thuộc trang [page] (0-based).
  List<String> paragraphsOfPage(int page) => [
    for (final i in paragraphItems)
      if (items[i].page == page) items[i].speech,
  ];

  /// Các đoạn nằm trong dòng hiển thị [first]..[last] (gồm cả hai đầu).
  List<String> paragraphsInRange(int first, int last) => [
    for (final i in paragraphItems)
      if (i >= first && i <= last) items[i].speech,
  ];
}

final _spaces = RegExp(r'\s+');

/// Gộp khoảng trắng, bỏ đầu/cuối, gộp dấu tiếng Việt rời (NFD → NFC).
String cleanReflowText(String s) =>
    composeVietnamese(s.replaceAll(_spaces, ' ').trim());

bool _allBold(List<DocSpan> spans) {
  final visible = spans.where((s) => s.text.trim().isNotEmpty);
  return visible.isNotEmpty && visible.every((s) => s.bold);
}

/// Dàn các khối [blocks] thành dòng hiển thị. Mỗi [DocPageBreak] sang trang mới; tài liệu nhiều
/// trang có ngăn "— Trang n —" ở đầu mỗi trang, trang không có chữ thêm dòng [ReflowKind.imagePage].
ReflowDocument buildReflowDocument(List<DocBlock> blocks) {
  if (blocks.isEmpty) return const ReflowDocument.empty();
  final pageCount = 1 + blocks.whereType<DocPageBreak>().length;
  final multiPage = pageCount > 1;
  final items = <ReflowItem>[];
  var page = 0;
  var pageHasText = false;

  void startPage() {
    pageHasText = false;
    if (multiPage) {
      items.add(ReflowItem(kind: ReflowKind.pageMarker, page: page));
    }
  }

  void endPage() {
    if (multiPage && !pageHasText) {
      items.add(ReflowItem(kind: ReflowKind.imagePage, page: page));
    }
  }

  void add(ReflowItem item) {
    if (item.text.isEmpty) return;
    items.add(item);
    pageHasText = true;
  }

  startPage();
  for (final b in blocks) {
    switch (b) {
      case DocPageBreak():
        endPage();
        page++;
        startPage();
      case DocHeading():
        add(
          ReflowItem(
            kind: ReflowKind.heading,
            page: page,
            text: cleanReflowText(b.text),
            level: b.level.clamp(1, 3),
            bold: true,
          ),
        );
      case DocParagraph():
        add(
          ReflowItem(
            kind: ReflowKind.paragraph,
            page: page,
            text: cleanReflowText(b.text),
            bold: _allBold(b.spans),
          ),
        );
      case DocListItem():
        add(
          ReflowItem(
            kind: ReflowKind.listItem,
            page: page,
            text: cleanReflowText(b.text),
            marker: b.marker.trim().isEmpty ? '•' : b.marker.trim(),
            ordered: b.ordered,
          ),
        );
      case DocTable():
        for (final row in b.cells) {
          final cells = [
            for (final c in row)
              if (cleanReflowText(c).isNotEmpty) cleanReflowText(c),
          ];
          if (cells.isEmpty) continue;
          add(
            ReflowItem(
              kind: ReflowKind.tableRow,
              page: page,
              text: cells.join(' · '),
              cells: cells,
            ),
          );
        }
    }
  }
  endPage();
  if (!items.any((i) => i.hasText)) {
    return ReflowDocument.empty(pageCount: pageCount);
  }
  return ReflowDocument(items: items, pageCount: pageCount);
}

/// Danh sách đoạn chữ (cho đọc to / dịch) của các khối [blocks]: tiêu đề, đoạn văn, mục danh sách,
/// mỗi hàng bảng một đoạn; bỏ ngăn trang và khối rỗng.
List<String> reflowParagraphs(List<DocBlock> blocks) =>
    buildReflowDocument(blocks).paragraphs;
