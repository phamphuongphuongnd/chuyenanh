// ignore_for_file: depend_on_referenced_packages
// Kiểm thử hộp trắng (A10, chủ đề core) — lib/core/utils/file_import.dart.
// Bộ dữ liệu + kết quả mong đợi: test-output/whitebox/core/file_import/buoc-5-du-lieu-thu.md
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pdf_office/core/platform/app_platform.dart';
import 'package:pdf_office/core/utils/file_import.dart';
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
  late Directory docs;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('wb_import_');
    docs = Directory(p.join(tmp.path, 'docs'))..createSync();
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  File src(String sub, String name, String content) =>
      File(p.join(tmp.path, sub, name))
        ..createSync(recursive: true)
        ..writeAsStringSync(content);

  Future<String> imp(String path, {Directory? dir}) => importIntoAppDocuments(
    path,
    platform: AppPlatform.ios,
    documentsDir: dir ?? docs,
  );

  Directory imported() => Directory(p.join(docs.path, importedFolderName));

  test('1.1 iOS, file ngoài Documents, chưa trùng ⇒ chép vào Documents/Imported/a.pdf', () async {
    final s = src('x', 'a.pdf', 'one');
    final r = await imp(s.path);
    expect(r, p.join(docs.path, importedFolderName, 'a.pdf'));
    expect(File(r).readAsStringSync(), 'one');
    expect(s.existsSync(), isTrue);
  });

  test('1.2 Android (MỚI, 6352ec7) ⇒ chép vào <app documents>/Imported như iOS', () async {
    final s = src('x', 'a.pdf', 'one');
    final r = await importIntoAppDocuments(s.path, platform: AppPlatform.android, documentsDir: docs);
    expect(imported().existsSync(), isTrue);
    expect(r, p.join(docs.path, importedFolderName, 'a.pdf'));
    expect(File(r).readAsStringSync(), 'one');
  });

  test('1.11 platform = other (truyền rõ) ⇒ trả nguyên đường dẫn, không chép', () async {
    final s = src('x', 'a.pdf', 'one');
    final r = await importIntoAppDocuments(s.path, platform: AppPlatform.other, documentsDir: docs);
    expect(imported().existsSync(), isFalse);
    expect(r, s.path);
  });

  test('1.3 không truyền platform, máy dev (other) ⇒ trả nguyên đường dẫn', () async {
    final s = src('x', 'a.pdf', 'one');
    final r = await importIntoAppDocuments(s.path, documentsDir: docs);
    expect(imported().existsSync(), isFalse);
    expect(r, s.path);
  });

  test('1.4 iOS, không truyền documentsDir ⇒ lấy thư mục Documents của app', () async {
    final fake = _FakePathProvider(docs.path);
    final old = PathProviderPlatform.instance;
    PathProviderPlatform.instance = fake;
    addTearDown(() => PathProviderPlatform.instance = old);
    final s = src('x', 'a.pdf', 'one');
    final r = await importIntoAppDocuments(s.path, platform: AppPlatform.ios);
    expect(fake.calls, 1);
    expect(r, p.join(docs.path, importedFolderName, 'a.pdf'));
  });

  test('1.5 iOS, file đã nằm trong Documents ⇒ giữ nguyên, không chép', () async {
    final s = File(p.join(docs.path, 'a.pdf'))..writeAsStringSync('one');
    final r = await imp(s.path);
    expect(imported().existsSync(), isFalse);
    expect(r, s.path);
  });

  test('1.6 iOS, file nguồn không tồn tại ⇒ trả nguyên đường dẫn, không tạo Imported', () async {
    final missing = p.join(tmp.path, 'x', 'gone.pdf');
    final r = await imp(missing);
    expect(imported().existsSync(), isFalse);
    expect(r, missing);
  });

  test('1.7 iOS, nhập lại đúng file đó (giống hệt) ⇒ dùng lại a.pdf, không thêm bản', () async {
    final s = src('x', 'a.pdf', 'one');
    final r1 = await imp(s.path);
    final r2 = await imp(s.path);
    expect(imported().listSync().length, 1);
    expect(r2, r1);
  });

  test('1.8 iOS, trùng tên khác nội dung (khác dung lượng) ⇒ a (1).pdf', () async {
    await imp(src('x', 'a.pdf', 'one').path);
    final r = await imp(src('y', 'a.pdf', 'twelve').path);
    expect(p.basename(r), 'a (1).pdf');
    expect(File(r).readAsStringSync(), 'twelve');
  });

  test('1.9 iOS, a.pdf khác, a (1).pdf giống hệt ⇒ dùng lại a (1).pdf', () async {
    await imp(src('x', 'a.pdf', 'one').path);
    final b = src('y', 'a.pdf', 'twelve');
    final r1 = await imp(b.path);
    final r2 = await imp(b.path);
    expect(imported().listSync().length, 2);
    expect(p.basename(r2), 'a (1).pdf');
    expect(r2, r1);
  });

  test('1.10 iOS, trùng tên, CÙNG dung lượng nhưng KHÁC nội dung ⇒ a (1).pdf (wiki: chỉ giống hệt mới dùng lại)', () async {
    await imp(src('x', 'a.pdf', 'abc').path);
    final r = await imp(src('y', 'a.pdf', 'xyz').path);
    final content = File(r).readAsStringSync();
    // Nhánh đã đi: nếu trả về a.pdf (nội dung "abc") là code dùng lại theo dung lượng.
    expect(imported().listSync().length, 2, reason: 'đã đi nhánh dùng lại; nội dung trả về: $content');
    expect(p.basename(r), 'a (1).pdf');
    expect(content, 'xyz');
  });

  group('Android có quyền đọc tất cả file', () {
    Future<String> impA(String path, {bool full = true}) => importIntoAppDocuments(
      path,
      platform: AppPlatform.android,
      documentsDir: docs,
      hasFullStorageAccess: full,
      sharedStorageRoot: p.join(tmp.path, 'shared'),
    );

    test('1.12 file thật dưới bộ nhớ chung ⇒ mở thẳng bản gốc, không chép', () async {
      final s = src('shared/Download', 'a.pdf', 'one');
      final r = await impA(s.path);
      expect(r, s.path);
      expect(imported().existsSync(), isFalse);
    });

    test('1.13 bản sao tạm trong cache (ngoài bộ nhớ chung) ⇒ vẫn chép vào Imported', () async {
      final s = src('cache/file_picker', 'a.pdf', 'one');
      final r = await impA(s.path);
      expect(r, p.join(docs.path, importedFolderName, 'a.pdf'));
    });

    test('1.14 chưa có quyền, file ở bộ nhớ chung ⇒ vẫn chép', () async {
      final s = src('shared/Download', 'a.pdf', 'one');
      final r = await impA(s.path, full: false);
      expect(r, p.join(docs.path, importedFolderName, 'a.pdf'));
    });

    test('1.15 iOS bỏ qua cờ quyền ⇒ luôn chép', () async {
      final s = src('shared/Download', 'a.pdf', 'one');
      final r = await importIntoAppDocuments(
        s.path,
        platform: AppPlatform.ios,
        documentsDir: docs,
        hasFullStorageAccess: true,
        sharedStorageRoot: p.join(tmp.path, 'shared'),
      );
      expect(r, p.join(docs.path, importedFolderName, 'a.pdf'));
    });
  });
}
