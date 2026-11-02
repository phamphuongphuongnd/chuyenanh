// Kiểm thử hộp trắng A13 — app/lib/features/documents/documents_providers.dart (bản làm việc hash eeb593a)
// Thiết kế: test-output/whitebox/documents/documents_providers/buoc-1..5. Expected chép từ Bước 5.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/core/platform/app_platform.dart';
import 'package:pdf_office/core/utils/doc_type.dart';
import 'package:pdf_office/core/utils/output_directory.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/data/file_scanner/file_scanner.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/engines/pdf/pdf_security.dart';
import 'package:pdf_office/features/documents/documents_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Scanner implements FileScanner {
  _Scanner([this.result = const ScanResult(files: [])]);
  ScanResult result;
  Object? error;
  Completer<void>? gate;
  int progressValue = -1;
  void Function(int)? lastProgress;
  final calls = <List<String>>[];
  @override
  Future<ScanResult> scan(List<String> roots, {void Function(int found)? onProgress}) async {
    calls.add(roots);
    lastProgress = onProgress;
    if (progressValue >= 0) onProgress?.call(progressValue);
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return result;
  }
}

class _Perm implements StoragePermissionService {
  _Perm({this.granted = true});
  bool granted;
  Completer<bool>? gate;
  @override
  Future<bool> isGranted() => gate?.future ?? Future.value(granted);
  @override
  Future<bool> request() => gate?.future ?? Future.value(granted);
}

