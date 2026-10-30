import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/core/utils/output_directory.dart';
import 'package:pdf_office/features/id_card/id_card_screen.dart';
import 'package:pdf_office/features/id_card/id_card_services.dart';
import 'package:pdf_office/features/scanner/capture/document_capture.dart';

class FakeCapture implements DocumentCapture {
  FakeCapture({
    this.pages = const ['scan_front.jpg'],
    this.unavailable = false,
  });
  List<String>? pages;
  final bool unavailable;
  int? lastMax;
  int photoCalls = 0;

  @override
  Future<List<String>?> scanPages({int maxPages = 100}) async {
    lastMax = maxPages;
    if (unavailable) throw const ScannerUnavailable();
    return pages;
  }

  @override
  Future<String?> takePhoto() async {
    photoCalls++;
    return null;
  }
}

class FakeGallery implements IdCardGalleryPicker {
  String? next = 'gallery_back.jpg';
  @override
  Future<String?> pickImage() async => next;
}

class FakeComposer implements IdCardComposer {
  final requests = <IdCardRequest>[];
  // PNG hợp lệ để Image.memory không báo lỗi giải mã.
  final bytes = Uint8List.fromList(
    img.encodePng(img.Image(width: 2, height: 3)),
  );

  @override
  Future<Uint8List> compose(IdCardRequest request) async {
    requests.add(request);
    return bytes;
  }
}

class FakeExporter implements IdCardExporter {
  final calls = <({IdCardFormat format, String dir, String name})>[];

  @override
  Future<String> export({
    required Uint8List page,
    required IdCardFormat format,
    required String outputDir,
    required String baseName,
  }) async {
    calls.add((format: format, dir: outputDir, name: baseName));
    return '$outputDir/$baseName.${format.extension}';
  }
}

class Env {
  final capture = FakeCapture();
  final gallery = FakeGallery();
  final composer = FakeComposer();
  final exporter = FakeExporter();
  final cleaned = <String>[];
  final registered = <String>[];
}

Future<Env> pump(WidgetTester tester, {Env? env, FakeCapture? capture}) async {
  final e = env ?? Env();
  // Điện thoại rộng 390 nhưng cao 2400 để ListView dựng đủ mọi khối (cả ô xem trước).
  tester.view.physicalSize = const Size(1170, 7200);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        documentCaptureProvider.overrideWithValue(capture ?? e.capture),
        idCardGalleryPickerProvider.overrideWithValue(e.gallery),
        idCardComposerProvider.overrideWithValue(e.composer),
        idCardExporterProvider.overrideWithValue(e.exporter),
        idCardTempCleanerProvider.overrideWithValue(
          (paths) async => e.cleaned.addAll(paths),
        ),
        idCardRegisterOutputProvider.overrideWithValue(
          (path) async => e.registered.add(path),
        ),
        outputDirectoryProvider.overrideWith((ref) async => '/out'),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: appLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const IdCardScreen(),
      ),
    ),
  );
  await tester.pump();
  return e;
}

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> addFrontByScan(WidgetTester tester) async {
  await tapAndSettle(tester, find.byKey(const ValueKey('idcard_front')));
  await tapAndSettle(tester, find.byKey(const ValueKey('idcard_source_scan')));
}

Future<void> addBackFromGallery(WidgetTester tester) async {
  await tapAndSettle(tester, find.byKey(const ValueKey('idcard_back')));
  await tapAndSettle(
    tester,
    find.byKey(const ValueKey('idcard_source_gallery')),
  );
}

FilledButton exportButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.byWidgetPredicate((w) => w is FilledButton).last,
);

