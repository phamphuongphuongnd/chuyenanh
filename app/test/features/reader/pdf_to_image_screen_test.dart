import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/core/utils/output_directory.dart';
import 'package:pdf_office/engines/pdf/pdf_render_engine.dart';
import 'package:pdf_office/features/reader/reader_providers.dart';
import 'package:pdf_office/features/reader/screens/pdf_to_image_screen.dart';

import 'test_app.dart';

class _Doc implements PdfRenderDocument {
  _Doc(this.pageCount);
  @override
  final int pageCount;
  final List<(int, double, RenderFormat)> rendered = [];
  bool closed = false;

  @override
  Future<PdfPageSize> pageSize(int pageIndex) async =>
      const PdfPageSize(595, 842);

  @override
  Future<Uint8List> renderPage(
    int pageIndex, {
    double dpi = 150,
    RenderFormat format = RenderFormat.png,
    int jpgQuality = 90,
    CancelToken? cancelToken,
  }) async {
    rendered.add((pageIndex, dpi, format));
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<Uint8List> renderThumbnail(int pageIndex, {int maxSide = 300}) =>
      throw const CorruptFile('no thumbnail'); // man hinh phai chiu duoc

  @override
  Future<void> close() async => closed = true;
}

class _Engine implements PdfRenderEngine {
  _Engine(this.doc, {this.password});
  final _Doc doc;
  final String? password;
  final List<String?> attempts = [];

  @override
  Future<PdfRenderDocument> openFile(String path, {String? password}) async {
    attempts.add(password);
    if (this.password != null) {
      if (password == null) throw const PasswordRequired();
      if (password != this.password) throw const WrongPassword();
    }
    return doc;
  }

