import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/data/db/app_database.dart';

/// Lược đồ v1 (trước khi có `document_texts`) đúng như drift đã tạo cho bản cũ.
const _v1Schema = [
  'CREATE TABLE documents (path TEXT NOT NULL, name TEXT NOT NULL, ext TEXT NOT NULL, '
      'size INTEGER NOT NULL, modified_ms INTEGER NOT NULL, folder TEXT NOT NULL, '
      'scanned_at_ms INTEGER NOT NULL, PRIMARY KEY (path))',
  'CREATE TABLE favorites (path TEXT NOT NULL, added_at_ms INTEGER NOT NULL, '
      'PRIMARY KEY (path))',
  'CREATE TABLE recents (path TEXT NOT NULL, opened_at_ms INTEGER NOT NULL, '
      'PRIMARY KEY (path))',
  'CREATE TABLE bookmarks (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      'path TEXT NOT NULL, page INTEGER NOT NULL, created_at_ms INTEGER NOT NULL)',
];

const _v1Data = [
  "INSERT INTO documents VALUES ('/a.pdf', 'a.pdf', 'pdf', 10, 1, 'Download', 1)",
  "INSERT INTO favorites VALUES ('/a.pdf', 111)",
  "INSERT INTO favorites VALUES ('/b.docx', 222)",
  "INSERT INTO recents VALUES ('/a.pdf', 333)",
  "INSERT INTO bookmarks (path, page, created_at_ms) VALUES ('/a.pdf', 4, 444)",
];

void main() {
  test('nâng v1 → v2: giữ dữ liệu cũ, có bảng document_texts', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        // Chạy trước khi drift đọc user_version: dựng sẵn một DB v1 có dữ liệu.
        setup: (raw) {
          if (raw.userVersion != 0) return;
          for (final sql in [..._v1Schema, ..._v1Data]) {
            raw.execute(sql);
          }
          raw.userVersion = 1;
        },
      ),
    );
    addTearDown(db.close);

    // Dữ liệu cũ còn nguyên.
    expect((await db.favoritesDao.getAll()).map((f) => f.path).toSet(), {
      '/a.pdf',
      '/b.docx',
    });
    expect((await db.recentsDao.getRecent()).single.openedAtMs, 333);
    expect((await db.bookmarksDao.getForPath('/a.pdf')).single.page, 4);
    expect((await db.documentsDao.getByPath('/a.pdf'))?.name, 'a.pdf');

    // Bảng mới dùng được.
    await db.documentTextsDao.upsert(
      DocumentTextsCompanion.insert(
        path: '/a.pdf',
        content: 'Hợp đồng',
        normalized: 'hop dong',
        sourceModifiedMs: 1,
        sourceSize: 10,
        extractedAtMs: 0,
      ),
    );
    expect(await db.documentTextsDao.searchPaths('hop'), ['/a.pdf']);

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 2);
  });
}
