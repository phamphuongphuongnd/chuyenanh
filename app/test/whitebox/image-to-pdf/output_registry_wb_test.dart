// Kiểm thử hộp trắng (A06) — services/output_registry.dart. Mã bộ = buoc-5-du-lieu-thu.md của output_registry.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/features/image_to_pdf/services/output_registry.dart';

void main() {
  late Directory tmp;
  late AppDatabase db;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('wb_a06_reg');
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  group('U1 renameOutputDocument', () {
    test('1-1 đặt đúng tên cũ ⇒ giữ nguyên đường dẫn, file và DB không đổi', () async {
      final a = p.join(tmp.path, 'a.pdf');
      File(a).writeAsBytesSync([1]);
      await registerOutputDocument(db, a);
      final r = await renameOutputDocument(db, a, 'a');
      expect(r, a);
      expect(File(a).existsSync(), isTrue);
      expect(File(p.join(tmp.path, 'a (1).pdf')).existsSync(), isFalse);
      expect((await db.documentsDao.getByPath(a))!.name, 'a.pdf');
    });
    test('1-2 tên mới ⇒ đổi file thật cùng thư mục và cập nhật DB', () async {
      final a = p.join(tmp.path, 'a.pdf');
      File(a).writeAsBytesSync([1]);
      await registerOutputDocument(db, a);
      final r = await renameOutputDocument(db, a, 'Báo cáo');
      expect(r, p.join(tmp.path, 'Báo cáo.pdf'));
      expect(File(a).existsSync(), isFalse);
      expect(File(r).readAsBytesSync(), [1]);
      expect(await db.documentsDao.getByPath(a), isNull);
      expect((await db.documentsDao.getByPath(r))!.name, 'Báo cáo.pdf');
    });
    test('1-3 (bổ sung) tên mới trùng file khác ⇒ thêm (1), không đè', () async {
      final a = p.join(tmp.path, 'a.pdf');
      final b = p.join(tmp.path, 'b.pdf');
      File(a).writeAsBytesSync([1]);
      File(b).writeAsBytesSync([2]);
      await registerOutputDocument(db, a);
      final r = await renameOutputDocument(db, a, 'b');
      expect(p.basename(r), 'b (1).pdf');
      expect(File(b).readAsBytesSync(), [2]);
    });
  });
}
