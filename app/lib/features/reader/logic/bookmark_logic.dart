import '../../../data/db/app_database.dart';

/// Trang [page] (0-based) đã được đánh dấu chưa.
bool isPageBookmarked(List<Bookmark> bookmarks, int page) =>
    page != wholeDocumentPage && bookmarks.any((b) => b.page == page);

/// Cả tài liệu đã được đánh dấu chưa (`page == -1`).
bool isDocumentBookmarked(List<Bookmark> bookmarks) =>
    bookmarks.any((b) => b.page == wholeDocumentPage);

/// Chỉ các bookmark của từng trang, số trang tăng dần.
List<Bookmark> pageBookmarks(List<Bookmark> bookmarks) =>
    bookmarks.where((b) => b.page != wholeDocumentPage).toList()
      ..sort((a, b) => a.page.compareTo(b.page));

/// Đánh dấu / bỏ đánh dấu trang [page] (0-based). Trả về trạng thái **sau** khi đổi.
Future<bool> togglePageBookmark(BookmarksDao dao, String path, int page) async {
  final existing = await dao.getForPath(path);
  if (isPageBookmarked(existing, page)) {
    await dao.removePage(path, page);
    return false;
  }
  await dao.add(path, page);
  return true;
}

/// Đánh dấu / bỏ đánh dấu cả tài liệu. Trả về trạng thái **sau** khi đổi.
Future<bool> toggleDocumentBookmark(BookmarksDao dao, String path) async {
  final existing = await dao.getForPath(path);
  if (isDocumentBookmarked(existing)) {
    await dao.removePage(path, wholeDocumentPage);
    return false;
  }
  await dao.add(path, wholeDocumentPage);
  return true;
}
