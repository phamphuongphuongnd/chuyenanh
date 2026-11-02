// Kiểm thử hộp trắng A12 — app/lib/data/db/daos/bookmarks_dao.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/data/db/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('U1 BookmarksDao.add', () {
    test('U1.1 path+page mới, có at ⇒ thêm dòng, createdAtMs = at, trả id mới', () async {
      final id = await db.bookmarksDao.add(
        '/a.pdf',
        3,
        at: DateTime.fromMillisecondsSinceEpoch(1234),
      );
      final rows = await db.bookmarksDao.getForPath('/a.pdf');
      expect(rows.single.id, id);
      expect((rows.single.page, rows.single.createdAtMs), (3, 1234));
    });

    test('U1.2 trùng path+page ⇒ không thêm, trả id cũ', () async {
      final first = await db.bookmarksDao.add(
        '/a.pdf',
        3,
        at: DateTime.fromMillisecondsSinceEpoch(1),
      );
      final again = await db.bookmarksDao.add(
        '/a.pdf',
        3,
        at: DateTime.fromMillisecondsSinceEpoch(999),
      );
      final rows = await db.bookmarksDao.getForPath('/a.pdf');
      // Nhánh đã đi: existing != null ⇒ không insert (vẫn 1 dòng, giờ tạo cũ).
      expect(rows.length, 1);
      expect(rows.single.createdAtMs, 1);
      expect(again, first);
    });

    test('U1.3 không truyền at ⇒ createdAtMs = giờ hiện tại', () async {
      final before = DateTime.now().millisecondsSinceEpoch;
      await db.bookmarksDao.add('/a.pdf', wholeDocumentPage);
      final after = DateTime.now().millisecondsSinceEpoch;
      final row = (await db.bookmarksDao.getForPath('/a.pdf')).single;
      expect(row.page, -1);
      expect(row.createdAtMs, inInclusiveRange(before, after));
    });

    test('U1.1b cùng path khác page ⇒ thêm dòng thứ hai (trùng là path+page)', () async {
      await db.bookmarksDao.add('/a.pdf', 3);
      await db.bookmarksDao.add('/a.pdf', 1);
      await db.bookmarksDao.add('/b.pdf', 3);
      expect(
        (await db.bookmarksDao.getForPath('/a.pdf')).map((b) => b.page),
        [1, 3],
      );
    });
  });
}