void main() {
  testWidgets('trống: 2 ô Mặt trước / Mặt sau, nút xuất tắt', (tester) async {
    await pump(tester);
    expect(find.text('Front'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Tap to scan or pick a photo'), findsNWidgets(2));
    expect(find.text('Add both sides to preview the page.'), findsOneWidget);
    expect(find.text('Export PDF'), findsOneWidget);
    expect(exportButton(tester).onPressed, isNull);
  });

  testWidgets(
    'quét mặt trước (1 trang) + thư viện mặt sau → xem trước, nút xuất bật',
    (tester) async {
      final e = await pump(tester);
      await addFrontByScan(tester);
      expect(e.capture.lastMax, 1);
      expect(find.text('Retake'), findsOneWidget);
      expect(e.composer.requests, isEmpty); // chưa đủ 2 mặt

      await addBackFromGallery(tester);
      expect(find.text('Retake'), findsNWidgets(2));
      expect(e.composer.requests, hasLength(1));
      final r = e.composer.requests.single;
      expect(r.preview, isTrue);
      expect(r.front.path, 'scan_front.jpg');
      expect(r.back.path, 'gallery_back.jpg');
      expect(find.text('Add both sides to preview the page.'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('idcard_preview')),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
      expect(exportButton(tester).onPressed, isNotNull);
    },
  );

  testWidgets('xoay 90° ghép lại xem trước với số lần xoay mới', (
    tester,
  ) async {
    final e = await pump(tester);
    await addFrontByScan(tester);
    await addBackFromGallery(tester);
    await tapAndSettle(tester, find.text('Rotate').first);
    await tester.pumpAndSettle();
    expect(e.composer.requests.last.front.turns, 1);
    expect(e.composer.requests.last.back.turns, 0);
  });

  testWidgets('chụp lại thay ảnh và dọn ảnh cũ', (tester) async {
    final e = await pump(tester);
    await addFrontByScan(tester);
    e.capture.pages = ['scan_front_2.jpg'];
    await tapAndSettle(tester, find.text('Retake').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('idcard_source_scan')));
    await tester.pumpAndSettle();
    expect(e.cleaned, contains('scan_front.jpg'));
    await addBackFromGallery(tester);
    expect(e.composer.requests.last.front.path, 'scan_front_2.jpg');
  });

  testWidgets('máy không có trình quét → báo và chụp ảnh tay', (tester) async {
    final cap = FakeCapture(unavailable: true);
    await pump(tester, capture: cap);
    await addFrontByScan(tester);
    expect(cap.photoCalls, 1);
    expect(find.textContaining('not available on this device'), findsOneWidget);
    expect(find.text('Retake'), findsNothing);
  });

  testWidgets(
    'xuất JPG: tên IDCard_yyyyMMdd_HHmmss, thẻ kết quả có Mở / Chia sẻ',
    (tester) async {
      final e = await pump(tester);
      await addFrontByScan(tester);
      await addBackFromGallery(tester);
      await tapAndSettle(
        tester,
        find.byKey(const ValueKey('idcard_format_jpg')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Save JPG'), findsOneWidget);
      await tester.tap(find.text('Save JPG'));
      await tester.pumpAndSettle();

      expect(e.exporter.calls, hasLength(1));
      final c = e.exporter.calls.single;
      expect(c.format, IdCardFormat.jpg);
      expect(c.dir, '/out');
      expect(c.name, matches(RegExp(r'^IDCard_\d{8}_\d{6}$')));
      // Bản xuất ghép ở độ phân giải đầy đủ.
      expect(e.composer.requests.last.preview, isFalse);
      expect(e.registered, isEmpty); // JPG không vào danh sách tài liệu
      expect(find.byKey(const ValueKey('idcard_result')), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Open'), findsWidgets);
      expect(find.text('Saved to out'), findsWidgets);
    },
  );

  testWidgets('xuất PDF ghi vào danh sách tài liệu', (tester) async {
    final e = await pump(tester);
    await addFrontByScan(tester);
    await addBackFromGallery(tester);
    await tester.tap(find.text('Export PDF'));
    await tester.pumpAndSettle();
    expect(e.exporter.calls.single.format, IdCardFormat.pdf);
    expect(e.registered, hasLength(1));
    expect(e.registered.single, endsWith('.pdf'));
  });

  testWidgets('rời màn → dọn mọi ảnh tạm', (tester) async {
    final e = await pump(tester);
    await addFrontByScan(tester);
    await addBackFromGallery(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(e.cleaned, containsAll(['scan_front.jpg', 'gallery_back.jpg']));
  });

  test('idCardFileName', () {
    expect(
      idCardFileName(DateTime(2026, 3, 7, 9, 5, 2)),
      'IDCard_20260307_090502',
    );
  });
}
