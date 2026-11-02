import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/platform/app_platform.dart';
import 'package:pdf_office/core/utils/file_import.dart';
import 'package:pdf_office/core/utils/output_directory.dart';
import 'package:pdf_office/features/documents/documents_providers.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('ios_test_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('importIntoAppDocuments', () {
    test(
      'Android: chép bản tạm của file_picker vào Documents/Imported',
      () async {
        final src = File(p.join(tmp.path, 'cache', 'a.pdf'))
          ..createSync(recursive: true)
          ..writeAsStringSync('x');
        final docs = Directory(p.join(tmp.path, 'docs'))..createSync();
        final r = await importIntoAppDocuments(
          src.path,
          platform: AppPlatform.android,
          documentsDir: docs,
        );
        expect(r, p.join(docs.path, importedFolderName, 'a.pdf'));
        expect(File(r).readAsStringSync(), 'x');
        // Bản tạm bị dọn (xoá bộ nhớ đệm) → bản trong Imported vẫn còn.
        src.deleteSync();
        expect(File(r).existsSync(), isTrue);
      },
    );

    test('Android: file đã nằm trong Documents thì giữ nguyên', () async {
      final docs = Directory(p.join(tmp.path, 'docs'))..createSync();
      final src = File(p.join(docs.path, importedFolderName, 'a.pdf'))
        ..createSync(recursive: true)
        ..writeAsStringSync('x');
      final r = await importIntoAppDocuments(
        src.path,
        platform: AppPlatform.android,
        documentsDir: docs,
      );
      expect(r, src.path);
    });

    test('Android: trùng tên khác nội dung → thêm hậu tố', () async {
      final docs = Directory(p.join(tmp.path, 'docs'))..createSync();
      final a = File(p.join(tmp.path, 'x', 'a.pdf'))
        ..createSync(recursive: true)
        ..writeAsStringSync('one');
      final b = File(p.join(tmp.path, 'y', 'a.pdf'))
        ..createSync(recursive: true)
        ..writeAsStringSync('twelve');
      Future<String> imp(File f) => importIntoAppDocuments(
        f.path,
        platform: AppPlatform.android,
        documentsDir: docs,
      );
      expect(p.basename(await imp(a)), 'a.pdf');
      expect(p.basename(await imp(b)), 'a (1).pdf');
    });

    test('nền tảng khác: trả nguyên đường dẫn, không chép', () async {
      final src = File(p.join(tmp.path, 'a.pdf'))..writeAsStringSync('x');
      final docs = Directory(p.join(tmp.path, 'docs'))..createSync();
      final r = await importIntoAppDocuments(
        src.path,
        platform: AppPlatform.other,
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

    test(
      'iOS: trùng tên khác nội dung → thêm hậu tố; giống hệt → dùng lại',
      () async {
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
      },
    );
  });

  test('iOS: defaultShareOrigin có giá trị, Android thì null', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(defaultShareOrigin(platform: AppPlatform.android), isNull);
    expect(defaultShareOrigin(platform: AppPlatform.ios), isNotNull);
  });

  test('platformScanRootsProvider: nền tảng khác rỗng', () async {
    final c = ProviderContainer(
      overrides: [appPlatformProvider.overrideWithValue(AppPlatform.other)],
    );
    addTearDown(c.dispose);
    expect(await c.read(platformScanRootsProvider)(), isEmpty);
  });

  test('platformScanRootsProvider: Android chỉ quét thư mục lưu + Documents của app', () async {
    final out = Directory(p.join(tmp.path, 'out'))..createSync();
    final docs = Directory(p.join(tmp.path, 'docs'))..createSync();
    final c = ProviderContainer(
      overrides: [
        appPlatformProvider.overrideWithValue(AppPlatform.android),
        outputDirectoryProvider.overrideWith((ref) async => out.path),
        appDocumentsDirProvider.overrideWith((ref) async => docs.path),
      ],
    );
    addTearDown(c.dispose);
    final roots = await c.read(platformScanRootsProvider)();
    // Không còn quét cả `/storage/emulated/0`; `Documents/PDF Office` không có trên máy dev.
    expect(roots, [out.path, docs.path]);
    expect(c.read(scanRootsProvider), isEmpty);
  });

  test('androidSdkIntProvider: không phải Android → null', () async {
    final c = ProviderContainer(
      overrides: [appPlatformProvider.overrideWithValue(AppPlatform.ios)],
    );
    addTearDown(c.dispose);
    expect(await c.read(androidSdkIntProvider.future), isNull);
  });
}
