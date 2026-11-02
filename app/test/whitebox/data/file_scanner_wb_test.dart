// Kiểm thử hộp trắng A12 — app/lib/data/file_scanner/file_scanner.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/data/file_scanner/file_scanner.dart';

void _touch(String path, [int bytes = 3]) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(List.filled(bytes, 65));
}

void main() {
  final temps = <Directory>[];
  Directory tmp() {
    final d = Directory.systemTemp.createTempSync('wb_a12_scan_');
    temps.add(d);
    return d;
  }

  tearDown(() {
    for (final d in temps) {
      try {
        d.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows giữ handle chậm.
      }
    }
    temps.clear();
  });

  Set<String> names(ScanResult r) => r.files.map((f) => f.name).toSet();

  group('U1 shouldSkipDirectory', () {
    test('U1.1 thư mục thường ⇒ false', () {
      expect(shouldSkipDirectory('/storage/emulated/0/Download'), isFalse);
      expect(shouldSkipDirectory('/storage/emulated/0/Android/media'), isFalse);
    });
    test('U1.2 đường dẫn không có tên (chỉ "/") ⇒ false', () {
      expect(shouldSkipDirectory('/'), isFalse);
    });
    test('U1.3 thư mục ẩn (bắt đầu ".") ⇒ true', () {
      expect(shouldSkipDirectory('/storage/emulated/0/.thumbnails'), isTrue);
    });
    test('U1.4 Android/data (mọi kiểu chữ, cả "\\") ⇒ true', () {
      expect(shouldSkipDirectory('/storage/emulated/0/Android/data'), isTrue);
      expect(shouldSkipDirectory(r'C:\X\ANDROID\DATA'), isTrue);
    });
    test('U1.5 Android/obb ⇒ true', () {
      expect(shouldSkipDirectory('/storage/emulated/0/Android/obb'), isTrue);
    });
  });

  group('U2 scanRoots', () {
    test('U2.1 một file PDF, có onProgress ⇒ 1 ScannedFile đủ thông tin, tiến độ cuối = 1', () async {
      final r = tmp();
      _touch(p.join(r.path, 'a.pdf'), 10);
      _touch(p.join(r.path, 'B.DOCX'), 4);
      final progress = <int>[];
      final res = await scanRoots([r.path], onProgress: progress.add);
      final a = res.files.firstWhere((f) => f.name == 'a.pdf');
      expect(a.path, p.join(r.path, 'a.pdf'));
      expect((a.ext, a.size, a.folder), ('pdf', 10, p.basename(r.path)));
      expect(
        a.modifiedMs,
        File(a.path).statSync().modified.millisecondsSinceEpoch,
      );
      expect(res.files.firstWhere((f) => f.name == 'B.DOCX').ext, 'docx');
      expect(progress, [2]);
      expect(res.allRootsReadable, isTrue);
      expect(res.skippedDirectories, 0);
    });

    test('U2.2 không có thư mục gốc nào, có onProgress ⇒ rỗng, báo tiến độ 0', () async {
      final progress = <int>[];
      final res = await scanRoots(const [], onProgress: progress.add);
      expect(res.files, isEmpty);
      expect(progress, [0]);
      expect(res.allRootsReadable, isTrue);
    });

    test('U2.3 không có gốc, không onProgress ⇒ rỗng, không lỗi', () async {
      final res = await scanRoots(const []);
      expect(res.files, isEmpty);
    });

    test('U2.4 gốc không tồn tại ⇒ vào unreadableRoots, không dừng', () async {
      final r = tmp();
      final missing = p.join(r.path, 'khong_co');
      _touch(p.join(r.path, 'ok.pdf'));
      final res = await scanRoots([missing, r.path]);
      expect(res.unreadableRoots, [missing]);
      expect(res.allRootsReadable, isFalse);
      expect(names(res), {'ok.pdf'});
      expect(res.skippedDirectories, 0);
    });

    test('U2.5 thư mục con lỗi khi liệt kê ⇒ bỏ thư mục đó, đếm skippedDirectories', () async {
      final r = tmp();
      final sub = Directory(p.join(r.path, '0sub'))..createSync();
      for (var i = 0; i < 50; i++) {
        _touch(p.join(r.path, 'f${i.toString().padLeft(2, '0')}.pdf'));
      }
      // Giả lập thư mục con không đọc được: xoá nó trước khi tới lượt liệt kê.
      final res = await scanRoots(
        [r.path],
        onProgress: (n) {
          if (n == 50 && sub.existsSync()) sub.deleteSync(recursive: true);
        },
      );
      expect(res.skippedDirectories, 1);
      expect(res.unreadableRoots, isEmpty);
      expect(res.files.length, 50);
    });

    test('U2.6 thư mục gốc rỗng ⇒ rỗng', () async {
      final r = tmp();
      final progress = <int>[];
      final res = await scanRoots([r.path], onProgress: progress.add);
      expect(res.files, isEmpty);
      expect(progress, [0]);
      expect(res.allRootsReadable, isTrue);
    });

    test('U2.7 symlink/junction ⇒ không đi theo', () async {
      final r = tmp();
      final outside = tmp();
      _touch(p.join(outside.path, 'x.pdf'));
      _touch(p.join(r.path, 'a.pdf'));
      Link(p.join(r.path, 'jn')).createSync(outside.path);
      // Điều kiện dựng: hệ điều hành báo mục này là Link.
      expect(
        FileSystemEntity.typeSync(p.join(r.path, 'jn'), followLinks: false),
        FileSystemEntityType.link,
      );
      final res = await scanRoots([r.path]);
      expect(names(res), {'a.pdf'});
    });

    test('U2.8 thư mục con thường ⇒ quét đệ quy', () async {
      final r = tmp();
      _touch(p.join(r.path, 'sub', 'deep', 'b.txt'));
      final res = await scanRoots([r.path]);
      expect(names(res), {'b.txt'});
      expect(res.files.single.folder, 'deep');
    });

    test('U2.9 thư mục ẩn / Android/data ⇒ bỏ qua', () async {
      final r = tmp();
      _touch(p.join(r.path, '.hidden', 'c.pdf'));
      _touch(p.join(r.path, 'Android', 'data', 'com.x', 'd.pdf'));
      _touch(p.join(r.path, 'Android', 'media', 'e.pdf'));
      final res = await scanRoots([r.path]);
      expect(names(res), {'e.pdf'});
    });

    test('U2.11 file ẩn ⇒ bỏ qua', () async {
      final r = tmp();
      _touch(p.join(r.path, '.e.pdf'));
      expect((await scanRoots([r.path])).files, isEmpty);
    });

    test('U2.12 đuôi không phải tài liệu / không đuôi ⇒ bỏ qua', () async {
      final r = tmp();
      _touch(p.join(r.path, 'c.jpg'));
      _touch(p.join(r.path, 'noext'));
      expect((await scanRoots([r.path])).files, isEmpty);
    });

    test('U2.14 đủ 50 file, có onProgress ⇒ báo tiến độ ở 50 và cuối lượt', () async {
      final r = tmp();
      for (var i = 0; i < 50; i++) {
        _touch(p.join(r.path, 'f$i.pdf'));
      }
      final progress = <int>[];
      final res = await scanRoots([r.path], onProgress: progress.add);
      expect(progress, [50, 50]);
      expect(res.files.length, 50);
    });

    test('U2.15 đủ 50 file, không onProgress ⇒ vẫn đủ 50 file, không lỗi', () async {
      final r = tmp();
      for (var i = 0; i < 50; i++) {
        _touch(p.join(r.path, 'f$i.pdf'));
      }
      expect((await scanRoots([r.path])).files.length, 50);
    });

    test('U2.16 hai thư mục gốc ⇒ gộp file cả hai', () async {
      final r1 = tmp();
      final r2 = tmp();
      _touch(p.join(r1.path, 'a.pdf'));
      _touch(p.join(r2.path, 'b.xlsx'));
      final res = await scanRoots([r1.path, r2.path]);
      expect(names(res), {'a.pdf', 'b.xlsx'});
      expect(res.allRootsReadable, isTrue);
    });
  });

  group('U3/U4/U5 scanInIsolate (+ listener, _scanEntry)', () {
    test('U3.1 / U4.1 / U4.3 / U5.1 quét trong isolate: nhận tiến độ rồi kết quả', () async {
      final r = tmp();
      for (var i = 0; i < 50; i++) {
        _touch(p.join(r.path, 'f$i.pdf'));
      }
      _touch(p.join(r.path, 'x.jpg'));
      final progress = <int>[];
      final res = await scanInIsolate([r.path], onProgress: progress.add);
      // Nhánh đã đi: thông điệp int ⇒ onProgress; ScanResult ⇒ hoàn tất.
      expect(progress, [50, 50]);
      expect(res.files.length, 50);
      expect(res.allRootsReadable, isTrue);
      // IsolateFileScanner dùng cùng đường.
      final viaClass = await const IsolateFileScanner().scan([r.path]);
      expect(viaClass.files.length, 50);
    });

    test('U4.2 onProgress null ⇒ bỏ qua thông điệp tiến độ, vẫn trả kết quả', () async {
      final r = tmp();
      _touch(p.join(r.path, 'a.pdf'));
      final res = await scanInIsolate([r.path]);
      expect(names(res), {'a.pdf'});
    });

    test('U4.1b gốc không đọc được trong isolate ⇒ kết quả có unreadableRoots (không ném)', () async {
      final r = tmp();
      final missing = p.join(r.path, 'nope');
      final res = await scanInIsolate([missing]);
      expect(res.unreadableRoots, [missing]);
    });
  });
}
