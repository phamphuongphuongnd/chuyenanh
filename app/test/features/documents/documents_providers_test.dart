import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/platform/app_platform.dart';
import 'package:pdf_office/core/utils/doc_type.dart';
import 'package:pdf_office/core/utils/output_directory.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/data/file_scanner/file_scanner.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/features/documents/documents_logic.dart';
import 'package:pdf_office/features/documents/documents_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeScanner implements FileScanner {
  _FakeScanner(this.result);
  ScanResult result;
  int calls = 0;
  List<String>? roots;

  @override
  Future<ScanResult> scan(
    List<String> roots, {
    void Function(int found)? onProgress,
  }) async {
    calls++;
    this.roots = roots;
    onProgress?.call(result.files.length);
    return result;
  }
}

class _FakePermission implements StoragePermissionService {
  _FakePermission({required this.granted, this.grantOnRequest = false});
  bool granted;
  bool grantOnRequest;
  int requests = 0;

  @override
  Future<bool> isGranted() async => granted;

  @override
  Future<bool> request() async {
    requests++;
    if (grantOnRequest) granted = true;
    return granted;
  }
}

ScannedFile _file(String name, {int size = 10, int modifiedMs = 1}) =>
    ScannedFile(
      path: '/root/$name',
      name: name,
      ext: extensionOf(name),
      size: size,
      modifiedMs: modifiedMs,
      folder: 'root',
    );

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() => db.close());

  ProviderContainer makeContainer(
    FileScanner scanner,
    StoragePermissionService permission,
  ) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        fileScannerProvider.overrideWithValue(scanner),
        storagePermissionProvider.overrideWithValue(permission),
        scanRootsProvider.overrideWithValue(const ['/root']),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  group('ScanController', () {
    test('đã có quyền → quét và ghi vào bảng documents', () async {
      final scanner = _FakeScanner(
        ScanResult(files: [_file('a.pdf'), _file('b.docx')]),
      );
      final c = makeContainer(scanner, _FakePermission(granted: true));

      c.read(scanControllerProvider); // khởi động lượt quét đầu
      await settle();

      expect(c.read(scanControllerProvider).phase, ScanPhase.done);
      expect(c.read(scanControllerProvider).found, 2);
      expect((await db.documentsDao.getAll()).map((d) => d.name).toSet(), {
        'a.pdf',
        'b.docx',
      });
    });

    test(
      'chưa có quyền → needsPermission, không quét, không đụng DB',
      () async {
        await db.documentsDao.upsert(
          DocumentsCompanion.insert(
            path: '/old.pdf',
            name: 'old.pdf',
            ext: 'pdf',
            size: 1,
            modifiedMs: 1,
            folder: 'x',
            scannedAtMs: 1,
          ),
        );
        final scanner = _FakeScanner(const ScanResult(files: []));
        final c = makeContainer(scanner, _FakePermission(granted: false));

        c.read(scanControllerProvider);
        await settle();

        expect(c.read(scanControllerProvider).needsPermission, isTrue);
        expect(scanner.calls, 0);
        expect((await db.documentsDao.getAll()).length, 1);
      },
    );

    test(
      'thư mục gốc không đọc được → needsPermission, giữ nguyên DB',
      () async {
        await db.documentsDao.upsert(
          DocumentsCompanion.insert(
            path: '/old.pdf',
            name: 'old.pdf',
            ext: 'pdf',
            size: 1,
            modifiedMs: 1,
            folder: 'x',
            scannedAtMs: 1,
          ),
        );
        final scanner = _FakeScanner(
          const ScanResult(files: [], unreadableRoots: ['/root']),
        );
        final c = makeContainer(scanner, _FakePermission(granted: true));

        c.read(scanControllerProvider);
        await settle();

        expect(c.read(scanControllerProvider).needsPermission, isTrue);
        expect((await db.documentsDao.getAll()).length, 1);
      },
    );

    test('xin quyền thành công → quét ngay', () async {
      final scanner = _FakeScanner(ScanResult(files: [_file('a.pdf')]));
      final permission = _FakePermission(granted: false, grantOnRequest: true);
      final c = makeContainer(scanner, permission);

      c.read(scanControllerProvider);
      await settle();
      expect(c.read(scanControllerProvider).needsPermission, isTrue);

      final ok = await c
          .read(scanControllerProvider.notifier)
          .requestPermissionAndScan();

      expect(ok, isTrue);
      expect(permission.requests, 1);
      expect(c.read(scanControllerProvider).phase, ScanPhase.done);
      expect((await db.documentsDao.getAll()).length, 1);
    });

    test('xin quyền bị từ chối → vẫn needsPermission', () async {
      final scanner = _FakeScanner(const ScanResult(files: []));
      final c = makeContainer(scanner, _FakePermission(granted: false));

      c.read(scanControllerProvider);
      await settle();
      final ok = await c
          .read(scanControllerProvider.notifier)
          .requestPermissionAndScan();

      expect(ok, isFalse);
      expect(c.read(scanControllerProvider).needsPermission, isTrue);
      expect(scanner.calls, 0);
    });

    test('nhiều lượt quét gọi cùng lúc chỉ chạy một lượt', () async {
      final scanner = _FakeScanner(ScanResult(files: [_file('a.pdf')]));
      final c = makeContainer(scanner, _FakePermission(granted: true));

      c.read(scanControllerProvider); // lượt tự động đầu tiên
      final n = c.read(scanControllerProvider.notifier);
      await Future.wait([
        n.refresh(),
        n.refresh(),
        n.requestPermissionAndScan(),
      ]);
      await settle();

      expect(scanner.calls, 1);
    });

    test('refresh(force: false) bỏ qua khi vừa quét xong', () async {
      final scanner = _FakeScanner(ScanResult(files: [_file('a.pdf')]));
      final c = makeContainer(scanner, _FakePermission(granted: true));

      c.read(scanControllerProvider);
      await settle();
      expect(scanner.calls, 1);

      await c.read(scanControllerProvider.notifier).refresh(force: false);
      expect(scanner.calls, 1);

      await c.read(scanControllerProvider.notifier).refresh();
      expect(scanner.calls, 2);
    });

    test(
      'không có file + vài thư mục con bị bỏ qua → vẫn done, không đòi quyền',
      () async {
        final scanner = _FakeScanner(
          const ScanResult(files: [], skippedDirectories: 5),
        );
        final c = makeContainer(scanner, _FakePermission(granted: true));
        c.read(scanControllerProvider);
        await settle();
        expect(c.read(scanControllerProvider).phase, ScanPhase.done);
      },
    );

    test('file bị xoá khỏi máy → biến mất sau lượt quét sau', () async {
      final scanner = _FakeScanner(
        ScanResult(files: [_file('a.pdf'), _file('b.pdf')]),
      );
      final c = makeContainer(scanner, _FakePermission(granted: true));
      c.read(scanControllerProvider);
      await settle();
      expect((await db.documentsDao.getAll()).length, 2);

      scanner.result = ScanResult(files: [_file('a.pdf')]);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await c.read(scanControllerProvider.notifier).refresh();

      expect((await db.documentsDao.getAll()).map((d) => d.name), ['a.pdf']);
    });
  });

  group(
    'PermissionHandlerStorage (không bao giờ xin "Truy cập tất cả file")',
    () {
      PermissionHandlerStorage make(
        AppPlatform platform,
        int? sdk, {
        required List<String> calls,
        bool granted = false,
      }) => PermissionHandlerStorage(
        platform: platform,
        sdkInt: () async => sdk,
        storageGranted: () async {
          calls.add('status');
          return granted;
        },
        requestStorage: () async {
          calls.add('request');
          return true;
        },
      );

      for (final sdk in [30, 33, 35]) {
        test('Android API $sdk → không cần quyền, không hỏi', () async {
          final calls = <String>[];
          final s = make(AppPlatform.android, sdk, calls: calls);
          expect(await s.isGranted(), isTrue);
          expect(await s.request(), isTrue);
          expect(calls, isEmpty);
        });
      }

      test('Android API ≤ 29 → dùng Permission.storage', () async {
        final calls = <String>[];
        final s = make(AppPlatform.android, 29, calls: calls);
        expect(await s.isGranted(), isFalse);
        expect(await s.request(), isTrue);
        expect(calls, ['status', 'request']);

        final granted = make(AppPlatform.android, 24, calls: [], granted: true);
        expect(await granted.isGranted(), isTrue);
      });

      test('iOS / khác / không đọc được mức API → true, không hỏi', () async {
        final calls = <String>[];
        for (final (platform, sdk) in [
          (AppPlatform.ios, null),
          (AppPlatform.other, null),
          (AppPlatform.android, null),
        ]) {
          final s = make(platform, sdk, calls: calls);
          expect(await s.isGranted(), isTrue);
          expect(await s.request(), isTrue);
        }
        expect(calls, isEmpty);
      });
    },
  );

  group('androidScanRoots', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('roots_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    String dir(String name, {bool create = true}) {
      // normalize: tên có '/' phải ra cùng dấu phân cách với code (Windows là '\').
      final d = Directory(p.normalize(p.join(tmp.path, name)));
      if (create) d.createSync(recursive: true);
      return d.path;
    }

    test('thư mục lưu + mặc định + cũ (nếu có) + Documents của app', () async {
      final roots = await androidScanRoots(
        outputDir: dir('custom'),
        appDocumentsDir: dir('app_docs'),
        defaultDir: dir('Documents/$appFolderName'),
        legacyDir: dir('Documents/$legacyAppFolderName'),
      );
      expect(roots, [
        dir('custom'),
        dir('Documents/$appFolderName'),
        dir('Documents/$legacyAppFolderName'),
        dir('app_docs'),
      ]);
    });

    test('bỏ thư mục không tồn tại và trùng lặp', () async {
      final out = dir('Documents/$appFolderName');
      final roots = await androidScanRoots(
        outputDir: out,
        appDocumentsDir: dir('app_docs'),
        defaultDir: out,
        legacyDir: dir('Documents/$legacyAppFolderName', create: false),
      );
      expect(roots, [out, dir('app_docs')]);
    });

    test(
      'thư mục lưu nằm trong Documents của app → chỉ quét một lần',
      () async {
        final docs = dir('app_docs');
        final roots = await androidScanRoots(
          outputDir: dir('app_docs/$appFolderName'),
          appDocumentsDir: docs,
          defaultDir: dir('nope', create: false),
          legacyDir: dir('old', create: false),
        );
        expect(roots, [docs]);
      },
    );
  });

  group('Android chỉ quét thư mục của app', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('android_scan_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test(
      'API ≥ 30: quét thư mục lưu + Documents của app, không xin quyền',
      () async {
        final out = Directory(p.join(tmp.path, 'out'))..createSync();
        final docs = Directory(p.join(tmp.path, 'app_docs'))..createSync();
        final scanner = _FakeScanner(ScanResult(files: [_file('a.pdf')]));
        final c = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            fileScannerProvider.overrideWithValue(scanner),
            appPlatformProvider.overrideWithValue(AppPlatform.android),
            androidSdkIntProvider.overrideWith((ref) async => 34),
            outputDirectoryProvider.overrideWith((ref) async => out.path),
            appDocumentsDirProvider.overrideWith((ref) async => docs.path),
          ],
        );
        addTearDown(c.dispose);

        c.read(scanControllerProvider);
        await settle();

        expect(c.read(scanControllerProvider).phase, ScanPhase.done);
        // `Documents/PDF Office` thật không có trên máy dev → bị bỏ.
        expect(scanner.roots, [out.path, docs.path]);
      },
    );

    test('API ≤ 29 chưa cấp Permission.storage → needsPermission', () async {
      final scanner = _FakeScanner(const ScanResult(files: []));
      final c = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          fileScannerProvider.overrideWithValue(scanner),
          appPlatformProvider.overrideWithValue(AppPlatform.android),
          androidSdkIntProvider.overrideWith((ref) async => 29),
          storagePermissionProvider.overrideWith(
            (ref) => PermissionHandlerStorage(
              platform: ref.watch(appPlatformProvider),
              sdkInt: () => ref.read(androidSdkIntProvider.future),
              storageGranted: () async => false,
              requestStorage: () async => false,
            ),
          ),
        ],
      );
      addTearDown(c.dispose);

      c.read(scanControllerProvider);
      await settle();
      expect(c.read(scanControllerProvider).needsPermission, isTrue);
      expect(
        await c
            .read(scanControllerProvider.notifier)
            .requestPermissionAndScan(),
        isFalse,
      );
      expect(scanner.calls, 0);
    });
  });

  group('sắp xếp', () {
    test('mặc định dateDesc, đổi xong được lưu và đọc lại ở lần sau', () async {
      final c1 = makeContainer(
        _FakeScanner(const ScanResult(files: [])),
        _FakePermission(granted: true),
      );
      expect(c1.read(docSortProvider), DocSort.dateDesc);

      await c1.read(docSortProvider.notifier).set(DocSort.sizeAsc);
      expect(c1.read(docSortProvider), DocSort.sizeAsc);
      expect(prefs.getString(DocSortNotifier.prefsKey), 'sizeAsc');

      final c2 = makeContainer(
        _FakeScanner(const ScanResult(files: [])),
        _FakePermission(granted: true),
      );
      expect(c2.read(docSortProvider), DocSort.sizeAsc);
    });
  });

  group('categoryDocumentsProvider', () {
    test('lọc theo tab và sắp xếp theo lựa chọn hiện tại', () async {
      final scanner = _FakeScanner(
        ScanResult(
          files: [
            _file('small.pdf', size: 5),
            _file('big.pdf', size: 500),
            _file('mid.docx', size: 50),
            _file('note.txt', size: 1),
          ],
        ),
      );
      final c = makeContainer(scanner, _FakePermission(granted: true));
      c.listen(documentsProvider, (_, _) {}); // giữ stream sống
      c.read(scanControllerProvider);
      await settle();
      await c.read(docSortProvider.notifier).set(DocSort.sizeDesc);
      await settle();

      List<String> names(DocCategory? cat) => c
          .read(categoryDocumentsProvider(cat))
          .requireValue
          .map((d) => d.name)
          .toList();

      expect(names(null), ['big.pdf', 'mid.docx', 'small.pdf', 'note.txt']);
      expect(names(DocCategory.pdf), ['big.pdf', 'small.pdf']);
      expect(names(DocCategory.doc), ['mid.docx']);
      expect(names(DocCategory.ppt), isEmpty);
    });
  });

  group('pdfLockedProvider', () {
    test('không phải PDF hoặc file không tồn tại → false', () async {
      final c = makeContainer(
        _FakeScanner(const ScanResult(files: [])),
        _FakePermission(granted: true),
      );
      expect(await c.read(pdfLockedProvider('/nope/a.docx').future), isFalse);
      expect(await c.read(pdfLockedProvider('/nope/a.pdf').future), isFalse);
    });
  });
}
