// Kiểm thử hộp trắng A12 — app/lib/data/db/tables.dart (khai báo bảng, không rẽ nhánh)
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/data/db/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// cột → (kiểu, notnull, pk) theo PRAGMA table_info.
  Future<Map<String, (String, int, int)>> info(String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return {
      for (final r in rows)
        r.read<String>('name'): (
          r.read<String>('type'),
          r.read<int>('notnull'),
          r.read<int>('pk'),
        ),
    };
  }

  test('U1.1 lược đồ 5 bảng đúng cột, khoá chính, NOT NULL', () async {
    expect(await info('documents'), {
      'path': ('TEXT', 1, 1),
      'name': ('TEXT', 1, 0),
      'ext': ('TEXT', 1, 0),
      'size': ('INTEGER', 1, 0),
      'modified_ms': ('INTEGER', 1, 0),
      'folder': ('TEXT', 1, 0),
      'scanned_at_ms': ('INTEGER', 1, 0),
    });
    expect(await info('favorites'), {
      'path': ('TEXT', 1, 1),
      'added_at_ms': ('INTEGER', 1, 0),
    });
    expect(await info('recents'), {
      'path': ('TEXT', 1, 1),
      'opened_at_ms': ('INTEGER', 1, 0),
    });
    expect(await info('bookmarks'), {
      'id': ('INTEGER', 1, 1),
      'path': ('TEXT', 1, 0),
      'page': ('INTEGER', 1, 0),
      'created_at_ms': ('INTEGER', 1, 0),
    });
    expect(await info('document_texts'), {
      'path': ('TEXT', 1, 1),
      'content': ('TEXT', 1, 0),
      'normalized': ('TEXT', 1, 0),
      'source_modified_ms': ('INTEGER', 1, 0),
      'source_size': ('INTEGER', 1, 0),
      'extracted_at_ms': ('INTEGER', 1, 0),
    });
  });

  test('U1.1b document_texts: dòng content rỗng được lưu; path là khoá (ghi đè, không nhân đôi)', () async {
    final dao = db.documentTextsDao;
    await dao.upsert(
      DocumentTextsCompanion.insert(
        path: '/locked.pdf',
        content: '',
        normalized: '',
        sourceModifiedMs: 1,
        sourceSize: 2,
        extractedAtMs: 3,
      ),
    );
    expect((await dao.getByPath('/locked.pdf'))?.content, '');
    await dao.upsert(
      DocumentTextsCompanion.insert(
        path: '/locked.pdf',
        content: 'Có chữ',
        normalized: 'co chu',
        sourceModifiedMs: 9,
        sourceSize: 2,
        extractedAtMs: 4,
      ),
    );
    expect(await dao.allPaths(), {'/locked.pdf'});
    expect((await dao.getByPath('/locked.pdf'))?.sourceModifiedMs, 9);
  });

  test('U1.1c bookmarks: id tự tăng; documents thiếu cột bắt buộc ⇒ lỗi', () async {
    final a = await db.bookmarksDao.add('/a.pdf', 0);
    final b = await db.bookmarksDao.add('/a.pdf', 1);
    expect(b, greaterThan(a));
    Object? r = 'ok';
    try {
      await db
          .into(db.documents)
          .insert(const DocumentsCompanion(path: Value('/x.pdf')));
    } catch (e) {
      r = e;
    }
    expect(r, isNot('ok'));
  });
}
