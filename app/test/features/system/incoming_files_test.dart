import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/navigation/open_file_args.dart';
import 'package:pdf_office/core/router/app_router.dart';
import 'package:pdf_office/core/router/routes.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/features/system/incoming_files.dart';

class _FakeService extends IncomingFilesService {
  _FakeService([this.initial = const IncomingBatch()]);
  final IncomingBatch initial;
  void Function(IncomingBatch)? handler;
  var takeInitialCalls = 0;

  @override
  Future<IncomingBatch> takeInitial() async {
    takeInitialCalls++;
    return initial;
  }

  @override
  void setFilesHandler(void Function(IncomingBatch batch)? h) => handler = h;
}

/// Chỉ ghi lại các lần `push`; không dựng UI.
class _RecordingRouter implements GoRouter {
  final pushes = <(String, Object?)>[];

  @override
  Future<T?> push<T extends Object?>(String location, {Object? extra}) async {
    pushes.add((location, extra));
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late String cacheDir;
  late String importedDir;
  late AppDatabase db;
  late _RecordingRouter router;
  late List<IncomingNotice> notices;
  late List<String> externalOpened;
  late String? targetDir;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('incoming_files_');
    cacheDir = p.join(tmp.path, 'cache', 'incoming');
    importedDir = p.join(tmp.path, 'Documents', 'PDF Office', 'Imported');
    await Directory(cacheDir).create(recursive: true);
    db = AppDatabase(NativeDatabase.memory());
    router = _RecordingRouter();
    notices = [];
    externalOpened = [];
    targetDir = importedDir;
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  ProviderContainer makeContainer([_FakeService? service]) {
    final c = ProviderContainer(
      overrides: [
        incomingFilesServiceProvider.overrideWithValue(
          service ?? _FakeService(),
        ),
        appDatabaseProvider.overrideWithValue(db),
        appRouterProvider.overrideWithValue(router),
        incomingSourceRootsProvider.overrideWith((ref) async => [cacheDir]),
        incomingTargetDirProvider.overrideWith((ref) async => targetDir),
        incomingNotifierProvider.overrideWithValue(notices.addAll),
        incomingExternalOpenerProvider.overrideWithValue((path) async {
          externalOpened.add(path);
          return false;
        }),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  String cacheFile(String name, [List<int> bytes = const [1, 2, 3]]) {
    final f = File(p.join(cacheDir, name))..writeAsBytesSync(bytes);
    return f.path;
  }

  Future<void> handle(ProviderContainer c, IncomingBatch batch) =>
      handleIncomingBatch(c.read(_refProbe), batch);

  Future<void> waitFor(bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('khoi dong lanh: 1 PDF -> chep sang Imported, xoa cache, mo reader, ghi Gan day', () async {
    final src = cacheFile('a.pdf');
    final service = _FakeService(IncomingBatch(paths: [src]));
    final c = makeContainer(service);
    c.read(incomingFilesProvider);
    await waitFor(() => router.pushes.isNotEmpty);

    final saved = p.join(importedDir, 'a.pdf');
    expect(service.takeInitialCalls, 1);
    expect(router.pushes, [(Routes.pdfReader, OpenFileArgs(saved))]);
    expect(File(saved).existsSync(), isTrue);
    expect(File(src).existsSync(), isFalse);
    expect((await db.recentsDao.getRecent()).map((r) => r.path), [saved]);
    expect(notices, isEmpty);
  });

  test(
    'dang chay: onFiles 3 anh -> man sua Anh sang PDF, khong ghi Gan day',
    () async {
      final service = _FakeService();
      final c = makeContainer(service);
      c.read(incomingFilesProvider);
      await waitFor(() => service.takeInitialCalls > 0);
      expect(router.pushes, isEmpty);

      service.handler!(
        IncomingBatch(
          paths: [cacheFile('1.jpg'), cacheFile('2.png'), cacheFile('3.webp')],
        ),
      );
      await waitFor(() => router.pushes.isNotEmpty);

      expect(router.pushes, hasLength(1));
      final (route, extra) = router.pushes.single;
      expect(route, Routes.imageToPdf);
      expect(extra, [
        p.join(importedDir, '1.jpg'),
        p.join(importedDir, '2.png'),
        p.join(importedDir, '3.webp'),
      ]);
      expect(await db.recentsDao.getRecent(), isEmpty);
    },
  );

  test('PDF + anh -> mo PDF, bao da luu file con lai', () async {
    final c = makeContainer();
    await handle(
      c,
      IncomingBatch(paths: [cacheFile('x.jpg'), cacheFile('a.pdf')]),
    );
    expect(router.pushes, [
      (Routes.pdfReader, OpenFileArgs(p.join(importedDir, 'a.pdf'))),
    ]);
    expect(notices, [const IncomingNotice(IncomingNoticeKind.savedOthers, 1)]);
  });

  test('nhieu PDF -> man Gop voi file dau, ca hai vao Gan day', () async {
    final c = makeContainer();
    await handle(
      c,
      IncomingBatch(
        paths: [
          cacheFile('a.pdf'),
          cacheFile('b.pdf', [9]),
        ],
      ),
    );
    expect(router.pushes, [(Routes.merge, p.join(importedDir, 'a.pdf'))]);
    expect((await db.recentsDao.getRecent()).map((r) => r.path).toSet(), {
      p.join(importedDir, 'a.pdf'),
      p.join(importedDir, 'b.pdf'),
    });
    expect(notices, [const IncomingNotice(IncomingNoticeKind.savedOthers, 1)]);
  });

  test(
    'duoi la + path ngoai cache + loi native -> khong mo, bao loi',
    () async {
      final outside = File(p.join(tmp.path, 'secret.pdf'))
        ..writeAsBytesSync([1]);
      final c = makeContainer();
      await handle(
        c,
        IncomingBatch(
          paths: [
            cacheFile('a.exe'),
            outside.path,
            p.join(cacheDir, 'missing.pdf'),
          ],
          failed: 1,
          unsupported: 1,
        ),
      );
      expect(router.pushes, isEmpty);
      expect(notices, [
        const IncomingNotice(IncomingNoticeKind.unsupported),
        const IncomingNotice(IncomingNoticeKind.failed, 3),
      ]);
      // File ngoài vùng cho phép không bị chép đi đâu.
      expect(Directory(importedDir).existsSync(), isFalse);
    },
  );

  test('.doc doi cu -> app ngoai; khong mo duoc -> bao', () async {
    final c = makeContainer();
    await handle(c, IncomingBatch(paths: [cacheFile('old.doc')]));
    expect(externalOpened, [p.join(importedDir, 'old.doc')]);
    expect(router.pushes, isEmpty);
    expect(notices, [const IncomingNotice(IncomingNoticeKind.openFailed)]);
  });

  test('iOS (khong co thu muc dich): dung nguyen duong dan native', () async {
    targetDir = null;
    final src = cacheFile('r.xlsx');
    final c = makeContainer();
    await handle(c, IncomingBatch(paths: [src]));
    expect(router.pushes, [(Routes.xlsxViewer, src)]);
    expect(File(src).existsSync(), isTrue);
  });

  group('persistIncomingFile', () {
    test(
      'trung ten + cung dung luong -> dung lai; khac dung luong -> (1)',
      () async {
        final first = await persistIncomingFile(
          cacheFile('a.pdf', [1, 2]),
          importedDir,
        );
        final same = await persistIncomingFile(
          cacheFile('a.pdf', [3, 4]),
          importedDir,
        );
        final other = await persistIncomingFile(
          cacheFile('a.pdf', [5]),
          importedDir,
        );
        expect(first, p.join(importedDir, 'a.pdf'));
        expect(same, first);
        expect(other, p.join(importedDir, 'a (1).pdf'));
      },
    );

    test('da nam trong thu muc dich -> tra nguyen', () async {
      await Directory(importedDir).create(recursive: true);
      final inside = File(p.join(importedDir, 'z.pdf'))..writeAsBytesSync([1]);
      expect(await persistIncomingFile(inside.path, importedDir), inside.path);
    });
  });

  test('isWithinIncomingRoots', () {
    final inside = cacheFile('k.pdf');
    expect(isWithinIncomingRoots(inside, [cacheDir]), isTrue);
    expect(
      isWithinIncomingRoots(p.join(cacheDir, '..', 'k.pdf'), [cacheDir]),
      isFalse,
    );
    expect(isWithinIncomingRoots(inside, const []), isFalse);
  });
}

final _refProbe = Provider<Ref>((ref) => ref);
