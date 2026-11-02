// Kiểm thử hộp trắng (A09 · reader) — bookmark_logic.dart.
// Bộ dữ liệu + expected chép từ test-output/whitebox/reader/bookmark_logic/buoc-5-du-lieu-thu.md.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/features/reader/logic/bookmark_logic.dart';

/// DAO thật (drift bộ nhớ) có ghi lại lời gọi để khẳng định nhánh đã đi.
class _SpyDao extends BookmarksDao {
  _SpyDao(super.attachedDatabase);
  final calls = <String>[];

  @override
  Future<int> add(String path, int page, {DateTime? at}) {
    calls.add('add($page)');
    return super.add(path, page, at: at);
  }

  @override
  Future<int> removePage(String path, int page) {
    calls.add('removePage($page)');
    return super.removePage(path, page);
  }
}

Bookmark _bm(int page) =>
    Bookmark(id: page + 100, path: '/a.pdf', page: page, createdAtMs: 0);

void main() {
  const path = '/storage/emulated/0/Download/a.pdf';
  late AppDatabase db;
  late _SpyDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = _SpyDao(db);
  });
  tearDown(() => db.close());

  group('isPageBookmarked', () {
    test('B1-1 trang 7 có trong danh sách ⇒ true', () {
      expect(isPageBookmarked([_bm(7), _bm(-1), _bm(2)], 7), isTrue);
    });
    test('B1-2 trang 3 không có (danh sách nhiều phần tử / rỗng) ⇒ false', () {
      expect(isPageBookmarked([_bm(7), _bm(-1), _bm(2)], 3), isFalse);
      expect(isPageBookmarked(const [], 0), isFalse);
      expect(isPageBookmarked([_bm(0)], 0), isTrue);
    });
    test('B1-3 page = -1 (cả tài liệu) dù có bookmark -1 ⇒ false', () {
      expect(isPageBookmarked([_bm(-1)], wholeDocumentPage), isFalse);
    });
  });

  group('togglePageBookmark', () {
    test('B2-1 trang chưa đánh dấu ⇒ add, trả true, DB có trang', () async {
      final r = await togglePageBookmark(dao, path, 4);
      expect(dao.calls, ['add(4)']);
      expect(r, isTrue);
      expect((await dao.getForPath(path)).map((b) => b.page), [4]);
    });
    test('B2-2 trang đã đánh dấu ⇒ removePage, trả false, DB mất trang, giữ bookmark cả tài liệu', () async {
      await db.bookmarksDao.add(path, 4);
      await db.bookmarksDao.add(path, wholeDocumentPage);
      final r = await togglePageBookmark(dao, path, 4);
      expect(dao.calls, ['removePage(4)']);
      expect(r, isFalse);
      expect((await dao.getForPath(path)).map((b) => b.page), [wholeDocumentPage]);
    });
  });

  group('toggleDocumentBookmark', () {
    test('B3-1 chưa đánh dấu cả tài liệu ⇒ add(-1), trả true', () async {
      await db.bookmarksDao.add(path, 0);
      final r = await toggleDocumentBookmark(dao, path);
      expect(dao.calls, ['add(-1)']);
      expect(r, isTrue);
      expect((await dao.getForPath(path)).map((b) => b.page).toSet(), {wholeDocumentPage, 0});
    });
    test('B3-2 đã đánh dấu cả tài liệu ⇒ removePage(-1), trả false, giữ trang 0', () async {
      await db.bookmarksDao.add(path, 0);
      await db.bookmarksDao.add(path, wholeDocumentPage);
      final r = await toggleDocumentBookmark(dao, path);
      expect(dao.calls, ['removePage(-1)']);
      expect(r, isFalse);
      expect((await dao.getForPath(path)).map((b) => b.page), [0]);
    });
  });
}
