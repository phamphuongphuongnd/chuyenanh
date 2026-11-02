// Kiểm thử hộp trắng A12 — app/lib/data/db/daos/recents_dao.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/data/db/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('U1 RecentsDao.touch', () {
    test('U1.1 có at ⇒ openedAtMs = at; mở lại ⇒ cập nhật giờ, đưa lên đầu, không nhân đôi', () async {
      await db.recentsDao.touch('/a.pdf', at: DateTime.fromMillisecondsSinceEpoch(10));
      await db.recentsDao.touch('/b.pdf', at: DateTime.fromMillisecondsSinceEpoch(20));
      expect((await db.recentsDao.getRecent()).map((r) => r.path), ['/b.pdf', '/a.pdf']);
      await db.recentsDao.touch('/a.pdf', at: DateTime.fromMillisecondsSinceEpoch(30));
      final rows = await db.recentsDao.getRecent();
      expect(rows.map((r) => (r.path, r.openedAtMs)), [('/a.pdf', 30), ('/b.pdf', 20)]);
      expect((await db.recentsDao.getRecent(limit: 1)).single.path, '/a.pdf');
    });

    test('U1.2 không có at ⇒ openedAtMs = giờ hiện tại', () async {
      final before = DateTime.now().millisecondsSinceEpoch;
      await db.recentsDao.touch('/a.pdf');
      final after = DateTime.now().millisecondsSinceEpoch;
      expect(
        (await db.recentsDao.getRecent()).single.openedAtMs,
        inInclusiveRange(before, after),
      );
    });
  });
}
