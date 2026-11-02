// Kiểm thử hộp trắng A12 — app/lib/data/db/app_database.dart
// Thiết kế: test-output/whitebox/data/app_database/buoc-1..5. Tên test bắt đầu bằng mã bộ Bước 5.
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/data/db/app_database.dart';

/// Lược đồ v1 (trước khi có `document_texts`), đúng như drift tạo cho bản cũ.
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
  "INSERT INTO documents VALUES ('/b.docx', 'b.docx', 'docx', 20, 2, 'Download', 1)",
  "INSERT INTO favorites VALUES ('/a.pdf', 111)",
  "INSERT INTO favorites VALUES ('/b.docx', 222)",
  "INSERT INTO recents VALUES ('/a.pdf', 333)",
  "INSERT INTO bookmarks (path, page, created_at_ms) VALUES ('/a.pdf', 4, 444)",
  "INSERT INTO bookmarks (path, page, created_at_ms) VALUES ('/a.pdf', -1, 445)",
];

void _setupV1(dynamic db) {
  if (db.userVersion != 0) return;
  for (final sql in [..._v1Schema, ..._v1Data]) {
    db.execute(sql);
  }
  db.userVersion = 1;
}

Future<bool> _hasTable(AppDatabase db, String name) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable.withString(name)],
      )
      .get();
  return rows.isNotEmpty;
}

DocumentsCompanion _doc(String path, {String folder = 'Download'}) =>
    DocumentsCompanion.insert(
      path: path,
      name: path.split('/').last,
      ext: 'pdf',
      size: 10,
      modifiedMs: 1,
      folder: folder,
      scannedAtMs: 1,
    );

DocumentTextsCompanion _text(String path) => DocumentTextsCompanion.insert(
  path: path,
  content: 'Hợp đồng',
  normalized: 'hop dong',
  sourceModifiedMs: 1,
  sourceSize: 10,
  extractedAtMs: 0,
);

