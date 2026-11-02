// Kiểm thử hộp trắng (A09 · reader) — shortcut_launcher.dart.
// Bộ dữ liệu + expected chép từ test-output/whitebox/reader/shortcut_launcher/buoc-5-du-lieu-thu.md.
import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_office/core/navigation/open_file_args.dart';
import 'package:pdf_office/core/router/app_router.dart';
import 'package:pdf_office/core/router/routes.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/features/reader/shortcut/shortcut_launcher.dart';
import 'package:pdf_office/features/reader/shortcut/shortcut_service.dart';

class _Service extends ShortcutService {
  _Service(this.initial);
  final Future<String?> initial;
  void Function(String)? handler;
  final handlerLog = <String>[];

  @override
  Future<String?> takeInitialPath() => initial;

  @override
  void setOpenPathHandler(void Function(String path)? h) {
    handlerLog.add(h == null ? 'null' : 'set');
    handler = h;
  }
}

class _SpyRouter implements GoRouter {
  final pushes = <(String, Object?)>[];
  @override
  Future<T?> push<T extends Object?>(String location, {Object? extra}) async {
    pushes.add((location, extra));
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

final _refProbe = Provider<Ref>((ref) => ref);

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  late Directory tmp;
  late String pdf;
  late AppDatabase db;
  late _SpyRouter router;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('wb_a09_shortcut_');
    pdf = '${tmp.path}${Platform.pathSeparator}a.pdf';
    File(pdf).writeAsBytesSync([1, 2, 3]);
    db = AppDatabase(NativeDatabase.memory());
    router = _SpyRouter();
  });
  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  ProviderContainer make(_Service s) => ProviderContainer(
    overrides: [
      shortcutServiceProvider.overrideWithValue(s),
      appDatabaseProvider.overrideWithValue(db),
      appRouterProvider.overrideWithValue(router),
    ],
  );

  group('open', () {
    test('SL1-1 app đang chạy, native gọi openPath với PDF có thật ⇒ mở reader', () async {
      final s = _Service(Future.value(null));
      final c = make(s);
      addTearDown(c.dispose);
      c.read(shortcutLaunchProvider);
      await _settle();
      s.handler!(pdf);
      await _settle();
      expect(router.pushes, [(Routes.pdfReader, OpenFileArgs(pdf))]);
    });

    test('SL1-2 provider đã huỷ rồi mới tới đường dẫn ⇒ không điều hướng', () async {
      final initial = Completer<String?>();
      final s = _Service(initial.future);
      final c = make(s);
      c.read(shortcutLaunchProvider);
      final captured = s.handler!;
      c.dispose();
      expect(s.handlerLog, ['set', 'null']);
      captured(pdf);
      initial.complete(pdf);
      await _settle();
      expect(router.pushes, isEmpty);
      expect(await db.recentsDao.getRecent(), isEmpty);
    });
  });

  group('then-callback', () {
    test('SL2-1 app khởi động từ lối tắt (initial = PDF) ⇒ mở reader 1 lần', () async {
      final s = _Service(Future.value(pdf));
      final c = make(s);
      addTearDown(c.dispose);
      c.read(shortcutLaunchProvider);
      await _settle();
      expect(router.pushes, [(Routes.pdfReader, OpenFileArgs(pdf))]);
    });

    test('SL2-2 mở app bình thường (initial = null) ⇒ không điều hướng', () async {
      final s = _Service(Future.value(null));
      final c = make(s);
      addTearDown(c.dispose);
      c.read(shortcutLaunchProvider);
      await _settle();
      expect(router.pushes, isEmpty);
    });
  });

  group('openShortcutPath', () {
    late ProviderContainer c;
    setUp(() {
      c = make(_Service(Future.value(null)));
    });
    tearDown(() => c.dispose());

    test('SL3-1 PDF có thật ⇒ true, push reader với OpenFileArgs, ghi Gần đây', () async {
      final r = openShortcutPath(c.read(_refProbe), pdf);
      await _settle();
      expect(router.pushes, [(Routes.pdfReader, OpenFileArgs(pdf))]);
      expect((await db.recentsDao.getRecent()).map((e) => e.path), [pdf]);
      expect(r, isTrue);
    });

    test('SL3-2 file không phải PDF (có thật) ⇒ false, không điều hướng, không ghi Gần đây', () async {
      final txt = '${tmp.path}${Platform.pathSeparator}b.txt';
      File(txt).writeAsStringSync('x');
      final r = openShortcutPath(c.read(_refProbe), txt);
      await _settle();
      expect(router.pushes, isEmpty);
      expect(await db.recentsDao.getRecent(), isEmpty);
      expect(r, isFalse);
    });

    test('SL3-3 PDF không còn trên máy ⇒ false, không điều hướng', () async {
      final r = openShortcutPath(c.read(_refProbe), '${tmp.path}${Platform.pathSeparator}missing.pdf');
      await _settle();
      expect(router.pushes, isEmpty);
      expect(await db.recentsDao.getRecent(), isEmpty);
      expect(r, isFalse);
    });
  });
}
