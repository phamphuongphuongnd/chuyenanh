// ignore_for_file: unnecessary_import
// Kiểm thử hộp trắng (A10, chủ đề core) — lib/core/navigation/open_document.dart.
// Bộ dữ liệu + kết quả mong đợi: test-output/whitebox/core/open_document/buoc-5-du-lieu-thu.md
// `File(path).exists()` được giả lập bằng IOOverrides (mock D1) để cả luồng chạy trong fake-async
// của testWidgets — không cần runAsync (lượt đầu dùng runAsync bị treo ở bộ 2.5).
import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/core/navigation/open_document.dart';
import 'package:pdf_office/core/router/routes.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/data/db/daos/recents_dao.dart';

/// Ghi lại `touch` thay vì ghi DB; có cổng chặn để chen giữa `touch` và `push`.
class _RecRecents extends RecentsDao {
  _RecRecents(super.attachedDatabase);
  final touched = <String>[];
  Completer<void>? gate;

  @override
  Future<void> touch(String path, {DateTime? at}) async {
    touched.add(path);
    if (gate != null) await gate!.future;
  }
}

class _FakeDb extends AppDatabase {
  _FakeDb() : super(NativeDatabase.memory());
  late final _RecRecents rec = _RecRecents(this);
  @override
  RecentsDao get recentsDao => rec;
}

/// File giả: chỉ trả lời `exists()`.
class _ExistsFile extends Fake implements File {
  _ExistsFile(this.path, this.exist);
  @override
  final String path;
  final bool exist;
  @override
  Future<bool> exists() async => exist;
}

/// Kết quả openDocument: null = chưa xong; 'ok' = trả về bình thường; còn lại = lỗi ném ra.
class _Result {
  Object? value;
  bool get done => value != null;
}

void main() {
  group('U1 routeForDocument', () {
    test('1.1 .pdf ⇒ trình đọc PDF', () {
      expect(routeForDocument('/a/x.pdf'), Routes.pdfReader);
    });
    test('1.2 .docx ⇒ trình xem DOCX', () {
      expect(routeForDocument('/a/x.docx'), Routes.docxViewer);
    });
    test('1.3 .xlsx ⇒ trình xem XLSX', () {
      expect(routeForDocument('/a/x.XLSX'), Routes.xlsxViewer);
    });
    test('1.4 .pptx ⇒ trình xem PPTX', () {
      expect(routeForDocument('/a/x.pptx'), Routes.pptxViewer);
    });
    test('1.5 .txt ⇒ trình xem TXT', () {
      expect(routeForDocument('/a/x.txt'), Routes.txtViewer);
    });
    test('1.6 .doc / .zip ⇒ null (app ngoài / không hỗ trợ)', () {
      expect(routeForDocument('/a/x.doc'), isNull);
      expect(routeForDocument('/a/x.zip'), isNull);
    });
  });

  group('U2 openDocument', () {
    late _FakeDb db;
    late List<(String, Object?)> pushed;
    late GoRouter router;
    late BuildContext homeCtx;

    setUp(() {
      db = _FakeDb();
      pushed = [];
      GoRoute page(String path) => GoRoute(
        path: path,
        builder: (_, state) {
          pushed.add((path, state.extra));
          return const SizedBox();
        },
      );
      router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Builder(
              builder: (c) {
                homeCtx = c;
                return const SizedBox();
              },
            ),
          ),
          page(Routes.pdfReader),
          page(Routes.docxViewer),
          page(Routes.xlsxViewer),
          page(Routes.pptxViewer),
          page(Routes.txtViewer),
        ],
      );
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> pumpApp(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    _Result start(
      BuildContext ctx,
      String path, {
      bool exists = true,
      String? password,
    }) {
      final r = _Result();
      IOOverrides.runZoned(() {
        openDocument(ctx, path, password: password)
            .then<Object?>((_) => 'ok', onError: (Object e) => e)
            .then((v) => r.value = v);
      }, createFile: (pth) => _ExistsFile(pth, exists));
      return r;
    }

    testWidgets('2.1 PDF có thật ⇒ ghi Gần đây, mở reader với OpenFileArgs(path, password)', (
      tester,
    ) async {
      await pumpApp(tester);
      const path = '/d/a.pdf';
      start(homeCtx, path, password: 'pw');
      await tester.pumpAndSettle();
      expect(db.rec.touched, [path]);
      expect(pushed, [(Routes.pdfReader, const OpenFileArgs(path, password: 'pw'))]);
    });

    testWidgets('2.2 file không tồn tại ⇒ ném CorruptFile, không ghi Gần đây, không mở màn', (
      tester,
    ) async {
      await pumpApp(tester);
      final r = start(homeCtx, '/d/missing.pdf', exists: false);
      await tester.pumpAndSettle();
      expect(db.rec.touched, isEmpty);
      expect(pushed, isEmpty);
      expect(r.value, isA<CorruptFile>());
    });

    testWidgets('2.3 context đã unmount khi kiểm file xong ⇒ thoát êm, không ghi, không mở', (
      tester,
    ) async {
      await pumpApp(tester);
      final stale = homeCtx;
      await tester.pumpWidget(const SizedBox());
      final r = start(stale, '/d/a.pdf');
      await tester.pumpAndSettle();
      expect(db.rec.touched, isEmpty);
      expect(pushed, isEmpty);
      expect(r.value, 'ok');
    });

    testWidgets('2.4 DOCX ⇒ ghi Gần đây, mở trình xem DOCX với extra = path (String)', (
      tester,
    ) async {
      await pumpApp(tester);
      const path = '/d/b.docx';
      start(homeCtx, path);
      await tester.pumpAndSettle();
      expect(db.rec.touched, [path]);
      expect(pushed, [(Routes.docxViewer, path)]);
    });

    testWidgets('2.5 context unmount trong lúc ghi Gần đây ⇒ không mở màn, không lỗi', (
      tester,
    ) async {
      await pumpApp(tester);
      const path = '/d/a.pdf';
      db.rec.gate = Completer<void>();
      final r = start(homeCtx, path);
      await tester.pump();
      expect(db.rec.touched, [path], reason: 'đã vào touch, đang chờ cổng');
      await tester.pumpWidget(const SizedBox());
      db.rec.gate!.complete();
      await tester.pumpAndSettle();
      expect(pushed, isEmpty);
      expect(r.value, 'ok');
    });

    testWidgets('2.6 loại không hỗ trợ (.zip) ⇒ ném UnsupportedFormat(zip), không mở màn', (
      tester,
    ) async {
      await pumpApp(tester);
      final r = start(homeCtx, '/d/c.zip');
      await tester.pumpAndSettle();
      expect(pushed, isEmpty);
      expect(r.value, isA<UnsupportedFormat>());
      expect((r.value! as UnsupportedFormat).extension, 'zip');
    });
  });
}
