// ignore_for_file: depend_on_referenced_packages
// Kiểm thử hộp trắng (A10, chủ đề core) — lib/core/utils/output_directory.dart.
// Bộ dữ liệu + kết quả mong đợi: test-output/whitebox/core/output_directory/buoc-5-du-lieu-thu.md
// Máy chạy test là Windows (Platform.isAndroid = false): bộ 1.5, 1.6 cần thiết bị Android.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pdf_office/core/utils/output_directory.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.docs);
  final String docs;
  int calls = 0;
  @override
  Future<String?> getApplicationDocumentsPath() async {
    calls++;
    return docs;
  }
}

void main() {
  late Directory tmp;
  late _FakePathProvider fake;
  late PathProviderPlatform old;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('wb_outdir_');
    fake = _FakePathProvider(p.join(tmp.path, 'docs'));
    old = PathProviderPlatform.instance;
    PathProviderPlatform.instance = fake;
  });
  tearDown(() {
    PathProviderPlatform.instance = old;
    tmp.deleteSync(recursive: true);
  });

  String fallback() => p.join(tmp.path, 'docs', appFolderName);

  test('1.0 điều kiện tiên quyết: máy dev không phải Android', () {
    expect(Platform.isAndroid, isFalse);
  });

  test('1.1 thư mục cấu hình ghi được ⇒ dùng nó, tạo sẵn, không để file thử', () async {
    final cfg = p.join(tmp.path, 'out', 'nested');
    final r = await resolveOutputDirectory(cfg);
    expect(fake.calls, 0, reason: 'không được rơi về Documents');
    expect(r, cfg);
    expect(Directory(cfg).existsSync(), isTrue);
    expect(Directory(cfg).listSync(), isEmpty);
  });

  test('1.2 chưa cấu hình (null) ⇒ <Documents>/PDF Office, đã tạo', () async {
    final r = await resolveOutputDirectory(null);
    expect(fake.calls, 1);
    expect(r, fallback());
    expect(Directory(r).existsSync(), isTrue);
  });

  test('1.3 cấu hình rỗng ⇒ <Documents>/PDF Office', () async {
    final r = await resolveOutputDirectory('');
    expect(fake.calls, 1);
    expect(r, fallback());
  });

  test('1.4 thư mục cấu hình không tạo được (nằm dưới một FILE) ⇒ rơi về <Documents>/PDF Office', () async {
    final blocker = File(p.join(tmp.path, 'blocker'))..writeAsStringSync('');
    final r = await resolveOutputDirectory(p.join(blocker.path, 'sub'));
    expect(fake.calls, 1);
    expect(r, fallback());
  });
}
