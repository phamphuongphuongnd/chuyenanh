import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/platform/app_platform.dart';
import 'package:pdf_office/core/utils/file_import.dart';
import 'package:pdf_office/features/documents/documents_providers.dart';
import 'package:pdf_office/features/settings/settings_logic.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('ios_test_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('importIntoAppDocuments', () {
    test('Android: trả nguyên đường dẫn, không chép', () async {
      final src = File(p.join(tmp.path, 'a.pdf'))..writeAsStringSync('x');
      final docs = Directory(p.join(tmp.path, 'docs'))..createSync();
      final r = await importIntoAppDocuments(
        src.path,
        platform: AppPlatform.android,
        documentsDir: docs,
      );
      expect(r, src.path);
      expect(docs.listSync(), isEmpty);
    });

    test('iOS: chép vào Documents/Imported', () async {
      final src = File(p.join(tmp.path, 'a.pdf'))..writeAsStringSync('x');
      final docs = Directory(p.join(tmp.path, 'docs'))..createSync();
      final r = await importIntoAppDocuments(
        src.path,
        platform: AppPlatform.ios,
        documentsDir: docs,
      );
      expect(r, p.join(docs.path, importedFolderName, 'a.pdf'));
      expect(File(r).readAsStringSync(), 'x');
    });

    test('iOS: file đã nằm trong Documents thì giữ nguyên', () async {
      final docs = Directory(p.join(tmp.path, 'docs'))..createSync();
      final src = File(p.join(docs.path, 'a.pdf'))..writeAsStringSync('x');
      final r = await importIntoAppDocuments(
        src.path,
        platform: AppPlatform.ios,
        documentsDir: docs,
      );
      expect(r, src.path);
    });

    test('iOS: trùng tên khác nội dung → thêm hậu tố; giống hệt → dùng lại', () async {
      final docs = Directory(p.join(tmp.path, 'docs'))..createSync();
      final a = File(p.join(tmp.path, 'x', 'a.pdf'))
        ..createSync(recursive: true)
        ..writeAsStringSync('one');
      final b = File(p.join(tmp.path, 'y', 'a.pdf'))
        ..createSync(recursive: true)
        ..writeAsStringSync('twelve');
      Future<String> imp(File f) => importIntoAppDocuments(
        f.path,
        platform: AppPlatform.ios,
        documentsDir: docs,
      );
      final r1 = await imp(a);
      final r2 = await imp(b);
      final r3 = await imp(a);
      expect(p.basename(r1), 'a.pdf');
      expect(p.basename(r2), 'a (1).pdf');
      expect(r3, r1);
    });
  });

  test('iOS: defaultShareOrigin có giá trị, Android thì null', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(defaultShareOrigin(platform: AppPlatform.android), isNull);
    expect(defaultShareOrigin(platform: AppPlatform.ios), isNotNull);
  });

  test('appShareMessage: mặc định (Android) kèm link APK, iOS kèm link trang cài iOS', () {
    expect(appShareMessage('hi'), 'hi\n$kAppDownloadUrl');
    expect(appShareMessage('hi', link: kIosDownloadUrl), 'hi\n$kIosDownloadUrl');
    // iPhone không cài được APK → link iOS phải khác link APK và trỏ trang Release ios-latest.
    expect(kIosDownloadUrl, isNot(kAppDownloadUrl));
    expect(kIosDownloadUrl, endsWith('/releases/tag/ios-latest'));
  });

  test('platformScanRootsProvider: Android/khác rỗng', () async {
    final c = ProviderContainer(
      overrides: [appPlatformProvider.overrideWithValue(AppPlatform.android)],
    );
    addTearDown(c.dispose);
    expect(await c.read(platformScanRootsProvider)(), isEmpty);
  });
}
