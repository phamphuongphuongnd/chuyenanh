import 'package:drift/drift.dart';

import '../app_database.dart';

part 'bookmarks_dao.g.dart';

/// Hằng page cho "đánh dấu cả tài liệu".
const int wholeDocumentPage = -1;

@DriftAccessor(tables: [Bookmarks])
class BookmarksDao extends DatabaseAccessor<AppDatabase>
    with _$BookmarksDaoMixin {
  BookmarksDao(super.attachedDatabase);

  Stream<List<Bookmark>> watchAll() => (select(
    bookmarks,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAtMs)])).watch();

  /// Bookmark của một file, theo số trang tăng dần.
  Stream<List<Bookmark>> watchForPath(String path) =>
      (select(bookmarks)
            ..where((t) => t.path.equals(path))
            ..orderBy([(t) => OrderingTerm.asc(t.page)]))
          .watch();

  Future<List<Bookmark>> getForPath(String path) =>
      (select(bookmarks)
            ..where((t) => t.path.equals(path))
            ..orderBy([(t) => OrderingTerm.asc(t.page)]))
          .get();

  /// Thêm bookmark (trùng path+page thì không thêm). Trả về id.
  Future<int> add(String path, int page, {DateTime? at}) async {
    final existing =
        await (select(bookmarks)
              ..where((t) => t.path.equals(path) & t.page.equals(page)))
            .getSingleOrNull();
    if (existing != null) return existing.id;
    return into(bookmarks).insert(
      BookmarksCompanion.insert(
        path: path,
        page: page,
        createdAtMs: (at ?? DateTime.now()).millisecondsSinceEpoch,
      ),
    );
  }

  Future<int> removeById(int id) =>
      (delete(bookmarks)..where((t) => t.id.equals(id))).go();

  Future<int> removePage(String path, int page) => (delete(
    bookmarks,
  )..where((t) => t.path.equals(path) & t.page.equals(page))).go();

  Future<int> removeForPath(String path) =>
      (delete(bookmarks)..where((t) => t.path.equals(path))).go();
}
