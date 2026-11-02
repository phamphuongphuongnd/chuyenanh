// Kiểm thử hộp trắng A13 — app/lib/features/documents/document_actions.dart
// Thiết kế: test-output/whitebox/documents/document_actions/buoc-1..5. Expected chép từ Bước 5.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/core/router/routes.dart';
import 'package:pdf_office/core/tools/tool_registry.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/features/documents/document_actions.dart';
import 'package:pdf_office/features/documents/documents_logic.dart';

final class _PF extends PlatformFile {
  _PF(this.name, this.uri);
  @override
  final String name;
  @override
  final Uri uri;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePicker extends FilePickerPlatform {
  PlatformFile? result;
  List<String>? lastExt;
  int calls = 0;
  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    calls++;
    lastExt = allowedExtensions;
    return result;
  }
}

void main() {
  late Directory tmp;
  late AppDatabase db;
  late _FakePicker picker;
  late FilePickerPlatform savedPicker;
  late BuildContext hostCtx;
  late WidgetRef hostRef;
  late ValueNotifier<bool> show;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('wb_docact_');
    db = AppDatabase(NativeDatabase.memory());
    picker = _FakePicker();
    savedPicker = FilePickerPlatform.instance;
    FilePickerPlatform.instance = picker;
    show = ValueNotifier(true);
  });
  tearDown(() async {
    FilePickerPlatform.instance = savedPicker;
    await db.close();
    if (Platform.isWindows) Process.runSync('attrib', ['-R', '${tmp.path}\\*', '/S', '/D']);
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // còn handle
    }
  });

  String file(String n, [String s = 'x']) => (File(p.join(tmp.path, n))..writeAsStringSync(s)).path;

  Future<void> pumpApp(WidgetTester t) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (c, s) => Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: show,
              builder: (_, v, _) => v
                  ? Consumer(
                      builder: (ctx, ref, _) {
                        hostCtx = ctx;
                        hostRef = ref;
                        return const Text('HOST');
                      },
                    )
                  : const SizedBox(),
            ),
          ),
        ),
        GoRoute(path: Routes.txtViewer, builder: (c, s) => Text('TXT:${s.extra}')),
        GoRoute(path: Routes.annotate, builder: (c, s) => Text('ANN:${s.extra}')),
        GoRoute(path: Routes.imageToPdf, builder: (c, s) => Text('IMG:${s.extra}')),
      ],
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  /// Cho tương lai [f] chạy xong (có I/O thật) rồi dựng lại khung hình.
  Future<Object?> drive(WidgetTester t, Future<void> f) async {
    var done = false;
    Object? err;
    f.then((_) => done = true, onError: (Object e) {
      err = e;
      done = true;
    });
    for (var i = 0; i < 200 && !done; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await t.pump();
    }
    await t.pumpAndSettle();
    return done ? (err ?? 'ok') : 'timeout';
  }

  AppLocalizations l() => AppLocalizations.of(hostCtx);
  Future<List<String>> recents(WidgetTester t) async =>
      (await t.runAsync(() => db.recentsDao.getRecent()))!.map((r) => r.path).toList();

  group('U1 openDocumentWithFeedback', () {
    testWidgets('1-1 mở được .txt ⇒ viewer, Gần đây', (t) async {
      await pumpApp(t);
      final f = file('a.txt');
      final r = await drive(t, openDocumentWithFeedback(hostCtx, f));
      expect(find.text('TXT:$f'), findsOneWidget);
      expect(await recents(t), [f]);
      expect(find.byType(SnackBar), findsNothing);
      // openDocument chờ push tới khi trang đóng ⇒ tương lai chưa xong là đúng.
      expect(r, 'timeout');
    });
    testWidgets('1-2 file mất ⇒ SnackBar docs_fileMissing', (t) async {
      await pumpApp(t);
      final msg = l().docs_fileMissing;
      final r = await drive(t, openDocumentWithFeedback(hostCtx, p.join(tmp.path, 'none.txt')));
      expect(find.text(msg), findsOneWidget);
      expect(r, 'ok');
    });
    testWidgets('1-3 đuôi không hỗ trợ ⇒ SnackBar lỗi khác', (t) async {
      await pumpApp(t);
      final msg = l().docs_fileMissing;
      final r = await drive(t, openDocumentWithFeedback(hostCtx, file('a.xyz')));
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(msg), findsNothing);
      expect(r, 'ok');
    });
    testWidgets('1-4 gỡ widget trước khi lỗi về ⇒ không SnackBar', (t) async {
      await pumpApp(t);
      final fut = openDocumentWithFeedback(hostCtx, p.join(tmp.path, 'none.txt'));
      show.value = false;
      await t.pump();
      final r = await drive(t, fut);
      expect(find.byType(SnackBar), findsNothing);
      expect(r, 'ok');
    });
  });

  group('U2 pickAndOpenDocument', () {
    testWidgets('2-1 huỷ ⇒ không chuyển trang', (t) async {
      await pumpApp(t);
      picker.result = null;
      await drive(t, pickAndOpenDocument(hostCtx));
      expect(picker.calls, 1);
      expect(find.text('HOST'), findsOneWidget);
    });
    testWidgets('2-2 file không có path ⇒ không chuyển trang', (t) async {
      await pumpApp(t);
      picker.result = _PF('a.pdf', Uri.parse('https://x/a.pdf'));
      await drive(t, pickAndOpenDocument(hostCtx));
      expect(find.text('HOST'), findsOneWidget);
    });
    testWidgets('2-3 chọn .txt ⇒ mở viewer', (t) async {
      await pumpApp(t);
      final f = file('a.txt');
      picker.result = _PF('a.txt', Uri.file(f));
      await drive(t, pickAndOpenDocument(hostCtx));
      expect(find.text('TXT:$f'), findsOneWidget);
    });
  });

  group('U5 deleteDocument', () {
    Future<(Future<void>,)> start(WidgetTester t, DocItem item) async {
      final fut = deleteDocument(hostCtx, hostRef, item);
      await t.pumpAndSettle();
      return (fut,);
    }

    DocItem item(String path) => DocItem(
      path: path,
      name: p.basename(path),
      ext: 'txt',
      size: 1,
      modified: DateTime(2026),
      folder: p.basename(tmp.path),
    );

    testWidgets('5-1 xoá ⇒ file mất, Gần đây rỗng, SnackBar docs_deleted', (t) async {
      await pumpApp(t);
      final f = file('a.txt');
      await t.runAsync(() => db.recentsDao.touch(f));
      final msg = l().docs_deleted('a.txt');
      final (fut,) = await start(t, item(f));
      await t.tap(find.text(l().core_delete));
      final r = await drive(t, fut);
      expect(File(f).existsSync(), isFalse);
      expect(await recents(t), isEmpty);
      expect(find.text(msg), findsOneWidget);
      expect(r, 'ok');
    });
    testWidgets('5-2 huỷ ⇒ file còn', (t) async {
      await pumpApp(t);
      final f = file('a.txt');
      final (fut,) = await start(t, item(f));
      await t.tap(find.text(l().core_cancel));
      await drive(t, fut);
      expect(File(f).existsSync(), isTrue);
    });
    testWidgets('5-3 file đã mất ⇒ chỉ bỏ khỏi DB', (t) async {
      await pumpApp(t);
      final f = p.join(tmp.path, 'gone.txt');
      await t.runAsync(() => db.recentsDao.touch(f));
      final msg = l().docs_deleted('gone.txt');
      final (fut,) = await start(t, item(f));
      await t.tap(find.text(l().core_delete));
      await drive(t, fut);
      expect(await recents(t), isEmpty);
      expect(find.text(msg), findsOneWidget);
    });
    testWidgets('5-4 xoá lỗi (chỉ-đọc) ⇒ file còn, SnackBar lỗi', (t) async {
      await pumpApp(t);
      final f = file('ro.txt');
      Process.runSync('attrib', ['+R', f]);
      final msg = l().docs_deleted('ro.txt');
      final (fut,) = await start(t, item(f));
      await t.tap(find.text(l().core_delete));
      final r = await drive(t, fut);
      expect(File(f).existsSync(), isTrue);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(msg), findsNothing);
      expect(r, 'ok');
    }, skip: !Platform.isWindows);
    testWidgets('5-5 gỡ widget khi hộp thoại mở ⇒ không xoá', (t) async {
      await pumpApp(t);
      final f = file('a.txt');
      final del = l().core_delete;
      final (fut,) = await start(t, item(f));
      show.value = false;
      await t.pump();
      await t.tap(find.text(del));
      final r = await drive(t, fut);
      expect(File(f).existsSync(), isTrue);
      expect(r, 'ok');
    });
  });

  group('U6 launchTool', () {
    ToolSpec tool(String id) => allTools.firstWhere((e) => e.id == id);
    testWidgets('6-1 công cụ tự chọn file ⇒ push không extra', (t) async {
      await pumpApp(t);
      await drive(t, launchTool(hostCtx, tool('imageToPdf')));
      expect(picker.calls, 0);
      expect(find.text('IMG:null'), findsOneWidget);
    });
    testWidgets('6-2 pdfRequired, huỷ ⇒ không chuyển', (t) async {
      await pumpApp(t);
      await drive(t, launchTool(hostCtx, tool('annotate')));
      expect(picker.lastExt, ['pdf']);
      expect(find.text('HOST'), findsOneWidget);
    });
    testWidgets('6-3 file không có path ⇒ không chuyển', (t) async {
      await pumpApp(t);
      picker.result = _PF('a.pdf', Uri.parse('https://x/a.pdf'));
      await drive(t, launchTool(hostCtx, tool('annotate')));
      expect(find.text('HOST'), findsOneWidget);
    });
    testWidgets('6-4 chọn PDF ⇒ push(route, extra: path)', (t) async {
      await pumpApp(t);
      final f = file('a.pdf');
      picker.result = _PF('a.pdf', Uri.file(f));
      await drive(t, launchTool(hostCtx, tool('annotate')));
      expect(find.text('ANN:$f'), findsOneWidget);
    });
  });

  // Đặt cuối file: lỗi framework (controller bị dispose khi hộp thoại còn đóng) làm hỏng cây widget của test sau.
  group('U3/U4 renameDocument', () {
    Future<(Future<void>,)> start(WidgetTester t, String path) async {
      final fut = renameDocument(hostCtx, hostRef, DocItem.fromFileSync(path)!);
      await t.pumpAndSettle();
      return (fut,);
    }

    Future<void> typeAndOk(WidgetTester t, String s) async {
      await t.enterText(find.byType(TextField), s);
      await t.tap(find.text(l().core_ok));
      await t.pump();
    }

    testWidgets('3-1/4-1 đổi tên ⇒ file mới, Gần đây cập nhật', (t) async {
      await pumpApp(t);
      final old = file('old.txt');
      await t.runAsync(() => db.recentsDao.touch(old));
      final (fut,) = await start(t, old);
      await typeAndOk(t, 'new');
      final r = await drive(t, fut);
      final nw = p.join(tmp.path, 'new.txt');
      expect(find.byType(TextField), findsNothing);
      expect(File(nw).existsSync(), isTrue);
      expect(File(old).existsSync(), isFalse);
      expect(await recents(t), [nw]);
      expect(r, 'ok');
    });
    testWidgets('3-2 huỷ ⇒ giữ nguyên', (t) async {
      await pumpApp(t);
      final old = file('old.txt');
      final (fut,) = await start(t, old);
      await t.tap(find.text(l().core_cancel));
      await drive(t, fut);
      expect(File(old).existsSync(), isTrue);
    });
    testWidgets('3-3 giữ tên ⇒ không đổi, không SnackBar', (t) async {
      await pumpApp(t);
      final old = file('old.txt');
      final (fut,) = await start(t, old);
      await typeAndOk(t, 'old');
      await drive(t, fut);
      expect(File(old).existsSync(), isTrue);
      expect(find.byType(SnackBar), findsNothing);
    });
    testWidgets('3-4 file nguồn mất ⇒ SnackBar docs_renameFailed', (t) async {
      await pumpApp(t);
      final old = file('old.txt');
      final (fut,) = await start(t, old);
      File(old).deleteSync();
      await typeAndOk(t, 'x');
      final msg = l().docs_renameFailed;
      final r = await drive(t, fut);
      expect(find.text(msg), findsOneWidget);
      expect(r, 'ok');
    });
    testWidgets('3-5 đích là thư mục ⇒ SnackBar lỗi khác renameFailed', (t) async {
      await pumpApp(t);
      final old = file('old.txt');
      Directory(p.join(tmp.path, 'dst.txt')).createSync();
      final (fut,) = await start(t, old);
      await typeAndOk(t, 'dst');
      final msg = l().docs_renameFailed;
      final r = await drive(t, fut);
      expect(File(old).existsSync(), isTrue);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(msg), findsNothing);
      expect(r, 'ok');
    });
    testWidgets('4-2 tên rỗng ⇒ hộp thoại còn, báo docs_renameEmpty', (t) async {
      await pumpApp(t);
      final (fut,) = await start(t, file('old.txt'));
      await typeAndOk(t, '   ');
      await t.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(l().docs_renameEmpty), findsOneWidget);
      await t.tap(find.text(l().core_cancel));
      await drive(t, fut);
    });
    testWidgets('4-3 tên đã có ⇒ báo docs_renameExists', (t) async {
      await pumpApp(t);
      file('b.txt');
      final (fut,) = await start(t, file('old.txt'));
      await typeAndOk(t, 'b');
      await t.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(l().docs_renameExists), findsOneWidget);
      await t.tap(find.text(l().core_cancel));
      await drive(t, fut);
    });
  });

}