/// Đặt một dòng vào cả 5 bảng cho [path].
Future<void> _fillAll(AppDatabase db, String path) async {
  await db.documentsDao.upsert(_doc(path));
  await db.favoritesDao.add(path, at: DateTime.fromMillisecondsSinceEpoch(5));
  await db.recentsDao.touch(path, at: DateTime.fromMillisecondsSinceEpoch(6));
  await db.bookmarksDao.add(path, 2, at: DateTime.fromMillisecondsSinceEpoch(7));
  await db.documentTextsDao.upsert(_text(path));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('U1 AppDatabase([executor])', () {
    test('U1.1 executor được truyền ⇒ dùng đúng executor đó (DB trong RAM)', () async {
      final mem = NativeDatabase.memory();
      final db = AppDatabase(mem);
      addTearDown(db.close);
      // Nhánh đã đi: executor là cái được truyền vào (không phải driftDatabase).
      expect(identical(db.executor, mem), isTrue);
      await db.documentsDao.upsert(_doc('/m.pdf'));
      expect((await db.documentsDao.getAll()).single.path, '/m.pdf');
    });

    test('U1.2 executor null ⇒ file pdf_office.sqlite trong thư mục app', () async {
      final dir = Directory.systemTemp.createTempSync('wb_a12_appdir_');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return dir.path;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final db = AppDatabase();
      await db.documentsDao.upsert(_doc('/f.pdf'));
      expect((await db.documentsDao.getAll()).single.path, '/f.pdf');
      await db.close();
      // Nhánh đã đi: hỏi thư mục app qua path_provider, không phải executor truyền vào.
      expect(calls, contains('getApplicationDocumentsDirectory'));
      expect(File('${dir.path}${Platform.pathSeparator}pdf_office.sqlite').existsSync(), isTrue);
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows có thể giữ handle chậm — không ảnh hưởng kết quả.
      }
    });
  });

  group('U2 migration.onUpgrade', () {
    test('U2.1 DB v1 có dữ liệu ⇒ nâng v2: giữ nguyên dữ liệu cũ, thêm document_texts', () async {
      final dir = Directory.systemTemp.createTempSync('wb_a12_mig_');
      final file = File('${dir.path}${Platform.pathSeparator}v1.sqlite');
      var db = AppDatabase(NativeDatabase(file, setup: (r) => _setupV1(r)));

      // Dữ liệu cũ còn nguyên ở cả 4 bảng.
      expect(
        (await db.documentsDao.getAll()).map((d) => d.path).toSet(),
        {'/a.pdf', '/b.docx'},
      );
      expect(
        {for (final f in await db.favoritesDao.getAll()) f.path: f.addedAtMs},
        {'/a.pdf': 111, '/b.docx': 222},
      );
      expect((await db.recentsDao.getRecent()).single.openedAtMs, 333);
      final marks = await db.bookmarksDao.getForPath('/a.pdf');
      expect(marks.map((b) => (b.page, b.createdAtMs)).toList(), [
        (wholeDocumentPage, 445),
        (4, 444),
      ]);
      // Nhánh đã đi (from < 2 ⇒ createTable): bảng mới có, user_version = 2.
      expect(await _hasTable(db, 'document_texts'), isTrue);
      final v = await db.customSelect('PRAGMA user_version').getSingle();
      expect(v.read<int>('user_version'), 2);

      // Bảng mới dùng được; AUTOINCREMENT của bookmarks tiếp tục từ số cũ.
      await db.documentTextsDao.upsert(_text('/a.pdf'));
      expect(await db.documentTextsDao.searchPaths('hop'), ['/a.pdf']);
      final newId = await db.bookmarksDao.add('/b.docx', 0);
      expect(newId, greaterThan(marks.map((b) => b.id).reduce((a, b) => a > b ? a : b)));
      await db.close();

      // Mở lại: không nâng cấp lần nữa, dữ liệu cũ + mới vẫn còn.
      db = AppDatabase(NativeDatabase(file, setup: (r) => _setupV1(r)));
      expect((await db.favoritesDao.getAll()).length, 2);
      expect((await db.documentTextsDao.getByPath('/a.pdf'))?.content, 'Hợp đồng');
      expect((await db.bookmarksDao.getForPath('/b.docx')).single.id, newId);
      await db.close();
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows giữ handle chậm.
      }
    });

    test('U2.1b mức unit: onUpgrade(from: 1, to: 2) tạo lại document_texts', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customStatement('DROP TABLE document_texts');
      expect(await _hasTable(db, 'document_texts'), isFalse);
      await db.migration.onUpgrade(db.createMigrator(), 1, 2);
      expect(await _hasTable(db, 'document_texts'), isTrue);
    });

    test('U2.2 mức unit: onUpgrade(from: 2, to: 3) không tạo bảng', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.favoritesDao.add('/x.pdf');
      await db.customStatement('DROP TABLE document_texts');
      await db.migration.onUpgrade(db.createMigrator(), 2, 3);
      // Nhánh S: không gọi createTable ⇒ bảng vẫn vắng; bảng cũ không bị đụng.
      expect(await _hasTable(db, 'document_texts'), isFalse);
      expect(await db.favoritesDao.isFavorite('/x.pdf'), isTrue);
    });
  });

  group('U3 renamePath', () {
    late AppDatabase db;
    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await _fillAll(db, '/d/a.pdf');
      await _fillAll(db, '/d/keep.pdf');
    });
    tearDown(() => db.close());

    Future<void> expectMoved(String from, String to) async {
      expect(await db.documentsDao.getByPath(from), isNull);
      expect(await db.favoritesDao.isFavorite(from), isFalse);
      expect(await db.favoritesDao.isFavorite(to), isTrue);
      expect((await db.recentsDao.getRecent()).map((r) => r.path), contains(to));
      expect((await db.recentsDao.getRecent()).map((r) => r.path), isNot(contains(from)));
      expect(await db.bookmarksDao.getForPath(from), isEmpty);
      expect((await db.bookmarksDao.getForPath(to)).single.page, 2);
      expect(await db.documentTextsDao.getByPath(from), isNull);
      // Chữ đã trích giữ nguyên, chỉ đổi khoá.
      final t = await db.documentTextsDao.getByPath(to);
      expect((t?.content, t?.normalized), ('Hợp đồng', 'hop dong'));
      // File khác không bị đụng.
      expect(await db.favoritesDao.isFavorite('/d/keep.pdf'), isTrue);
      expect(await db.documentTextsDao.getByPath('/d/keep.pdf'), isNotNull);
    }

    test('U3.1 không truyền newName/newFolder ⇒ đổi path mọi bảng, giữ name/folder', () async {
      await db.renamePath('/d/a.pdf', '/d/b.pdf');
      final d = await db.documentsDao.getByPath('/d/b.pdf');
      expect((d?.name, d?.folder), ('a.pdf', 'Download'));
      await expectMoved('/d/a.pdf', '/d/b.pdf');
    });

    test('U3.2 có newName ⇒ đổi cả name', () async {
      await db.renamePath('/d/a.pdf', '/d/b.pdf', newName: 'b.pdf');
      final d = await db.documentsDao.getByPath('/d/b.pdf');
      expect((d?.name, d?.folder), ('b.pdf', 'Download'));
      await expectMoved('/d/a.pdf', '/d/b.pdf');
    });

    test('U3.3 có newFolder ⇒ đổi cả folder', () async {
      await db.renamePath('/d/a.pdf', '/e/a.pdf', newFolder: 'e');
      final d = await db.documentsDao.getByPath('/e/a.pdf');
      expect((d?.name, d?.folder), ('a.pdf', 'e'));
      await expectMoved('/d/a.pdf', '/e/a.pdf');
    });
  });

  test('U4.1 forgetPath ⇒ bỏ path khỏi cả 5 bảng, file khác giữ nguyên', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _fillAll(db, '/d/a.pdf');
    await _fillAll(db, '/d/keep.pdf');
    await db.forgetPath('/d/a.pdf');
    expect(await db.documentsDao.getByPath('/d/a.pdf'), isNull);
    expect(await db.favoritesDao.isFavorite('/d/a.pdf'), isFalse);
    expect((await db.recentsDao.getRecent()).map((r) => r.path), ['/d/keep.pdf']);
    expect(await db.bookmarksDao.getForPath('/d/a.pdf'), isEmpty);
    expect(await db.documentTextsDao.getByPath('/d/a.pdf'), isNull);
    expect(await db.documentTextsDao.allPaths(), {'/d/keep.pdf'});
    expect((await db.documentsDao.getAll()).single.path, '/d/keep.pdf');
  });
}
