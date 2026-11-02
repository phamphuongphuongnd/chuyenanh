// Kiểm thử hộp trắng A12 — app/lib/data/db/daos/documents_dao.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/data/db/app_database.dart';

DocumentsCompanion _doc(String path, String ext, int modified) =>
    DocumentsCompanion.insert(
      path: path,
      name: path.split('/').last,
      ext: ext,
      size: 1,
      modifiedMs: modified,
      folder: 'd',
      scannedAtMs: 1,
    );

void main() {
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.documentsDao.upsertAll([
      _doc('/old.pdf', 'pdf', 10),
      _doc('/mid.docx', 'docx', 20),
      _doc('/new.pdf', 'pdf', 30),
    ]);
  });
  tearDown(() => db.close());

  group('U1 DocumentsDao._query (qua getAll/watchAll)', () {
    test('U1.1 exts null ⇒ mọi tài liệu, mới sửa trước', () async {
      final all = await db.documentsDao.getAll();
      expect(all.map((d) => d.path), ['/new.pdf', '/mid.docx', '/old.pdf']);
      final watched = await db.documentsDao.watchAll().first;
      expect(watched.map((d) => d.path), ['/new.pdf', '/mid.docx', '/old.pdf']);
    });

    test('U1.2 exts {pdf} ⇒ chỉ PDF, mới sửa trước', () async {
      final pdf = await db.documentsDao.getAll(exts: {'pdf'});
      expect(pdf.map((d) => d.path), ['/new.pdf', '/old.pdf']);
      final watched = await db.documentsDao.watchAll(exts: {'docx'}).first;
      expect(watched.map((d) => d.path), ['/mid.docx']);
    });

    test('U1.2b exts rỗng ⇒ không file nào khớp', () async {
      expect(await db.documentsDao.getAll(exts: {}), isEmpty);
    });
  });
}
