import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/features/reader/logic/bookmark_logic.dart';

void main() {
  late AppDatabase db;
  const path = '/storage/emulated/0/Download/a.pdf';

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('togglePageBookmark: them roi go, tra ve trang thai moi', () async {
    expect(await togglePageBookmark(db.bookmarksDao, path, 4), isTrue);
    var list = await db.bookmarksDao.getForPath(path);
    expect(list.map((b) => b.page), [4]);

    expect(await togglePageBookmark(db.bookmarksDao, path, 4), isFalse);
    list = await db.bookmarksDao.getForPath(path);
    expect(list, isEmpty);
  });

  test('toggleDocumentBookmark dung page = -1 va khong dung toi trang', () async {
    await togglePageBookmark(db.bookmarksDao, path, 0);
    expect(await toggleDocumentBookmark(db.bookmarksDao, path), isTrue);
    final list = await db.bookmarksDao.getForPath(path);
    expect(list.map((b) => b.page).toSet(), {wholeDocumentPage, 0});

    expect(await toggleDocumentBookmark(db.bookmarksDao, path), isFalse);
    expect((await db.bookmarksDao.getForPath(path)).map((b) => b.page), [0]);
  });

  test('bookmark cua file khac khong lan sang', () async {
    await togglePageBookmark(db.bookmarksDao, path, 1);
    await togglePageBookmark(db.bookmarksDao, '/other.pdf', 1);
    expect(await togglePageBookmark(db.bookmarksDao, path, 1), isFalse);
    expect((await db.bookmarksDao.getForPath('/other.pdf')), hasLength(1));
  });

  group('ham thuan tren danh sach', () {
    late List<Bookmark> list;
    setUp(() async {
      await db.bookmarksDao.add(path, 7);
      await db.bookmarksDao.add(path, wholeDocumentPage);
      await db.bookmarksDao.add(path, 2);
      list = await db.bookmarksDao.getForPath(path);
    });

    test('isPageBookmarked / isDocumentBookmarked', () {
      expect(isPageBookmarked(list, 7), isTrue);
      expect(isPageBookmarked(list, 3), isFalse);
      expect(isPageBookmarked(list, wholeDocumentPage), isFalse);
      expect(isDocumentBookmarked(list), isTrue);
      expect(isDocumentBookmarked(const []), isFalse);
    });

    test('pageBookmarks chi giu trang that, tang dan', () {
      expect(pageBookmarks(list).map((b) => b.page), [2, 7]);
    });
  });
}
