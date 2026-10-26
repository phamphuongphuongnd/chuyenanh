import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/core/theme/app_theme.dart';
import 'package:pdf_office/engines/pdf/pdf_render_engine.dart';
import 'package:pdf_office/engines/pdf/pdf_sign_engine.dart';

/// PNG hợp lệ [w]x[h] một màu (dùng làm "ảnh trang" / "chữ ký" giả).
Uint8List testPng({int w = 20, int h = 10, int r = 255, int g = 255, int b = 255}) {
  final image = img.Image(width: w, height: h, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(r, g, b, 255));
  return Uint8List.fromList(img.encodePng(image));
}

/// Chờ tác vụ thật (I/O, giải mã ảnh) rồi dựng lại khung hình. Có [until] thì lặp tới khi điều kiện
/// đúng (tối đa ~6 giây).
Future<void> settle(WidgetTester tester, {bool Function()? until}) async {
  for (var i = 0; i < 120; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (until == null && i >= 2) break;
    if (until != null && until()) break;
  }
  await tester.pump(const Duration(milliseconds: 300));
}

/// Dựng app tối thiểu (l10n + theme), trang chủ có nút "open" đẩy [screen] lên — để thử cả
/// việc thoát màn hình (PopScope).
Future<void> pumpEditorScreen(
  WidgetTester tester, {
  required Widget screen,
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: locale,
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('open'),
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => screen)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

class FakeRenderDocument implements PdfRenderDocument {
  FakeRenderDocument(this.pageCount);

  @override
  final int pageCount;
  bool closed = false;

  @override
  Future<PdfPageSize> pageSize(int pageIndex) async =>
      const PdfPageSize(600, 800);

  @override
  Future<Uint8List> renderPage(
    int pageIndex, {
    double dpi = 150,
    RenderFormat format = RenderFormat.png,
    int jpgQuality = 90,
    CancelToken? cancelToken,
  }) async => testPng(w: 60, h: 80);

  @override
  Future<Uint8List> renderThumbnail(int pageIndex, {int maxSide = 300}) async =>
      testPng(w: 6, h: 8);

  @override
  Future<void> close() async => closed = true;
}

class FakeRenderEngine implements PdfRenderEngine {
  FakeRenderEngine({this.pages = 2, this.requiredPassword});

  final int pages;
  final String? requiredPassword;
  final List<String?> triedPasswords = [];
  late final FakeRenderDocument document = FakeRenderDocument(pages);

  @override
  Future<PdfRenderDocument> openFile(String path, {String? password}) async {
    triedPasswords.add(password);
    if (requiredPassword != null) {
      if (password == null) throw const PasswordRequired();
      if (password != requiredPassword) throw const WrongPassword();
    }
    return document;
  }

  @override
  Future<PdfRenderDocument> openBytes(Uint8List bytes) =>
      throw UnimplementedError();
}

class FakeSignEngine implements PdfSignEngine {
  List<SignaturePlacement>? placements;
  String? outputPath;
  String? password;
  int pageSizeCalls = 0;

  @override
  Future<String> applySignatures(
    String inputPath,
    List<SignaturePlacement> placements,
    String outputPath, {
    String? password,
  }) async {
    this.placements = placements;
    this.outputPath = outputPath;
    this.password = password;
    await File(outputPath).writeAsBytes([1, 2, 3]);
    return outputPath;
  }

  @override
  Future<Size> pageSize(
    String inputPath,
    int pageIndex, {
    String? password,
  }) async {
    pageSizeCalls++;
    return const Size(600, 800);
  }
}
