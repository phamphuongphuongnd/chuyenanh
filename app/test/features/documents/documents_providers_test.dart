import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/utils/doc_type.dart';
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

  @override
  Future<ScanResult> scan(
    List<String> roots, {
    void Function(int found)? onProgress,
  }) async {
    calls++;
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
      'quét xong không có file nhưng nhiều thư mục bị bỏ qua → needsPermission',
      () async {
        final scanner = _FakeScanner(
          const ScanResult(files: [], skippedDirectories: 5),
        );
        final c = makeContainer(scanner, _FakePermission(granted: true));
        c.read(scanControllerProvider);
        await settle();
        expect(c.read(scanControllerProvider).needsPermission, isTrue);
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
