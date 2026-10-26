import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/data/file_scanner/file_scanner.dart';
import 'package:pdf_office/data/file_scanner/scan_sync.dart';

void _touch(String path, [int bytes = 3]) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(List.filled(bytes, 65));
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('scan_test_');
    _touch(p.join(root.path, 'a.pdf'), 10);
    _touch(p.join(root.path, 'b.DOCX'));
    _touch(p.join(root.path, 'c.jpg'));
    _touch(p.join(root.path, 'noext'));
    _touch(p.join(root.path, '.e.pdf'));
    _touch(p.join(root.path, '.hidden', 'd.pdf'));
    _touch(p.join(root.path, 'Android', 'data', 'com.x', 'f.pdf'));
    _touch(p.join(root.path, 'Android', 'obb', 'g.pdf'));
    _touch(p.join(root.path, 'Android', 'media', 'h.pdf'));
    _touch(p.join(root.path, 'sub', 'deep', 'i.txt'));
  });

  tearDown(() {
    root.deleteSync(recursive: true);
  });

  test('shouldSkipDirectory', () {
    expect(shouldSkipDirectory('/storage/emulated/0/.thumbnails'), isTrue);
    expect(shouldSkipDirectory('/storage/emulated/0/Android/data'), isTrue);
    expect(shouldSkipDirectory('/storage/emulated/0/Android/obb'), isTrue);
    expect(
      shouldSkipDirectory('/storage/emulated/0/Android/data/com.a/files'),
      isTrue,
    );
    expect(shouldSkipDirectory('/storage/emulated/0/Android/media'), isFalse);
    expect(shouldSkipDirectory('/storage/emulated/0/Download'), isFalse);
    expect(shouldSkipDirectory(r'C:\x\Android\data'), isTrue);
  });

  test(
    'scanRoots: chỉ lấy đuôi tài liệu, bỏ ẩn / Android/data / obb',
    () async {
      final progress = <int>[];
      final result = await scanRoots([root.path], onProgress: progress.add);
      final names = result.files.map((f) => f.name).toSet();
      expect(names, {'a.pdf', 'b.DOCX', 'h.pdf', 'i.txt'});
      expect(result.allRootsReadable, isTrue);

      final a = result.files.firstWhere((f) => f.name == 'a.pdf');
      expect(a.ext, 'pdf');
      expect(a.size, 10);
      expect(a.folder, p.basename(root.path));
      expect(a.path, p.join(root.path, 'a.pdf'));
      final b = result.files.firstWhere((f) => f.name == 'b.DOCX');
      expect(b.ext, 'docx');
      expect(progress.last, 4);
    },
  );

  test('scanRoots: thư mục gốc không tồn tại → unreadableRoots', () async {
    final missing = p.join(root.path, 'khong_co');
    final result = await scanRoots([missing, root.path]);
    expect(result.unreadableRoots, [missing]);
    expect(result.allRootsReadable, isFalse);
    expect(result.files, isNotEmpty);
  });

  test('scanRoots: không theo symlink (nếu máy cho tạo)', () async {
    try {
      Link(p.join(root.path, 'sub', 'loop')).createSync(root.path);
    } on FileSystemException {
      return; // Windows không có quyền tạo symlink — bỏ qua.
    }
    final result = await scanRoots([root.path]);
    expect(result.files.map((f) => f.name).toSet(), {
      'a.pdf',
      'b.DOCX',
      'h.pdf',
      'i.txt',
    });
  });

  test('scanInIsolate trả cùng kết quả', () async {
    final progress = <int>[];
    final result = await scanInIsolate([root.path], onProgress: progress.add);
    expect(result.files.length, 4);
    expect(progress, isNotEmpty);
  });

  group('syncScanToDatabase', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    ScannedFile file(String path, {int size = 1}) => ScannedFile(
      path: path,
      name: p.basename(path),
      ext: 'pdf',
      size: size,
      modifiedMs: 1000,
      folder: 'dir',
    );

    test('thêm mới, cập nhật và xoá file không còn thấy', () async {
      await syncScanToDatabase(
        db,
        ScanResult(files: [file('/x/a.pdf'), file('/x/b.pdf')]),
        100,
      );
      expect((await db.documentsDao.getAll()).length, 2);

      await syncScanToDatabase(
        db,
        ScanResult(files: [file('/x/a.pdf', size: 99)]),
        200,
      );
      final rows = await db.documentsDao.getAll();
      expect(rows.map((r) => r.path), ['/x/a.pdf']);
      expect(rows.single.size, 99);
      expect(rows.single.scannedAtMs, 200);
    });

    test('thiếu quyền (root không đọc được) thì không xoá bộ đệm', () async {
      await syncScanToDatabase(db, ScanResult(files: [file('/x/a.pdf')]), 100);
      await syncScanToDatabase(
        db,
        const ScanResult(files: [], unreadableRoots: ['/storage/emulated/0']),
        200,
      );
      expect((await db.documentsDao.getAll()).length, 1);
    });
  });
}