class _Sec implements PdfSecurityEngine {
  _Sec({this.error});
  final bool result = true;
  final Object? error;
  int calls = 0;
  @override
  Future<bool> isEncrypted(Uint8List bytes) async {
    calls++;
    if (error != null) throw error!;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ScannedFile _f(String name) => ScannedFile(
  path: '/root/$name',
  name: name,
  ext: extensionOf(name),
  size: 1,
  modifiedMs: 1,
  folder: 'root',
);

DocumentsCompanion _row(String path, String name) => DocumentsCompanion.insert(
  path: path,
  name: name,
  ext: 'pdf',
  size: 9,
  modifiedMs: 1,
  folder: 'r',
  scannedAtMs: 1,
);

/// DB hỏng: mọi lời gọi ném (giả lập lỗi ghi khi đồng bộ).
class _BrokenDb implements AppDatabase {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('db hỏng');
}

void main() {
  late Directory tmp;
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('wb_docprov_');
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  tearDown(() async {
    await db.close();
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // bỏ qua
    }
  });

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 60));
  String dir(String n) => (Directory(p.join(tmp.path, n))..createSync(recursive: true)).path;
  String file(String n, [List<int> b = const [1]]) => (File(p.join(tmp.path, n))..writeAsBytesSync(b)).path;

  ProviderContainer make({
    _Scanner? scanner,
    _Perm? perm,
    List<String> roots = const ['/root'],
    Future<List<String>> Function()? platformRoots,
    List<Override> extra = const [],
    AppDatabase? database,
  }) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database ?? db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        fileScannerProvider.overrideWithValue(scanner ?? _Scanner()),
        storagePermissionProvider.overrideWithValue(perm ?? _Perm()),
        scanRootsProvider.overrideWithValue(roots),
        if (platformRoots != null) platformScanRootsProvider.overrideWithValue(platformRoots),
        outputDirectoryProvider.overrideWith((ref) async => tmp.path),
        ...extra,
      ],
    );
    addTearDown(() {
      try {
        c.dispose();
      } catch (_) {}
    });
    return c;
  }

  group('U1 androidScanRoots', () {
    test('1-1 5 thư mục độc lập ⇒ đủ', () async {
      final r = await androidScanRoots(
        storageRoot: dir('s'),
        outputDir: dir('o'),
        defaultDir: dir('d'),
        legacyDir: dir('l'),
        appDocumentsDir: dir('a'),
      );
      expect(r, [for (final n in ['s', 'o', 'd', 'l', 'a']) p.join(tmp.path, n)]);
    });
    test('1-2 gốc cả máy chứa mọi thư mục ⇒ chỉ 1', () async {
      final d = dir('d');
      final r = await androidScanRoots(
        storageRoot: tmp.path,
        outputDir: dir('o'),
        defaultDir: d,
        legacyDir: d,
        appDocumentsDir: dir('a'),
      );
      expect(r, [p.normalize(tmp.path)]);
    });
    test('1-2b gốc con đứng trước bị thay bằng gốc cha', () async {
      final r = await androidScanRoots(
        outputDir: dir('a/x'),
        defaultDir: p.join(tmp.path, 'none1'),
        legacyDir: p.join(tmp.path, 'none2'),
        appDocumentsDir: dir('a'),
      );
      expect(r, [p.join(tmp.path, 'a')]);
    });
    test('1-3 thư mục không tồn tại ⇒ bỏ', () async {
      final r = await androidScanRoots(
        outputDir: dir('o'),
        defaultDir: p.join(tmp.path, 'none1'),
        legacyDir: p.join(tmp.path, 'none2'),
        appDocumentsDir: dir('a'),
      );
      expect(r, [p.join(tmp.path, 'o'), p.join(tmp.path, 'a')]);
    });
  });

  group('U2 platformScanRootsProvider', () {
    Future<List<String>> roots(AppPlatform pf) {
      final c = ProviderContainer(
        overrides: [
          appPlatformProvider.overrideWithValue(pf),
          appDocumentsDirProvider.overrideWith((ref) async => dir('A')),
          outputDirectoryProvider.overrideWith((ref) async => dir('O')),
        ],
      );
      addTearDown(c.dispose);
      return c.read(platformScanRootsProvider)();
    }

    test('2-1 ios ⇒ [Documents]', () async => expect(await roots(AppPlatform.ios), [p.join(tmp.path, 'A')]));
    test('2-2 android ⇒ [thư mục lưu, Documents app]', () async {
      expect(await roots(AppPlatform.android), [p.join(tmp.path, 'O'), p.join(tmp.path, 'A')]);
    });
    test('2-3 other ⇒ []', () async => expect(await roots(AppPlatform.other), isEmpty));
  });

  group('U3/U4 PermissionHandlerStorage', () {
    late List<String> asked;
    PermissionHandlerStorage ps(AppPlatform pf, int? sdk, {bool manage = false, bool storage = false}) {
      asked = [];
      return PermissionHandlerStorage(
        platform: pf,
        sdkInt: () async {
          asked.add('sdk');
          return sdk;
        },
        manageGranted: () async {
          asked.add('manage');
          return manage;
        },
        storageGranted: () async {
          asked.add('storage');
          return storage;
        },
        requestManage: () async {
          asked.add('reqManage');
          return manage;
        },
        requestStorage: () async {
          asked.add('reqStorage');
          return storage;
        },
      );
    }

    test('3-1 không phải Android ⇒ true, không hỏi', () async {
      expect(await ps(AppPlatform.ios, 30).isGranted(), isTrue);
      expect(asked, isEmpty);
    });
    test('3-2 sdk null, manage có ⇒ true, không hỏi storage', () async {
      expect(await ps(AppPlatform.android, null, manage: true).isGranted(), isTrue);
      expect(asked, ['sdk', 'manage']);
    });
    test('3-3 sdk null, chỉ storage ⇒ true', () async {
      expect(await ps(AppPlatform.android, null, storage: true).isGranted(), isTrue);
      expect(asked, ['sdk', 'manage', 'storage']);
    });
    test('3-4 sdk null, không quyền ⇒ false', () async {
      expect(await ps(AppPlatform.android, null).isGranted(), isFalse);
    });
    test('3-5 API 29 ⇒ theo quyền bộ nhớ', () async {
      expect(await ps(AppPlatform.android, 29, storage: true).isGranted(), isTrue);
      expect(asked, ['sdk', 'storage']);
    });
    test('3-6 API 30 ⇒ phải có Truy cập tất cả file', () async {
      expect(await ps(AppPlatform.android, 30, storage: true).isGranted(), isFalse);
      expect(asked, ['sdk', 'manage']);
    });
    test('4-1 request không phải Android ⇒ true', () async {
      expect(await ps(AppPlatform.other, 30).request(), isTrue);
      expect(asked, isEmpty);
    });
    test('4-2 request sdk null, manage cấp ⇒ true', () async {
      expect(await ps(AppPlatform.android, null, manage: true).request(), isTrue);
      expect(asked, ['sdk', 'reqManage']);
    });
    test('4-3 request sdk null, storage cấp ⇒ true', () async {
      expect(await ps(AppPlatform.android, null, storage: true).request(), isTrue);
      expect(asked, ['sdk', 'reqManage', 'reqStorage']);
    });
    test('4-4 request sdk null, từ chối hết ⇒ false', () async {
      expect(await ps(AppPlatform.android, null).request(), isFalse);
    });
    test('4-5 request API 29 ⇒ xin quyền bộ nhớ', () async {
      expect(await ps(AppPlatform.android, 29, storage: true).request(), isTrue);
      expect(asked, ['sdk', 'reqStorage']);
    });
    test('4-6 request API 30 ⇒ xin Truy cập tất cả file', () async {
      expect(await ps(AppPlatform.android, 30, manage: true).request(), isTrue);
      expect(asked, ['sdk', 'reqManage']);
    });
  });

  group('U5 copyWith', () {
    final t = DateTime(2026, 1, 1), t2 = DateTime(2026, 2, 2);
    final base = ScanState(phase: ScanPhase.done, found: 3, lastFinishedAt: t, error: const NoSpace());
    test('5-1 giữ cũ, xoá error', () {
      final s = base.copyWith();
      expect([s.phase, s.found, s.lastFinishedAt, s.error], [ScanPhase.done, 3, t, null]);
    });
    test('5-2 đổi phase', () => expect(base.copyWith(phase: ScanPhase.failed).phase, ScanPhase.failed));
    test('5-3 đổi found', () => expect(base.copyWith(found: 9).found, 9));
    test('5-4 đổi lastFinishedAt', () => expect(base.copyWith(lastFinishedAt: t2).lastFinishedAt, t2));
  });

  group('U6 refresh', () {
    test('6-1 có quyền ⇒ quét xong, ghi bảng documents', () async {
      final sc = _Scanner(ScanResult(files: [_f('a.pdf')]));
      final c = make(scanner: sc);
      c.read(scanControllerProvider);
      await settle();
      final s = c.read(scanControllerProvider);
      expect(sc.calls, hasLength(1));
      expect((await db.documentsDao.getAll()).map((d) => d.path), ['/root/a.pdf']);
      expect([s.phase, s.found], [ScanPhase.done, 1]);
    });
    test('6-2 đang quét ⇒ bỏ lượt mới', () async {
      final sc = _Scanner()..gate = Completer();
      final c = make(scanner: sc);
      c.read(scanControllerProvider);
      await settle();
      await c.read(scanControllerProvider.notifier).refresh();
      sc.gate!.complete();
      await settle();
      expect(sc.calls, hasLength(1));
    });
    test('6-3 force:false khi idle ⇒ quét', () async {
      final sc = _Scanner();
      final perm = _Perm()..gate = Completer();
      final c = make(scanner: sc, perm: perm);
      c.read(scanControllerProvider);
      await settle();
      perm.gate!.complete(false);
      await settle();
      perm.gate = null;
      expect(c.read(scanControllerProvider).phase, ScanPhase.needsPermission);
      await c.read(scanControllerProvider.notifier).refresh(force: false);
      expect(sc.calls, hasLength(1));
    });
    test('6-4 vừa quét xong + force:false ⇒ bỏ', () async {
      final sc = _Scanner(ScanResult(files: [_f('a.pdf')]));
      final c = make(scanner: sc);
      c.read(scanControllerProvider);
      await settle();
      await c.read(scanControllerProvider.notifier).refresh(force: false);
      expect(sc.calls, hasLength(1));
    });
    test('6-5 xong > 30 s trước ⇒ quét lại', () async {
      final sc = _Scanner(ScanResult(files: [_f('a.pdf')]));
      final c = make(scanner: sc);
      c.read(scanControllerProvider);
      await settle();
      final n = c.read(scanControllerProvider.notifier);
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      n.state = ScanState(phase: ScanPhase.done, lastFinishedAt: DateTime.now().subtract(const Duration(seconds: 60)));
      await n.refresh(force: false);
      expect(sc.calls, hasLength(2));
    });
    test('6-6 done mà last null ⇒ quét lại', () async {
      final sc = _Scanner(ScanResult(files: [_f('a.pdf')]));
      final c = make(scanner: sc);
      c.read(scanControllerProvider);
      await settle();
      final n = c.read(scanControllerProvider.notifier);
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      n.state = const ScanState(phase: ScanPhase.done);
      await n.refresh(force: false);
      expect(sc.calls, hasLength(2));
    });
    test('6-7 huỷ khi đang hỏi quyền ⇒ không quét, không ném', () async {
      final sc = _Scanner();
      final perm = _Perm()..gate = Completer();
      final c = make(scanner: sc, perm: perm);
      c.read(scanControllerProvider);
      await settle();
      c.dispose();
      perm.gate!.complete(true);
      await settle();
      expect(sc.calls, isEmpty);
    });
    test('6-8 chưa có quyền ⇒ needsPermission', () async {
      final sc = _Scanner();
      final c = make(scanner: sc, perm: _Perm(granted: false));
      c.read(scanControllerProvider);
      await settle();
      expect(sc.calls, isEmpty);
      expect(c.read(scanControllerProvider).phase, ScanPhase.needsPermission);
    });
  });

  group('U7/U8 requestPermissionAndScan + _scan', () {
    test('7-1 cấp quyền ⇒ true, done', () async {
      final perm = _Perm(granted: false);
      final c = make(perm: perm);
      c.read(scanControllerProvider);
      await settle();
      perm.granted = true;
      final r = await c.read(scanControllerProvider.notifier).requestPermissionAndScan();
      expect(c.read(scanControllerProvider).phase, ScanPhase.done);
      expect(r, isTrue);
    });
    test('7-2 từ chối ⇒ false, needsPermission', () async {
      final c = make(perm: _Perm(granted: false));
      c.read(scanControllerProvider);
      await settle();
      final r = await c.read(scanControllerProvider.notifier).requestPermissionAndScan();
      expect(c.read(scanControllerProvider).phase, ScanPhase.needsPermission);
      expect(r, isFalse);
    });
    test('7-3 huỷ khi đang xin quyền ⇒ false, không quét', () async {
      final sc = _Scanner();
      final perm = _Perm(granted: false);
      final c = make(scanner: sc, perm: perm);
      c.read(scanControllerProvider);
      await settle();
      perm.gate = Completer();
      final fut = c.read(scanControllerProvider.notifier).requestPermissionAndScan();
      c.dispose();
      perm.gate!.complete(true);
      expect(await fut, isFalse);
      expect(sc.calls, isEmpty);
    });
    test('8-1 một lượt ⇒ quét 1 lần', () async {
      final sc = _Scanner();
      final c = make(scanner: sc);
      c.read(scanControllerProvider);
      await settle();
      expect(sc.calls, hasLength(1));
    });
    test('8-2 hai lượt chồng nhau ⇒ quét 1 lần', () async {
      final sc = _Scanner();
      final c = make(scanner: sc, perm: _Perm(granted: false));
      c.read(scanControllerProvider);
      await settle();
      sc.gate = Completer();
      (c.read(storagePermissionProvider) as _Perm).granted = true;
      final n = c.read(scanControllerProvider.notifier);
      final a = n.requestPermissionAndScan();
      final b = n.requestPermissionAndScan();
      await settle();
      sc.gate!.complete();
      await Future.wait([a, b]);
      expect(sc.calls, hasLength(1));
    });
  });

  group('U9/U10 _runScan + onProgress', () {
    test('9-1 roots cố định, có file ⇒ done', () async {
      final sc = _Scanner(ScanResult(files: [_f('a.pdf')]));
      final c = make(scanner: sc);
      c.read(scanControllerProvider);
      await settle();
      expect(sc.calls.single, ['/root']);
      expect(c.read(scanControllerProvider).phase, ScanPhase.done);
    });
    test('9-2 roots rỗng ⇒ lấy theo nền tảng', () async {
      final sc = _Scanner(ScanResult(files: [_f('a.pdf')]));
      final c = make(scanner: sc, roots: const [], platformRoots: () async => ['/p']);
      c.read(scanControllerProvider);
      await settle();
      expect(sc.calls.single, ['/p']);
    });
    test('9-3 huỷ khi đang lấy roots nền tảng ⇒ không quét', () async {
      final sc = _Scanner();
      final g = Completer<List<String>>();
      final c = make(scanner: sc, roots: const [], platformRoots: () => g.future);
      c.read(scanControllerProvider);
      await settle();
      c.dispose();
      g.complete(['/p']);
      await settle();
      expect(sc.calls, isEmpty);
    });
    test('9-4 roots nền tảng rỗng ⇒ done, không quét', () async {
      final sc = _Scanner();
      final c = make(scanner: sc, roots: const [], platformRoots: () async => const []);
      c.read(scanControllerProvider);
      await settle();
      final s = c.read(scanControllerProvider);
      expect(sc.calls, isEmpty);
      expect(s.phase, ScanPhase.done);
      expect(s.lastFinishedAt, isNotNull);
    });
    test('9-5 scan ném ⇒ failed', () async {
      final sc = _Scanner()..error = const FileSystemException('x');
      final c = make(scanner: sc);
      c.read(scanControllerProvider);
      await settle();
      final s = c.read(scanControllerProvider);
      expect(s.phase, ScanPhase.failed);
      expect(s.error, isNotNull);
    });
    test('9-6 huỷ khi đang quét ⇒ không ném', () async {
      final sc = _Scanner(ScanResult(files: [_f('a.pdf')]))..gate = Completer();
      final c = make(scanner: sc);
      c.read(scanControllerProvider);
      await settle();
      c.dispose();
      sc.gate!.complete();
      await settle();
      expect(sc.calls, hasLength(1));
      expect(await db.documentsDao.getAll(), isEmpty);
    });
    test('9-7 0 gốc đọc được ⇒ needsPermission, không xoá bảng', () async {
      await db.documentsDao.upsertAll([_row('/root/old.pdf', 'old.pdf')]);
      final sc = _Scanner(const ScanResult(files: [], unreadableRoots: ['/root']));
      final c = make(scanner: sc);
      c.read(scanControllerProvider);
      await settle();
      expect(c.read(scanControllerProvider).phase, ScanPhase.needsPermission);
      expect(await db.documentsDao.getAll(), hasLength(1));
    });
    test('9-8 không file + thư mục con bị chặn ⇒ needsPermission', () async {
      final c = make(scanner: _Scanner(const ScanResult(files: [], skippedDirectories: 3)));
      c.read(scanControllerProvider);
      await settle();
      expect(c.read(scanControllerProvider).phase, ScanPhase.needsPermission);
    });
    test('9-9 không file, không bị chặn ⇒ done 0', () async {
      final c = make(scanner: _Scanner());
      c.read(scanControllerProvider);
      await settle();
      final s = c.read(scanControllerProvider);
      expect([s.phase, s.found], [ScanPhase.done, 0]);
    });
    test('9-10 sync ném (DB lỗi) ⇒ failed', () async {
      final c = make(scanner: _Scanner(ScanResult(files: [_f('a.pdf')])), database: _BrokenDb());
      c.read(scanControllerProvider);
      await settle();
      expect(c.read(scanControllerProvider).phase, ScanPhase.failed);
    });
    test('9-12 huỷ rồi scan ném ⇒ không ném ra ngoài', () async {
      final sc = _Scanner()
        ..gate = Completer()
        ..error = const FileSystemException('x');
      final c = make(scanner: sc);
      c.read(scanControllerProvider);
      await settle();
      final errors = <Object>[];
      await runZonedGuarded(() async {
        c.dispose();
        sc.gate!.complete();
        await settle();
      }, (e, _) => errors.add(e));
      expect(errors, isEmpty);
    });
    test('10-1 tiến độ ⇒ scanning, found 7', () async {
      final sc = _Scanner()
        ..progressValue = 7
        ..gate = Completer();
      final c = make(scanner: sc);
      c.read(scanControllerProvider);
      await settle();
      final s = c.read(scanControllerProvider);
      expect([s.phase, s.found], [ScanPhase.scanning, 7]);
      sc.gate!.complete();
      await settle();
    });
    test('10-2 báo tiến độ sau khi huỷ ⇒ không ném', () async {
      final sc = _Scanner()..gate = Completer();
      final c = make(scanner: sc);
      c.read(scanControllerProvider);
      await settle();
      c.dispose();
      expect(() => sc.lastProgress!(5), returnsNormally);
      sc.gate!.complete();
      await settle();
    });
  });

  group('U11/U12 _resolveExisting (recentItemsProvider)', () {
    Future<List<String>> names(ProviderContainer c) async {
      final sub = c.listen(recentItemsProvider, (_, _) {});
      addTearDown(sub.close);
      return (await c.read(recentItemsProvider.future)).map((d) => d.name).toList();
    }

    test('11-1 Gần đây rỗng ⇒ []', () async {
      final c = make();
      expect(await names(c), isEmpty);
    });
    test('11-2/12-3 documents chưa nạp ⇒ stat từ đĩa', () async {
      final f = file('a.pdf');
      await db.recentsDao.touch(f);
      final c = make();
      expect(await names(c), ['a.pdf']);
    });
    test('11-3/12-2 có trong documents ⇒ dùng metadata đã có', () async {
      final f = file('a.pdf');
      await db.recentsDao.touch(f);
      await db.documentsDao.upsertAll([
        _row(f, 'X.pdf'),
      ]);
      final c = make();
      final ds = c.listen(documentsProvider, (_, _) {});
      addTearDown(ds.close);
      await c.read(documentsProvider.future);
      expect(await names(c), ['X.pdf']);
    });
    test('12-1 file mất ⇒ bỏ', () async {
      await db.recentsDao.touch(p.join(tmp.path, 'gone.pdf'));
      final c = make();
      expect(await names(c), isEmpty);
    });
  });

  group('U13 _firstExisting (homeRecentItemsProvider)', () {
    Future<List<String>> names(ProviderContainer c) async {
      final sub = c.listen(homeRecentItemsProvider, (_, _) {});
      addTearDown(sub.close);
      return (await c.read(homeRecentItemsProvider.future)).map((d) => d.name).toList();
    }
    test('13-1 rỗng ⇒ []', () async => expect(await names(make()), isEmpty));
    test('13-2 1 file ⇒ 1', () async {
      await db.recentsDao.touch(file('a.pdf'));
      expect(await names(make()), ['a.pdf']);
    });
    test('13-3 bỏ file mất', () async {
      await db.recentsDao.touch(p.join(tmp.path, 'gone.pdf'), at: DateTime(2026, 1, 2));
      await db.recentsDao.touch(file('a.pdf'), at: DateTime(2026, 1, 1));
      expect(await names(make()), ['a.pdf']);
    });
    test('13-4 7 file ⇒ 5', () async {
      for (var i = 0; i < 7; i++) {
        await db.recentsDao.touch(file('f$i.pdf'), at: DateTime(2026, 1, i + 1));
      }
      expect(await names(make()), hasLength(5));
    });
  });

  group('U14 pdfLockedProvider', () {
    Future<(bool, int)> locked(String path, _Sec sec) async {
      final c = make(extra: [pdfSecurityProvider.overrideWithValue(sec)]);
      final sub = c.listen(pdfLockedProvider(path), (_, _) {});
      addTearDown(sub.close);
      final r = await c.read(pdfLockedProvider(path).future);
      return (r, sec.calls);
    }

    test('14-1 không phải PDF ⇒ false, không gọi engine', () async {
      final (r, calls) = await locked(file('a.txt', '/Encrypt'.codeUnits), _Sec());
      expect(calls, 0);
      expect(r, isFalse);
    });
    test('14-2 PDF không /Encrypt ⇒ false', () async {
      final (r, calls) = await locked(file('a.pdf', 'abc'.codeUnits), _Sec());
      expect(calls, 0);
      expect(r, isFalse);
    });
    test('14-3 có /Encrypt, engine true ⇒ true', () async {
      final (r, calls) = await locked(file('b.pdf', '/Encrypt'.codeUnits), _Sec());
      expect(calls, 1);
      expect(r, isTrue);
    });
    test('14-4 engine ném AppError ⇒ false', () async {
      final (r, calls) = await locked(file('c.pdf', '/Encrypt'.codeUnits), _Sec(error: const WrongPassword()));
      expect(calls, 1);
      expect(r, isFalse);
    });
  });
}
