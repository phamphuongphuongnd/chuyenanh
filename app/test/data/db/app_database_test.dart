import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/data/db/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  DocumentsCompanion doc(String path, {int scannedAt = 1}) =>
      DocumentsCompanion.insert(
        path: path,
        name: path.split('/').last,
        ext: 'pdf',
        size: 10,
        modifiedMs: 1,
        folder: 'Download',
        scannedAtMs: scannedAt,
      );

  test('documents upsert + xoá file không còn thấy', () async {
    await db.documentsDao.upsertAll([
      doc('/a.pdf'),
      doc('/b.pdf', scannedAt: 5),
    ]);
    expect((await db.documentsDao.getAll()).length, 2);
    await db.documentsDao.deleteNotSeenSince(5);
    final rest = await db.documentsDao.getAll();
    expect(rest.map((d) => d.path), ['/b.pdf']);
  });

  test('favorites toggle', () async {
    expect(await db.favoritesDao.toggle('/a.pdf'), isTrue);
    expect(await db.favoritesDao.isFavorite('/a.pdf'), isTrue);
    expect(await db.favoritesDao.toggle('/a.pdf'), isFalse);
  });

  test('recents touch cập nhật thứ tự', () async {
    await db.recentsDao.touch('/a.pdf', at: DateTime(2026, 1, 1));
    await db.recentsDao.touch('/b.pdf', at: DateTime(2026, 1, 2));
    await db.recentsDao.touch('/a.pdf', at: DateTime(2026, 1, 3));
    final r = await db.recentsDao.getRecent();
    expect(r.map((e) => e.path), ['/a.pdf', '/b.pdf']);
  });

  test('bookmarks không trùng path+page', () async {
    final id1 = await db.bookmarksDao.add('/a.pdf', 3);
    final id2 = await db.bookmarksDao.add('/a.pdf', 3);
    await db.bookmarksDao.add('/a.pdf', wholeDocumentPage);
    expect(id1, id2);
    final list = await db.bookmarksDao.getForPath('/a.pdf');
    expect(list.map((b) => b.page), [wholeDocumentPage, 3]);
  });

  test('renamePath và forgetPath cập nhật mọi bảng', () async {
    await db.documentsDao.upsert(doc('/a.pdf'));
    await db.favoritesDao.add('/a.pdf');
    await db.recentsDao.touch('/a.pdf');
    await db.bookmarksDao.add('/a.pdf', 1);

    await db.renamePath('/a.pdf', '/b.pdf', newName: 'b.pdf');
    expect((await db.documentsDao.getByPath('/b.pdf'))?.name, 'b.pdf');
    expect(await db.favoritesDao.isFavorite('/b.pdf'), isTrue);
    expect((await db.recentsDao.getRecent()).single.path, '/b.pdf');
    expect((await db.bookmarksDao.getForPath('/b.pdf')).length, 1);

    await db.forgetPath('/b.pdf');
    expect(await db.documentsDao.getByPath('/b.pdf'), isNull);
    expect(await db.favoritesDao.isFavorite('/b.pdf'), isFalse);
    expect(await db.recentsDao.getRecent(), isEmpty);
    expect(await db.bookmarksDao.getForPath('/b.pdf'), isEmpty);
  });

  test('watch stream phát lại khi đổi', () async {
    final stream = db.favoritesDao.watchPaths();
    final expectation = expectLater(
      stream,
      emitsInOrder([
        <String>{},
        {'/x.pdf'},
      ]),
    );
    await Future<void>.delayed(Duration.zero);
    await db.favoritesDao.add('/x.pdf');
    await expectation;
  });
}
