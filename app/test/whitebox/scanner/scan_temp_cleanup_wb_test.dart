// Kiểm thử hộp trắng A07 — scanner/capture/scan_temp_cleanup.dart (Bước 6).
// path_provider thay bằng mock MethodChannel của plugin.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/features/scanner/capture/scan_temp_cleanup.dart';

const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('wb_scan_clean_'));
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_pathChannel, null);
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  File make(String rel, {required Duration age}) {
    final f = File(p.join(temp.path, rel))..createSync(recursive: true);
    f.writeAsStringSync('x');
    f.setLastModifiedSync(DateTime.now().subtract(age));
    return f;
  }

  const old = Duration(days: 2);
  const fresh = Duration(minutes: 1);

  test('U1-B1 scan_pages có 1 ảnh cũ ⇒ xoá, trả 1', () async {
    final f = make('scan_pages/p1_0.jpg', age: old);
    expect(await cleanupStaleScanFiles(temp), 1);
    expect(f.existsSync(), isFalse);
  });

  test('U1-B2 temp null ⇒ dùng thư mục tạm của hệ thống (path_provider)', () async {
    var asked = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_pathChannel, (c) async {
      asked++;
      return temp.path;
    });
    final f = make('scan_pages/p1_0.jpg', age: old);
    final n = await cleanupStaleScanFiles(null);
    expect(asked, 1);
    expect(f.existsSync(), isFalse);
    expect(n, 1);
  });

  test('U1-B3 không có scan_pages, thư mục trống ⇒ 0', () async {
    expect(await cleanupStaleScanFiles(temp), 0);
  });

  test('U1-B4 scan_pages rỗng ⇒ 0', () async {
    Directory(p.join(temp.path, 'scan_pages')).createSync();
    expect(await cleanupStaleScanFiles(temp), 0);
  });

  test('U1-B5 scan_pages chỉ chứa thư mục con ⇒ không xoá gì', () async {
    final sub = Directory(p.join(temp.path, 'scan_pages', 'sub'))..createSync(recursive: true);
    expect(await cleanupStaleScanFiles(temp), 0);
    expect(sub.existsSync(), isTrue);
  });

  test('U1-B6 thư mục tạm không tồn tại ⇒ 0, không ném', () async {
    final missing = Directory(p.join(temp.path, 'khong-co'));
    final r = await cleanupStaleScanFiles(missing).then<Object?>((v) => v, onError: (Object e) => e);
    expect(r, 0);
  });

  test('U1-B7 ảnh cắt crop_ cũ ở gốc thư mục tạm ⇒ xoá', () async {
    final a = make('scan_pages/p1_0.jpg', age: old);
    final b = make('crop_1.jpg', age: old);
    expect(await cleanupStaleScanFiles(temp), 2);
    expect(a.existsSync(), isFalse);
    expect(b.existsSync(), isFalse);
  });

  test('U1-B8 file khác tên ở gốc ⇒ giữ', () async {
    make('scan_pages/p1_0.jpg', age: old);
    final other = make('other.jpg', age: old);
    expect(await cleanupStaleScanFiles(temp), 1);
    expect(other.existsSync(), isTrue);
  });

  test('U1-B9 ảnh quét còn mới ⇒ giữ', () async {
    final f = make('scan_pages/p1_0.jpg', age: fresh);
    expect(await cleanupStaleScanFiles(temp), 0);
    expect(f.existsSync(), isTrue);
  });

  test('U1-B10 ảnh cũ đang mở (xoá lỗi) ⇒ bỏ qua, không ném, không đếm', () async {
    final f = make('scan_pages/p1_0.jpg', age: old);
    final raf = f.openSync();
    try {
      final r = await cleanupStaleScanFiles(temp).then<Object?>((v) => v, onError: (Object e) => e);
      expect(f.existsSync(), isTrue, reason: 'Windows không cho xoá file đang mở');
      expect(r, 0);
    } finally {
      raf.closeSync();
    }
  });
}