  @override
  Future<PdfRenderDocument> openBytes(Uint8List bytes) async => doc;
}

void main() {
  late Directory tmp;
  late _Doc doc;
  late List<List<String>> shared;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('p2i_screen_');
    doc = _Doc(12);
    shared = [];
  });

  tearDown(() => tmp.delete(recursive: true));

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 4; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  /// Chờ I/O thật cho tới khi [finder] xuất hiện (tối đa ~5 giây).
  Future<void> waitFor(WidgetTester t, Finder finder) async {
    for (var i = 0; i < 1000 && finder.evaluate().isEmpty; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await t.pump(const Duration(milliseconds: 5));
    }
  }

  Future<_Engine> pumpScreen(
    WidgetTester t, {
    String? path = '/x/Hop dong.pdf',
    String? password,
    String? pickerResult,
  }) async {
    final engine = _Engine(doc, password: password);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          pdfRenderEngineProvider.overrideWithValue(engine),
          outputDirectoryProvider.overrideWith((ref) async => tmp.path),
          pdfFilePickerProvider.overrideWithValue(() async => pickerResult),
          fileSharerProvider.overrideWithValue((paths) async => shared.add(paths)),
        ],
        child: testApp(PdfToImageScreen(path: path)),
      ),
    );
    await settle(t);
    return engine;
  }

  testWidgets('mo file: hien ten, so trang, kich thuoc anh du kien theo DPI', (t) async {
    await pumpScreen(t);
    expect(find.text('Hop dong.pdf'), findsOneWidget);
    expect(find.text('12 pages'), findsOneWidget);
    // A4 595x842 pt o 150 DPI.
    expect(find.text('About 1240 × 1754 px per page'), findsOneWidget);

    await t.tap(find.byKey(const Key('p2i_dpi_300')));
    await t.pump();
    expect(find.text('About 2479 × 3508 px per page'), findsOneWidget);
  });

  testWidgets('khong co duong dan: yeu cau chon file, chon xong thi mo', (t) async {
    await pumpScreen(t, path: null, pickerResult: '/y/Bao cao.pdf');
    expect(find.text('Choose a PDF file to convert to images'), findsOneWidget);
    await t.tap(find.text('Select file'));
    await settle(t);
    expect(find.text('Bao cao.pdf'), findsOneWidget);
    expect(find.text('12 pages'), findsOneWidget);
  });

  testWidgets('chuyen khoang trang 1-3,5 ra JPG: render dung trang, hien ket qua', (t) async {
    await pumpScreen(t, path: '/x/Hop dong.pdf');
    await t.tap(find.byKey(const Key('p2i_rangePages')));
    await t.pump();
    await t.enterText(find.byKey(const Key('p2i_rangeField')), '1-3, 5');
    await t.pump();
    expect(find.text('4 pages selected'), findsOneWidget);

    await t.tap(find.byKey(const Key('p2i_convert')));
    await settle(t);
    await waitFor(t, find.text("Conversion complete"));

    expect(doc.rendered.map((r) => r.$1), [0, 1, 2, 4]);
    expect(doc.rendered.every((r) => r.$2 == 150), isTrue);
    expect(doc.rendered.every((r) => r.$3 == RenderFormat.jpg), isTrue);
    expect(find.text('Conversion complete'), findsOneWidget);
    expect(find.text('4 images saved to:'), findsOneWidget);

    final outDir = Directory('${tmp.path}/Hop dong');
    expect(outDir.existsSync(), isTrue);
    expect(
      outDir.listSync().map((e) => e.uri.pathSegments.last).toList()..sort(),
      [
        'Hop dong_001.jpg',
        'Hop dong_002.jpg',
        'Hop dong_003.jpg',
        'Hop dong_005.jpg',
      ],
    );

    await t.tap(find.byKey(const Key('p2i_share')));
    await settle(t);
    expect(shared.single, hasLength(4));
  });

  testWidgets('tat ca trang, PNG, 72 DPI', (t) async {
    await pumpScreen(t);
    await t.tap(find.text('PNG'));
    await t.tap(find.byKey(const Key('p2i_dpi_72')));
    await t.pump();
    await t.tap(find.byKey(const Key('p2i_convert')));
    await settle(t);
    await waitFor(t, find.text("Conversion complete"));
    expect(doc.rendered, hasLength(12));
    expect(doc.rendered.first.$2, 72);
    expect(doc.rendered.first.$3, RenderFormat.png);
    expect(File('${tmp.path}/Hop dong/Hop dong_012.png').existsSync(), isTrue);
  });

  testWidgets('khoang trang sai: hien loi, khong render', (t) async {
    await pumpScreen(t);
    await t.tap(find.byKey(const Key('p2i_rangePages')));
    await t.pump();

    Future<void> tryRange(String text, String message) async {
      await t.enterText(find.byKey(const Key('p2i_rangeField')), text);
      await t.tap(find.byKey(const Key('p2i_convert')));
      await t.pump();
      expect(find.text(message), findsOneWidget, reason: 'input "$text"');
    }

    await tryRange('', 'Enter the pages to convert.');
    await tryRange('abc', 'Invalid format. Example: 1-3, 5');
    await tryRange('0-2', 'Pages must be between 1 and 12.');
    await tryRange('13', 'Pages must be between 1 and 12.');
    await tryRange('5-2', 'In a range, the first page must not come after the last page.');
    expect(doc.rendered, isEmpty);
  });

  testWidgets('PDF co mat khau: hoi mat khau, sai thi hoi lai, dung thi mo', (t) async {
    final engine = await pumpScreen(t, password: 'abc123');
    expect(find.text('Enter password'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'sai');
    await t.tap(find.text('OK').last);
    await settle(t);
    expect(find.text('Incorrect password.'), findsOneWidget);

    await t.enterText(find.byType(TextField).last, 'abc123');
    await t.tap(find.text('OK').last);
    await settle(t);
    expect(find.text('12 pages'), findsOneWidget);
    expect(engine.attempts, [null, 'sai', 'abc123']);
  });

  testWidgets('file loi: hien thong bao, cho chon file khac', (t) async {
    final engine = _Engine(doc);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          pdfRenderEngineProvider.overrideWithValue(
            _ThrowingEngine(const CorruptFile('x')),
          ),
          pdfFilePickerProvider.overrideWithValue(() async => null),
        ],
        child: testApp(const PdfToImageScreen(path: '/x/hong.pdf')),
      ),
    );
    await settle(t);
    expect(find.text('The file is damaged or cannot be read.'), findsOneWidget);
    expect(find.text('Select file'), findsOneWidget);
    expect(engine.attempts, isEmpty);
  });
}

class _ThrowingEngine implements PdfRenderEngine {
  _ThrowingEngine(this.error);
  final AppError error;

  @override
  Future<PdfRenderDocument> openFile(String path, {String? password}) =>
      Future.error(error);

  @override
  Future<PdfRenderDocument> openBytes(Uint8List bytes) => Future.error(error);
}
