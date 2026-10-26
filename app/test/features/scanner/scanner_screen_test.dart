import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/features/scanner/capture/document_capture.dart';
import 'package:pdf_office/features/scanner/model/scan_session.dart';
import 'package:pdf_office/features/scanner/ui/scanner_screen.dart';

class FakeCapture implements DocumentCapture {
  FakeCapture({this.pages, this.unavailable = false, this.denied = false});
  List<String>? pages;
  final bool unavailable, denied;
  int photoCalls = 0;
  int? lastMax;

  @override
  Future<List<String>?> scanPages({int maxPages = 100}) async {
    lastMax = maxPages;
    if (denied) throw const PermissionDenied();
    if (unavailable) throw const ScannerUnavailable();
    return pages;
  }

  @override
  Future<String?> takePhoto() async {
    photoCalls++;
    return null;
  }
}

Future<ProviderContainer> pump(
  WidgetTester tester,
  FakeCapture capture, {
  String locale = 'en',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [documentCaptureProvider.overrideWithValue(capture)],
      child: MaterialApp(
        locale: Locale(locale),
        supportedLocales: appLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const ScannerScreen(autoStart: false),
      ),
    ),
  );
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(ScannerScreen)));
}

void main() {
  testWidgets('trống: hiện hướng dẫn và nút quét', (tester) async {
    await pump(tester, FakeCapture());
    expect(find.text('No pages yet'), findsOneWidget);
    expect(find.text('Scan pages'), findsOneWidget);
    expect(find.text('Export'), findsNothing);
  });

  testWidgets('quét thêm trang → danh sách + nút Xuất', (tester) async {
    await pump(tester, FakeCapture(pages: ['a.jpg', 'b.jpg']));
    await tester.tap(find.text('Scan pages'));
    await tester.pumpAndSettle();
    expect(find.text('Page 1'), findsOneWidget);
    expect(find.text('Page 2'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
    expect(find.text('Add page'), findsOneWidget);
  });

  testWidgets('huỷ quét → vẫn trống', (tester) async {
    await pump(tester, FakeCapture(pages: null));
    await tester.tap(find.text('Scan pages'));
    await tester.pumpAndSettle();
    expect(find.text('No pages yet'), findsOneWidget);
  });

  testWidgets('xoá trang', (tester) async {
    final c = await pump(tester, FakeCapture());
    c.read(scanSessionProvider.notifier).addPaths(['a.jpg', 'b.jpg', 'c.jpg']);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete page').at(1));
    await tester.pumpAndSettle();
    expect(find.text('Page 3'), findsNothing);
    expect(c.read(scanSessionProvider).map((p) => p.path), ['a.jpg', 'c.jpg']);
  });

  testWidgets('đổi thứ tự cập nhật danh sách', (tester) async {
    final c = await pump(tester, FakeCapture());
    final n = c.read(scanSessionProvider.notifier);
    n.addPaths(['a.jpg', 'b.jpg', 'c.jpg']);
    await tester.pumpAndSettle();
    n.reorder(2, 0);
    await tester.pumpAndSettle();
    expect(c.read(scanSessionProvider).map((p) => p.path), [
      'c.jpg',
      'a.jpg',
      'b.jpg',
    ]);
    expect(find.text('Page 3'), findsOneWidget);
  });

  testWidgets('chụp lại thay đúng trang, quét 1 trang', (tester) async {
    final cap = FakeCapture(pages: ['new.jpg']);
    final c = await pump(tester, cap);
    c.read(scanSessionProvider.notifier).addPaths(['a.jpg', 'b.jpg']);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Retake').at(1));
    await tester.pumpAndSettle();
    expect(cap.lastMax, 1);
    expect(c.read(scanSessionProvider).map((p) => p.path), [
      'a.jpg',
      'new.jpg',
    ]);
  });

  testWidgets('máy không có trình quét → báo và chuyển sang chụp ảnh tay', (
    tester,
  ) async {
    final cap = FakeCapture(unavailable: true);
    await pump(tester, cap);
    await tester.tap(find.text('Scan pages'));
    await tester.pumpAndSettle();
    expect(cap.photoCalls, 1);
    expect(find.textContaining('not available on this device'), findsOneWidget);
  });

  testWidgets('thiếu quyền camera → báo lỗi quyền', (tester) async {
    await pump(tester, FakeCapture(denied: true));
    await tester.tap(find.text('Scan pages'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Permission denied'), findsOneWidget);
  });

  testWidgets('bộ lọc: chọn một bộ lọc cho một trang', (tester) async {
    final c = await pump(tester, FakeCapture());
    c.read(scanSessionProvider.notifier).addPaths(['a.jpg', 'b.jpg']);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Filter').first);
    await tester.pumpAndSettle();
    expect(find.text('Black & white'), findsOneWidget);
    expect(find.text('Apply to all pages'), findsOneWidget);
    await tester.tap(find.text('Grayscale'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final pages = c.read(scanSessionProvider);
    expect(pages[0].filter.name, 'grayscale');
    expect(pages[1].filter.name, 'original');
  });

  testWidgets('menu Xuất có PDF, DOCX, TXT và chọn ngôn ngữ OCR (vi → Latin)', (
    tester,
  ) async {
    final c = await pump(tester, FakeCapture(), locale: 'vi');
    c.read(scanSessionProvider.notifier).addPaths(['a.jpg']);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xuất'));
    await tester.pumpAndSettle();
    expect(find.text('PDF'), findsOneWidget);
    expect(find.textContaining('DOCX'), findsOneWidget);
    expect(find.textContaining('TXT'), findsOneWidget);
    expect(find.textContaining('Latin'), findsOneWidget);
  });

  testWidgets('thoát khi đã có trang → hỏi xác nhận bỏ', (tester) async {
    final c = await pump(tester, FakeCapture());
    c.read(scanSessionProvider.notifier).addPaths(['a.jpg']);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard scan?'), findsOneWidget);
  });
}
