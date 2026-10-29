import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdf_office/app.dart';
import 'package:pdf_office/core/navigation/open_file_args.dart';
import 'package:pdf_office/core/router/app_router.dart';
import 'package:pdf_office/core/router/routes.dart';
import 'package:pdf_office/features/convert/convert_screen.dart';

import 'support/boot.dart';
import 'support/fixtures.dart';
import 'support/steps.dart';

/// Đợt 2: xem file + chuyển đổi (không quét camera/OCR). Bộ chọn file hệ thống không điều khiển
/// được trên simulator nên mở thẳng route bằng đường dẫn file mẫu do test tự sinh.
///
/// Lỗi từng kịch bản KHÔNG làm test ném lỗi: `flutter drive` treo (không kết thúc, mất hết ảnh) khi
/// test thất bại. Thay vào đó mỗi kịch bản bắt lỗi, chụp `FAIL-<tên>`, in `SCENARIO FAIL` ra log rồi chạy
/// tiếp; workflow đọc log sau khi đã đăng ảnh để báo đỏ.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('xem file và chuyển đổi, chụp ảnh từng bước', (tester) async {
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    final fx = await makeFixtures();

    await pumpApp(tester, locale: 'en');
    await settle(tester, binding, 'boot');
    final router = ProviderScope.containerOf(
      tester.element(find.byType(PdfOfficeApp)),
    ).read(appRouterProvider);

    final failures = <String>[];

    Future<void> open(String route, Object? extra, String label) async {
      unawaited(router.push<Object?>(route, extra: extra));
      await pumpFor(tester, binding, label);
    }

    Future<void> snap(String name) async {
      await pumpFor(
        tester,
        binding,
        name,
        duration: const Duration(seconds: 2),
      );
      await binding.takeScreenshot(name);
    }

    Future<void> home() async {
      router.go(Routes.home);
      await pumpFor(tester, binding, 'home');
    }

    /// Chạy một kịch bản; lỗi thì ghi nhận và quay về Trang chủ để kịch bản sau chạy tiếp.
    Future<void> scenario(String name, Future<void> Function() body) async {
      try {
        await body();
        // ignore: avoid_print
        print('SCENARIO OK $name');
      } catch (e) {
        failures.add(name);
        // ignore: avoid_print
        print('SCENARIO FAIL $name: $e');
        try {
          await binding.takeScreenshot('FAIL-$name');
        } catch (_) {}
      }
      try {
        await home();
      } catch (_) {}
    }

    // ---------- Xem file ----------
    await scenario('20-view-pdf', () async {
      await open(Routes.pdfReader, OpenFileArgs(fx.pdf), 'view-pdf');
      await snap('20-view-pdf');
    });
    await scenario('21-view-docx', () async {
      await open(Routes.docxViewer, fx.docx, 'view-docx');
      await snap('21-view-docx');
    });
    await scenario('22-view-xlsx', () async {
      await open(Routes.xlsxViewer, fx.xlsx, 'view-xlsx');
      await snap('22-view-xlsx');
    });
    await scenario('23-view-txt', () async {
      await open(Routes.txtViewer, fx.txt, 'view-txt');
      await snap('23-view-txt');
    });

    // ---------- Ảnh -> PDF ----------
    await scenario('30-img-to-pdf', () async {
      await open(Routes.imageToPdf, [fx.png, fx.jpg], 'img2pdf-open');
      await snap('30-img-to-pdf-1-edit');
      final create = find.byKey(const ValueKey('create_button'));
      await waitFor(tester, binding, create, 'img2pdf-create-button');
      await tester.ensureVisible(create);
      await tester.tap(create);
      // Bấm "Tạo PDF" mở bảng tuỳ chọn (tên file, khổ giấy); phải xác nhận mới tạo.
      final confirm = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(FilledButton),
      );
      await waitFor(tester, binding, confirm, 'img2pdf-options-sheet');
      await snap('30-img-to-pdf-2-options');
      await tester.tap(confirm.last);
      await waitFor(
        tester,
        binding,
        find.byKey(const ValueKey('result_name')),
        'img2pdf-result',
      );
      await snap('30-img-to-pdf-3-result');
    });

    // ---------- Chuyển đổi (có đường dẫn đầu vào) ----------
    Future<void> convert(String route, String input, String name) =>
        scenario(name, () async {
          await open(route, input, '$name-open');
          await snap('$name-1-before');
          final button = find
              .descendant(
                of: find.byType(ConvertScreen),
                matching: find.byType(FilledButton),
              )
              .first;
          await tester.ensureVisible(button);
      await tester.tap(button);
          await waitFor(
            tester,
            binding,
            find.byIcon(Icons.check_circle),
            '$name-done',
          );
          await snap('$name-2-done');
        });

    await convert(Routes.wordToPdf, fx.docx, '32-word-to-pdf');
    await convert(Routes.excelToPdf, fx.xlsx, '33-excel-to-pdf');
    await convert(Routes.textToPdf, fx.txt, '34-text-to-pdf');
    await convert(Routes.pdfToText, fx.pdf, '35-pdf-to-text');
    await convert(Routes.pdfToWord, fx.pdf, '36-pdf-to-word');
    await convert(Routes.pdfToExcel, fx.pdf, '37-pdf-to-excel');

    // ---------- PDF -> ảnh ----------
    await scenario('38-pdf-to-image', () async {
      await open(Routes.pdfToImage, fx.pdf, 'pdf2img-open');
      await snap('38-pdf-to-image-1-before');
      final convertButton = find.byKey(const Key('p2i_convert'));
      await waitFor(tester, binding, convertButton, 'pdf2img-button');
      await tester.ensureVisible(convertButton);
      await tester.tap(convertButton);
      await waitFor(
        tester,
        binding,
        find.byKey(const Key('p2i_resultPath')),
        'pdf2img-done',
      );
      await snap('38-pdf-to-image-2-done');
    });

    // ---------- OCR: PDF chỉ chứa ảnh có chữ → TXT, đọc file kết quả ----------
    await scenario('39-ocr-pdf-to-text', () async {
      await open(Routes.pdfToText, fx.ocrPdf, 'ocr-open');
      await snap('39-ocr-1-before');
      final button = find
          .descendant(
            of: find.byType(ConvertScreen),
            matching: find.byType(FilledButton),
          )
          .first;
      await tester.ensureVisible(button);
      await tester.tap(button);
      // OCR chạy lâu hơn chuyển đổi thường; "No text found" hiện ở SnackBar nếu OCR không ra chữ.
      await waitFor(
        tester,
        binding,
        find.byIcon(Icons.check_circle),
        'ocr-done',
        timeout: const Duration(seconds: 180),
      );
      await snap('39-ocr-2-done');
      final saved = find.textContaining('.txt');
      expect(saved, findsWidgets);
      final label = tester.widget<Text>(saved.first).data ?? '';
      final match = RegExp(r'(/.*[.]txt)').firstMatch(label);
      expect(match, isNotNull, reason: 'khong tim thay duong dan file .txt trong "$label"');
      final text = File(match!.group(1)!).readAsStringSync();
      // ignore: avoid_print
      print('OCR RESULT: "$text"');
      expect(
        text.toUpperCase().contains('HELLO'),
        isTrue,
        reason: 'OCR khong nhan ra chu, ket qua: "$text"',
      );
    });

    // ignore: avoid_print
    print(
      failures.isEmpty
          ? 'SCENARIOS ALL OK'
          : 'SCENARIOS FAILED ${failures.length}: ${failures.join(', ')}',
    );
  });
}
