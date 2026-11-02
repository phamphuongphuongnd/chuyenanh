// Kiểm thử hộp trắng A12 — app/lib/data/db/daos/favorites_dao.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/data/db/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('U1 FavoritesDao.add', () {
    test('U1.1 có at ⇒ addedAtMs = at; thêm lại ⇒ cập nhật, không nhân đôi', () async {
      await db.favoritesDao.add('/a.pdf', at: DateTime.fromMillisecondsSinceEpoch(100));
      await db.favoritesDao.add('/b.pdf', at: DateTime.fromMillisecondsSinceEpoch(200));
      expect((await db.favoritesDao.getAll()).map((f) => f.path), ['/b.pdf', '/a.pdf']);
      await db.favoritesDao.add('/a.pdf', at: DateTime.fromMillisecondsSinceEpoch(300));
      final all = await db.favoritesDao.getAll();
      expect(all.map((f) => (f.path, f.addedAtMs)), [('/a.pdf', 300), ('/b.pdf', 200)]);
    });

    test('U1.2 không có at ⇒ addedAtMs = giờ hiện tại', () async {
      final before = DateTime.now().millisecondsSinceEpoch;
      await db.favoritesDao.add('/a.pdf');
      final after = DateTime.now().millisecondsSinceEpoch;
      expect(
        (await db.favoritesDao.getAll()).single.addedAtMs,
        inInclusiveRange(before, after),
      );
    });
  });

  group('U2 FavoritesDao.toggle', () {
    test('U2.1 chưa yêu thích ⇒ thêm, trả true', () async {
      final r = await db.favoritesDao.toggle('/a.pdf');
      expect(await db.favoritesDao.isFavorite('/a.pdf'), isTrue);
      expect(await db.favoritesDao.watchPaths().first, {'/a.pdf'});
      expect(r, isTrue);
    });

    test('U2.2 đã yêu thích ⇒ bỏ, trả false', () async {
      await db.favoritesDao.add('/a.pdf');
      await db.favoritesDao.add('/b.pdf');
      final r = await db.favoritesDao.toggle('/a.pdf');
      expect(await db.favoritesDao.isFavorite('/a.pdf'), isFalse);
      expect(await db.favoritesDao.isFavorite('/b.pdf'), isTrue);
      expect(await db.favoritesDao.watchIsFavorite('/a.pdf').first, isFalse);
      expect(r, isFalse);
    });
  });
}
