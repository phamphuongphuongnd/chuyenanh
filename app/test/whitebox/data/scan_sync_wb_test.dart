// Kiểm thử hộp trắng A12 — app/lib/data/file_scanner/scan_sync.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/data/file_scanner/file_scanner.dart';
import 'package:pdf_office/data/file_scanner/scan_sync.dart';

ScannedFile _f(String path, {int size = 1}) => ScannedFile(
  path: path,
  name: path.split('/').last,
  ext: 'pdf',
  size: size,
  modifiedMs: 1000,
  folder: 'x',
);

void main() {
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await syncScanToDatabase(db, ScanResult(files: [_f('/x/old.pdf'), _f('/x/a.pdf')]), 100);
  });
  tearDown(() => db.close());

  test('U1.1 mọi gốc đọc được ⇒ upsert + xoá file không còn thấy', () async {
    await syncScanToDatabase(
      db,
      ScanResult(files: [_f('/x/a.pdf', size: 9), _f('/x/new.pdf')]),
      200,
    );
    final rows = await db.documentsDao.getAll();
    expect(rows.map((r) => r.path).toSet(), {'/x/a.pdf', '/x/new.pdf'});
    expect(rows.every((r) => r.scannedAtMs == 200), isTrue);
    expect((await db.documentsDao.getByPath('/x/a.pdf'))?.size, 9);
  });

  test('U1.2 có gốc không đọc được ⇒ chỉ upsert, không xoá bộ đệm cũ', () async {
    await syncScanToDatabase(
      db,
      ScanResult(files: [_f('/x/new.pdf')], unreadableRoots: const ['/storage/emulated/0']),
      200,
    );
    final rows = await db.documentsDao.getAll();
    expect(rows.map((r) => r.path).toSet(), {'/x/old.pdf', '/x/a.pdf', '/x/new.pdf'});
    expect((await db.documentsDao.getByPath('/x/old.pdf'))?.scannedAtMs, 100);
  });
}
