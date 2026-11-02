// ignore_for_file: depend_on_referenced_packages
// Kiểm thử hộp trắng A13 — app/lib/features/system/incoming_files.dart
// Thiết kế: test-output/whitebox/system/incoming_files/buoc-1..5. Expected chép từ Bước 5.
// Mock theo test/features/system/incoming_files_test.dart; path_provider qua PathProviderPlatform.instance.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/core/navigation/open_file_args.dart';
import 'package:pdf_office/core/platform/app_platform.dart';
import 'package:pdf_office/core/router/app_router.dart';
import 'package:pdf_office/core/router/routes.dart';
import 'package:pdf_office/core/utils/output_directory.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/features/system/incoming_files.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

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

class _FakePathProvider extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  _FakePathProvider(this.temp, this.docs);
  final String temp;
  final String docs;
  @override
  Future<String?> getTemporaryPath() async => temp;
  @override
  Future<String?> getApplicationDocumentsPath() async => docs;
}

final _refProbe = Provider<Ref>((ref) => ref);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late String cacheDir;
  late String importedDir;
  late AppDatabase db;
  late _RecordingRouter router;
  late List<IncomingNotice> notices;
  late int notifyCalls;
  late List<String> externalOpened;
  late bool externalOk;
  late Future<String?> Function() targetDir;
  late int rootsReads;
  late PathProviderPlatform savedPath;

  setUp(() async {
    savedPath = PathProviderPlatform.instance;
    tmp = await Directory.systemTemp.createTemp('wb_incoming_');
    cacheDir = p.join(tmp.path, 'cache', 'incoming');
    importedDir = p.join(tmp.path, 'Documents', 'PDF Office', 'Imported');
    await Directory(cacheDir).create(recursive: true);
    db = AppDatabase(NativeDatabase.memory());
    router = _RecordingRouter();
    notices = [];
    notifyCalls = 0;
    externalOpened = [];
    externalOk = false;
    targetDir = () async => importedDir;
    rootsReads = 0;
  });

  tearDown(() async {
    PathProviderPlatform.instance = savedPath;
    await db.close();
    if (Platform.isWindows) {
      Process.runSync('attrib', ['-R', '${tmp.path}\\*', '/S', '/D']);
    }
    try {
      await tmp.delete(recursive: true);
    } on FileSystemException {
      // Windows còn giữ handle — bỏ qua.
    }
  });

  ProviderContainer makeContainer([_FakeService? service]) {
    final c = ProviderContainer(
      overrides: [
        incomingFilesServiceProvider.overrideWithValue(service ?? _FakeService()),
        appDatabaseProvider.overrideWithValue(db),
        appRouterProvider.overrideWithValue(router),
        incomingSourceRootsProvider.overrideWith((ref) async {
          rootsReads++;
          return [cacheDir];
        }),
        incomingTargetDirProvider.overrideWith((ref) => targetDir()),
        incomingNotifierProvider.overrideWithValue((n) {
          notifyCalls++;
          notices.addAll(n);
        }),
        incomingExternalOpenerProvider.overrideWithValue((path) async {
          externalOpened.add(path);
          return externalOk;
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

  String outsideFile(String name) {
    final f = File(p.join(tmp.path, name))..writeAsBytesSync([7, 7]);
    return f.path;
  }

  Future<void> handle(ProviderContainer c, IncomingBatch b, {bool Function()? isActive}) =>
      handleIncomingBatch(c.read(_refProbe), b, isActive: isActive);

  /// isActive trả false từ lần gọi thứ [n].
  bool Function() falseAt(int n) {
    var k = 0;
    return () => ++k < n;
  }

  Future<void> waitFor(bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<List<String>> recents() async => (await db.recentsDao.getRecent()).map((r) => r.path).toList();
  String imp(String n) => p.join(importedDir, n);

  group('U1/U2 run + enqueue', () {
    test('1-1 khởi động lạnh: takeInitial 1 lần, mở PDF', () async {
      final src = cacheFile('a.pdf');
      final s = _FakeService(IncomingBatch(paths: [src]));
      final c = makeContainer(s);
      c.read(incomingFilesProvider);
      await waitFor(() => router.pushes.isNotEmpty);
      expect(s.takeInitialCalls, 1);
      expect(router.pushes, [(Routes.pdfReader, OpenFileArgs(imp('a.pdf')))]);
    });
    test('1-2 đã xếp hàng rồi huỷ ⇒ không xử lý', () async {
      final src = cacheFile('a.pdf');
      final s = _FakeService();
      final c = makeContainer(s);
      c.read(incomingFilesProvider);
      await waitFor(() => s.takeInitialCalls > 0);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      s.handler!(IncomingBatch(paths: [src]));
      c.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(rootsReads, 0);
      expect(router.pushes, isEmpty);
      expect(File(src).existsSync(), isTrue);
    });
    test('2-1 onFiles khi đang chạy ⇒ mở', () async {
      final s = _FakeService();
      final c = makeContainer(s);
      c.read(incomingFilesProvider);
      await waitFor(() => s.takeInitialCalls > 0);
      s.handler!(IncomingBatch(paths: [cacheFile('a.pdf')]));
      await waitFor(() => router.pushes.isNotEmpty);
      expect(router.pushes, [(Routes.pdfReader, OpenFileArgs(imp('a.pdf')))]);
    });
    test('2-2 lô rỗng ⇒ bỏ, không đọc roots', () async {
      final s = _FakeService();
      final c = makeContainer(s);
      c.read(incomingFilesProvider);
      await waitFor(() => s.takeInitialCalls > 0);
      s.handler!(const IncomingBatch());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(rootsReads, 0);
      expect(notifyCalls, 0);
    });
    test('2-3 gọi hàm enqueue sau khi huỷ ⇒ không xử lý', () async {
      final src = cacheFile('a.pdf');
      final s = _FakeService();
      final c = makeContainer(s);
      c.read(incomingFilesProvider);
      await waitFor(() => s.takeInitialCalls > 0);
      final h = s.handler!;
      c.dispose();
      expect(s.handler, isNull);
      h(IncomingBatch(paths: [src]));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(rootsReads, 0);
      expect(router.pushes, isEmpty);
    });
  });

  group('U3/U4 provider thư mục', () {
    ProviderContainer plat(AppPlatform pf) {
      PathProviderPlatform.instance = _FakePathProvider(p.join(tmp.path, 'T'), p.join(tmp.path, 'D'));
      final c = ProviderContainer(
        overrides: [
          appPlatformProvider.overrideWithValue(pf),
          outputDirectoryProvider.overrideWith((ref) async => p.join(tmp.path, 'O')),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('3-1 android ⇒ [tmp/incoming]', () async {
      expect(await plat(AppPlatform.android).read(incomingSourceRootsProvider.future), [p.join(tmp.path, 'T', 'incoming')]);
    });
    test('3-2 ios ⇒ [Documents/Imported]', () async {
      expect(await plat(AppPlatform.ios).read(incomingSourceRootsProvider.future), [p.join(tmp.path, 'D', 'Imported')]);
    });
    test('3-3 other ⇒ []', () async {
      expect(await plat(AppPlatform.other).read(incomingSourceRootsProvider.future), isEmpty);
    });
    test('4-1 android ⇒ out/Imported', () async {
      expect(await plat(AppPlatform.android).read(incomingTargetDirProvider.future), p.join(tmp.path, 'O', 'Imported'));
    });
    test('4-2 ios ⇒ null', () async {
      expect(await plat(AppPlatform.ios).read(incomingTargetDirProvider.future), isNull);
    });
  });

  group('U5 IncomingNotice.==', () {
    const n = IncomingNotice(IncomingNoticeKind.failed, 2);
    test('5-1 cùng ⇒ true', () => expect(n == const IncomingNotice(IncomingNoticeKind.failed, 2), isTrue));
    test('5-2 khác kiểu ⇒ false', () => expect(n == ('x' as Object), isFalse));
    test('5-3 khác kind ⇒ false', () => expect(n == const IncomingNotice(IncomingNoticeKind.unsupported, 2), isFalse));
    test('5-4 khác count ⇒ false', () => expect(n == const IncomingNotice(IncomingNoticeKind.failed, 3), isFalse));
  });

  group('U6 incomingNoticeText', () {
    test('6-1…6-4 mỗi loại ra đúng chuỗi', () async {
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      expect(incomingNoticeText(l, const IncomingNotice(IncomingNoticeKind.unsupported, 3)), l.incoming_unsupported);
      expect(incomingNoticeText(l, const IncomingNotice(IncomingNoticeKind.failed, 3)), l.incoming_failed(3));
      expect(incomingNoticeText(l, const IncomingNotice(IncomingNoticeKind.openFailed, 3)), l.incoming_openFailed);
      expect(incomingNoticeText(l, const IncomingNotice(IncomingNoticeKind.savedOthers, 3)), l.incoming_savedOthers(3));
    });
  });

  group('U7 showIncomingNotices', () {
    Widget nav() => Navigator(
      key: rootNavigatorKey,
      onGenerateRoute: (_) => PageRouteBuilder<void>(pageBuilder: (a, b, c) => const SizedBox()),
    );

    testWidgets('7-1 rỗng ⇒ không SnackBar', (t) async {
      await t.pumpWidget(MaterialApp(navigatorKey: rootNavigatorKey, home: const Scaffold()));
      showIncomingNotices(const []);
      await t.pump();
      expect(find.byType(SnackBar), findsNothing);
    });
    test('7-2 chưa có navigator ⇒ không ném', () {
      expect(rootNavigatorKey.currentContext, isNull);
      expect(() => showIncomingNotices(const [IncomingNotice(IncomingNoticeKind.unsupported)]), returnsNormally);
    });
    testWidgets('7-3 thiếu l10n ⇒ không ném, không SnackBar', (t) async {
      await t.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: nav()));
      expect(rootNavigatorKey.currentContext, isNotNull);
      showIncomingNotices(const [IncomingNotice(IncomingNoticeKind.unsupported)]);
      await t.pump();
      expect(t.takeException(), isNull);
      expect(find.byType(SnackBar), findsNothing);
    });
    testWidgets('7-4 thiếu ScaffoldMessenger ⇒ không ném', (t) async {
      await t.pumpWidget(
        Localizations(
          locale: const Locale('en'),
          delegates: const [AppLocalizations.delegate, DefaultWidgetsLocalizations.delegate],
          child: Directionality(textDirection: TextDirection.ltr, child: nav()),
        ),
      );
      await t.pumpAndSettle();
      showIncomingNotices(const [IncomingNotice(IncomingNoticeKind.unsupported)]);
      await t.pump();
      expect(t.takeException(), isNull);
      expect(find.byType(SnackBar), findsNothing);
    });
    testWidgets('7-5 đủ ⇒ 1 SnackBar 2 dòng', (t) async {
      await t.pumpWidget(
        MaterialApp(
          navigatorKey: rootNavigatorKey,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(),
        ),
      );
      await t.pumpAndSettle();
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      showIncomingNotices(const [
        IncomingNotice(IncomingNoticeKind.unsupported),
        IncomingNotice(IncomingNoticeKind.failed, 2),
      ]);
      await t.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('${l.incoming_unsupported}\n${l.incoming_failed(2)}'), findsOneWidget);
    });
  });

  group('U8 alive', () {
    test('8-1 không truyền isActive ⇒ xử lý đủ', () async {
      final c = makeContainer();
      await handle(c, IncomingBatch(paths: [cacheFile('a.pdf')]));
      expect(router.pushes, hasLength(1));
    });
    test('8-2 isActive luôn true ⇒ xử lý đủ', () async {
      final c = makeContainer();
      await handle(c, IncomingBatch(paths: [cacheFile('a.pdf')]), isActive: () => true);
      expect(router.pushes, hasLength(1));
    });
  });

  group('U9 handleIncomingBatch', () {
    test('9-1 1 PDF ⇒ chép Imported, xoá cache, Gần đây, mở reader', () async {
      final src = cacheFile('a.pdf');
      final c = makeContainer();
      await handle(c, IncomingBatch(paths: [src]));
      expect(File(imp('a.pdf')).existsSync(), isTrue);
      expect(File(src).existsSync(), isFalse);
      expect(await recents(), [imp('a.pdf')]);
      expect(router.pushes, [(Routes.pdfReader, OpenFileArgs(imp('a.pdf')))]);
      expect(notifyCalls, 0);
    });
    test('9-2 lô rỗng ⇒ không mở, không thông báo', () async {
      final c = makeContainer();
      await handle(c, const IncomingBatch());
      expect(router.pushes, isEmpty);
      expect(notifyCalls, 0);
    });
    test('9-3 đuôi lạ ⇒ báo unsupported, không chép', () async {
      final c = makeContainer();
      await handle(c, IncomingBatch(paths: [cacheFile('a.exe')]));
      expect(router.pushes, isEmpty);
      expect(File(imp('a.exe')).existsSync(), isFalse);
      expect(notices, [const IncomingNotice(IncomingNoticeKind.unsupported)]);
    });
    test('9-4 PDF ngoài thư mục native ⇒ từ chối, failed 1', () async {
      final out = outsideFile('secret.pdf');
      final c = makeContainer();
      await handle(c, IncomingBatch(paths: [out]));
      expect(router.pushes, isEmpty);
      expect(File(imp('secret.pdf')).existsSync(), isFalse);
      expect(File(out).existsSync(), isTrue);
      expect(notices, [const IncomingNotice(IncomingNoticeKind.failed, 1)]);
    });
    test('9-5 PDF đã mất ⇒ failed 1', () async {
      final c = makeContainer();
      await handle(c, IncomingBatch(paths: [p.join(cacheDir, 'missing.pdf')]));
      expect(router.pushes, isEmpty);
      expect(notices, [const IncomingNotice(IncomingNoticeKind.failed, 1)]);
    });
    test('9-6 isActive false ngay ⇒ không làm gì', () async {
      final src = cacheFile('a.pdf');
      final c = makeContainer();
      await handle(c, IncomingBatch(paths: [src]), isActive: () => false);
      expect(File(imp('a.pdf')).existsSync(), isFalse);
      expect(router.pushes, isEmpty);
      expect(notifyCalls, 0);
    });
    test('9-7 đọc thư mục đích ném ⇒ mở bản cache', () async {
      targetDir = () async => throw StateError('cfg');
      final src = cacheFile('a.pdf');
      final c = makeContainer();
      await handle(c, IncomingBatch(paths: [src]));
      expect(router.pushes, [(Routes.pdfReader, OpenFileArgs(src))]);
      expect(File(src).existsSync(), isTrue);
    });
    test('9-8 thư mục đích null (iOS) ⇒ mở nguyên path', () async {
      targetDir = () async => null;
      final src = cacheFile('a.pdf');
      final c = makeContainer();
      await handle(c, IncomingBatch(paths: [src]));
      expect(router.pushes, [(Routes.pdfReader, OpenFileArgs(src))]);
      expect(File(src).existsSync(), isTrue);
    });
    test('9-9 chép lỗi (đích là file) ⇒ mở bản cache', () async {
      final blocker = File(p.join(tmp.path, 'blocker'))..writeAsStringSync('x');
      targetDir = () async => blocker.path;
      final src = cacheFile('a.pdf');
      final c = makeContainer();
      await handle(c, IncomingBatch(paths: [src]));
      expect(router.pushes, [(Routes.pdfReader, OpenFileArgs(src))]);
    });
    test('9-10 đã nằm trong thư mục đích ⇒ không xoá', () async {
      targetDir = () async => cacheDir;
      final src = cacheFile('a.pdf');
      final c = makeContainer();
      await handle(c, IncomingBatch(paths: [src]));
      expect(router.pushes, [(Routes.pdfReader, OpenFileArgs(src))]);
      expect(File(src).existsSync(), isTrue);
    });
    test('9-11 isActive false lần 2 ⇒ đã chép, chưa Gần đây, không mở', () async {
      final c = makeContainer();
      await handle(c, IncomingBatch(paths: [cacheFile('a.pdf')]), isActive: falseAt(2));
      expect(File(imp('a.pdf')).existsSync(), isTrue);
      expect(await recents(), isEmpty);
      expect(router.pushes, isEmpty);
    });
    test('9-12 chỉ ảnh ⇒ không Gần đây, mở Ảnh sang PDF', () async {
      final c = makeContainer();
      await handle(c, IncomingBatch(paths: [cacheFile('x.jpg')]));
      expect(await recents(), isEmpty);
      expect(router.pushes, hasLength(1));
      expect(router.pushes.single.$1, Routes.imageToPdf);
      expect(router.pushes.single.$2, [imp('x.jpg')]);
    });
    test('9-13 isActive false lần 3 ⇒ có Gần đây, không mở', () async {
      final c = makeContainer();
      await handle(c, IncomingBatch(paths: [cacheFile('a.pdf')]), isActive: falseAt(3));
      expect(await recents(), [imp('a.pdf')]);
      expect(router.pushes, isEmpty);
    });
    test('9-14 .doc mở được bằng app ngoài ⇒ không thông báo', () async {
      externalOk = true;
      final c = makeContainer();
      await handle(c, IncomingBatch(paths: [cacheFile('old.doc')]));
      expect(externalOpened, [imp('old.doc')]);
      expect(router.pushes, isEmpty);
      expect(notifyCalls, 0);
    });
    test('9-15 .doc không mở được ⇒ openFailed', () async {
      final c = makeContainer();
      await handle(c, IncomingBatch(paths: [cacheFile('old.doc')]));
      expect(externalOpened, [imp('old.doc')]);
      expect(notices, [const IncomingNotice(IncomingNoticeKind.openFailed)]);
    });
    test('9-16 2 PDF ⇒ Gộp với file đầu, savedOthers 1', () async {
      final c = makeContainer();
      await handle(c, IncomingBatch(paths: [cacheFile('a.pdf'), cacheFile('b.pdf', [9])]));
      expect(router.pushes, [(Routes.merge, imp('a.pdf'))]);
      expect(notices, [const IncomingNotice(IncomingNoticeKind.savedOthers, 1)]);
    });
    test('9-17 DOCX ⇒ viewer, extra là path', () async {
      final c = makeContainer();
      await handle(c, IncomingBatch(paths: [cacheFile('r.docx')]));
      expect(router.pushes, [(Routes.docxViewer, imp('r.docx'))]);
    });
    test('9-18 có thông báo nhưng isActive false lần 4 ⇒ không gọi notifier', () async {
      final c = makeContainer();
      await handle(c, IncomingBatch(paths: [cacheFile('a.exe')]), isActive: falseAt(4));
      expect(notifyCalls, 0);
    });
    test('9-19 PDF + exe ⇒ mở PDF, báo unsupported', () async {
      final c = makeContainer();
      await handle(c, IncomingBatch(paths: [cacheFile('a.pdf'), cacheFile('a.exe')]));
      expect(router.pushes, [(Routes.pdfReader, OpenFileArgs(imp('a.pdf')))]);
      expect(notices, [const IncomingNotice(IncomingNoticeKind.unsupported)]);
    });
    test('9-20 ngoài vùng + hợp lệ ⇒ mở hợp lệ, failed 1', () async {
      final c = makeContainer();
      await handle(c, IncomingBatch(paths: [outsideFile('secret.pdf'), cacheFile('a.pdf')]));
      expect(router.pushes, [(Routes.pdfReader, OpenFileArgs(imp('a.pdf')))]);
      expect(notices, [const IncomingNotice(IncomingNoticeKind.failed, 1)]);
    });
    test('9-21 chỉ số đếm native ⇒ unsupported + failed 2', () async {
      final c = makeContainer();
      await handle(c, const IncomingBatch(failed: 2, unsupported: 1));
      expect(router.pushes, isEmpty);
      expect(notices, [
        const IncomingNotice(IncomingNoticeKind.unsupported),
        const IncomingNotice(IncomingNoticeKind.failed, 2),
      ]);
    });
    test('9-22 PDF + ảnh ⇒ mở PDF, savedOthers 1', () async {
      final c = makeContainer();
      await handle(c, IncomingBatch(paths: [cacheFile('a.pdf'), cacheFile('x.jpg')]));
      expect(router.pushes, [(Routes.pdfReader, OpenFileArgs(imp('a.pdf')))]);
      expect(notices, [const IncomingNotice(IncomingNoticeKind.savedOthers, 1)]);
    });
    test('9-23 DOC + PDF ⇒ mở DOC đầu bằng app ngoài, savedOthers 1', () async {
      externalOk = true;
      final c = makeContainer();
      await handle(c, IncomingBatch(paths: [cacheFile('old.doc'), cacheFile('a.pdf')]));
      expect(externalOpened, [imp('old.doc')]);
      expect(notices, [const IncomingNotice(IncomingNoticeKind.savedOthers, 1)]);
    });
    test('9-24 cùng path 2 lần ⇒ Gộp với bản đã lưu', () async {
      final src = cacheFile('a.pdf');
      final c = makeContainer();
      await handle(c, IncomingBatch(paths: [src, src]));
      expect(router.pushes, [(Routes.merge, imp('a.pdf'))]);
    });
    test('9-25 junction trong cache trỏ ra ngoài ⇒ từ chối', () async {
      final outDir = Directory(p.join(tmp.path, 'outside'))..createSync();
      final secret = File(p.join(outDir.path, 's.pdf'))..writeAsBytesSync([5]);
      Link(p.join(cacheDir, 'link')).createSync(outDir.path);
      final c = makeContainer();
      await handle(c, IncomingBatch(paths: [p.join(cacheDir, 'link', 's.pdf')]));
      expect(router.pushes, isEmpty);
      expect(File(imp('s.pdf')).existsSync(), isFalse);
      expect(secret.existsSync(), isTrue);
      expect(notices, [const IncomingNotice(IncomingNoticeKind.failed, 1)]);
    });
    test('9-26 cache/../secret.pdf ⇒ từ chối', () async {
      File(p.join(tmp.path, 'cache', 'secret.pdf')).writeAsBytesSync([5]);
      final c = makeContainer();
      await handle(c, IncomingBatch(paths: [p.join(cacheDir, '..', 'secret.pdf')]));
      expect(router.pushes, isEmpty);
      expect(notices, [const IncomingNotice(IncomingNoticeKind.failed, 1)]);
    });
  });

  group('U10 _realPath / isWithinIncomingRoots', () {
    test('10-1 file có thật trong vùng ⇒ true', () {
      expect(isWithinIncomingRoots(cacheFile('k.pdf'), [cacheDir]), isTrue);
    });
    test('10-2 không tồn tại / thư mục anh em / roots rỗng', () {
      expect(isWithinIncomingRoots(p.join(cacheDir, 'zz.pdf'), [cacheDir]), isTrue);
      final sib = p.join(tmp.path, 'cache', 'incoming2', 'k.pdf');
      expect(isWithinIncomingRoots(sib, [cacheDir]), isFalse);
      expect(isWithinIncomingRoots(cacheFile('k.pdf'), const []), isFalse);
    });
  });

  group('U11 persistIncomingFile', () {
    test('11-1 đã trong dir ⇒ trả nguyên', () async {
      final src = cacheFile('a.pdf');
      expect(await persistIncomingFile(src, cacheDir), src);
    });
    test('11-2 dir trống ⇒ chép a.pdf', () async {
      final r = await persistIncomingFile(cacheFile('a.pdf', [1, 2]), importedDir);
      expect(r, imp('a.pdf'));
      expect(File(r).readAsBytesSync(), [1, 2]);
    });
    test('11-3 cùng tên cùng cỡ cùng nội dung ⇒ dùng lại', () async {
      Directory(importedDir).createSync(recursive: true);
      File(imp('a.pdf')).writeAsBytesSync([1, 2]);
      final r = await persistIncomingFile(cacheFile('a.pdf', [1, 2]), importedDir);
      expect(r, imp('a.pdf'));
      expect(File(imp('a (1).pdf')).existsSync(), isFalse);
    });
    test('11-3b cùng tên cùng cỡ KHÁC nội dung ⇒ a (1), giữ bản cũ', () async {
      Directory(importedDir).createSync(recursive: true);
      File(imp('a.pdf')).writeAsBytesSync([9, 9]);
      final r = await persistIncomingFile(cacheFile('a.pdf', [1, 2]), importedDir);
      expect(r, imp('a (1).pdf'));
      expect(File(imp('a.pdf')).readAsBytesSync(), [9, 9]);
      expect(File(r).readAsBytesSync(), [1, 2]);
    });
    test('11-4 cùng tên khác cỡ ⇒ a (1)', () async {
      Directory(importedDir).createSync(recursive: true);
      File(imp('a.pdf')).writeAsBytesSync([9]);
      expect(await persistIncomingFile(cacheFile('a.pdf', [1, 2]), importedDir), imp('a (1).pdf'));
    });
    test('11-5 a (1) cùng nội dung ⇒ dùng lại a (1)', () async {
      Directory(importedDir).createSync(recursive: true);
      File(imp('a.pdf')).writeAsBytesSync([9]);
      File(imp('a (1).pdf')).writeAsBytesSync([1, 2]);
      expect(await persistIncomingFile(cacheFile('a.pdf', [1, 2]), importedDir), imp('a (1).pdf'));
      expect(File(imp('a (2).pdf')).existsSync(), isFalse);
    });
  });

  group('U12 _deleteQuietly', () {
    test('12-1 xoá được bản cache', () async {
      final src = cacheFile('a.pdf');
      await handle(makeContainer(), IncomingBatch(paths: [src]));
      expect(File(src).existsSync(), isFalse);
    });
    test('12-2 xoá lỗi (chỉ-đọc) ⇒ nuốt lỗi, vẫn mở', () async {
      final src = cacheFile('a.pdf');
      Process.runSync('attrib', ['+R', src]);
      final c = makeContainer();
      final r = await handle(c, IncomingBatch(paths: [src])).then<Object>((_) => 'ok', onError: (Object e) => e);
      expect(File(src).existsSync(), isTrue);
      expect(router.pushes, [(Routes.pdfReader, OpenFileArgs(imp('a.pdf')))]);
      expect(r, 'ok');
    }, testOn: 'windows');
  });

  group('U13 openWithExternalApp', () {
    test('13-1 không có path_provider ⇒ false, không ném', () async {
      final r = await openWithExternalApp(cacheFile('old.doc')).then((v) => v as Object, onError: (Object e) => e);
      expect(r, isFalse);
    });
  });
}
