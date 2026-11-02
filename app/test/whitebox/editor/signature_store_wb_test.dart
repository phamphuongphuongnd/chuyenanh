// Kiểm thử hộp trắng A14 — signature_store.dart.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/features/editor/signature_store.dart';

final Uint8List _png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('wb_sig_store'));
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  File put(String name, DateTime t) {
    final f = File(p.join(dir.path, name))..writeAsBytesSync(_png);
    f.setLastModifiedSync(t);
    return f;
  }

  group('U1 list', () {
    test('U1.P1 có 1 file .png ⇒ trả đúng 1 bản ghi', () async {
      final f = put('a.png', DateTime(2025));
      final all = await SignatureStore(dir).list();
      expect(all.map((e) => e.path), [f.path]);
      expect(all.single.fileName, 'a.png');
    });
    test('U1.P2 thư mục chưa có ⇒ []', () async {
      expect(await SignatureStore(Directory(p.join(dir.path, 'none'))).list(), isEmpty);
    });
    test('U1.P3 thư mục rỗng ⇒ []', () async {
      expect(await SignatureStore(dir).list(), isEmpty);
    });
    test('U1.P4 thư mục con tên x.png ⇒ bỏ qua', () async {
      Directory(p.join(dir.path, 'x.png')).createSync();
      expect(await SignatureStore(dir).list(), isEmpty);
    });
    test('U1.P5 file lạ .txt ⇒ bỏ qua; .PNG viết hoa vẫn nhận', () async {
      put('note.txt', DateTime(2025));
      final up = put('B.PNG', DateTime(2025));
      final all = await SignatureStore(dir).list();
      expect(all.map((e) => e.path), [up.path]);
    });
  });

  group('U2 so sánh', () {
    test('U2.P1 khác giờ sửa ⇒ mới nhất trước', () async {
      final old = put('z_old.png', DateTime(2020));
      final neu = put('a_new.png', DateTime(2024));
      expect((await SignatureStore(dir).list()).map((e) => e.path), [neu.path, old.path]);
    });
    test('U2.P2 trùng giờ sửa ⇒ thứ tự xác định theo tên (tên lớn trước)', () async {
      final t = DateTime(2024, 1, 1, 12);
      final a = put('signature_100.png', t);
      final b = put('signature_200.png', t);
      expect((await SignatureStore(dir).list()).map((e) => e.path), [b.path, a.path]);
    });
  });

  group('U3 save', () {
    test('U3.P1 dưới giới hạn ⇒ không xoá gì', () async {
      final s = SignatureStore(dir);
      final keep = put('old.png', DateTime(2020));
      final saved = await s.save(_png);
      expect(File(saved.path).existsSync(), isTrue);
      expect(keep.existsSync(), isTrue);
      expect(await s.list(), hasLength(2));
    });
    test('U3.P2 lưu cái thứ 13 ⇒ xoá cái cũ nhất, còn 12', () async {
      final s = SignatureStore(dir);
      final oldest = put('signature_0.png', DateTime(2000));
      for (var i = 1; i < kMaxSavedSignatures; i++) {
        put('signature_$i.png', DateTime(2010, 1, i));
      }
      expect(await s.list(), hasLength(kMaxSavedSignatures));
      final saved = await s.save(_png);
      final all = await s.list();
      expect(all, hasLength(kMaxSavedSignatures));
      expect(oldest.existsSync(), isFalse);
      expect(all.first.path, saved.path);
    });
  });

  group('U4 delete', () {
    test('U4.P1 file có ⇒ xoá', () async {
      final f = put('a.png', DateTime(2025));
      final s = SignatureStore(dir);
      await s.delete((await s.list()).single);
      expect(f.existsSync(), isFalse);
    });
    test('U4.P2 file không có ⇒ không lỗi', () async {
      final s = SignatureStore(dir);
      final ghost = SavedSignature(path: p.join(dir.path, 'ghost.png'), modified: DateTime(2020));
      await expectLater(s.delete(ghost), completes);
    });
  });
}
