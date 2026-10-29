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

    // ---------- Xem file ----------
    await open(Routes.pdfReader, OpenFileArgs(fx.pdf), 'view-pdf');
    await snap('20-view-pdf');
    await home();

    await open(Routes.docxViewer, fx.docx, 'view-docx');
    await snap('21-view-docx');
    await home();

    await open(Routes.xlsxViewer, fx.xlsx, 'view-xlsx');
    await snap('22-view-xlsx');
    await home();

    await open(Routes.txtViewer, fx.txt, 'view-txt');
    await snap('23-view-txt');
    await home();

    // ---------- Ảnh -> PDF ----------
    await open(Routes.imageToPdf, [fx.png, fx.jpg], 'img2pdf-open');
    await snap('30-img-to-pdf-edit');
    final create = find.byKey(const ValueKey('create_button'));
    await waitFor(tester, binding, create, 'img2pdf-create-button');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await waitFor(
      tester,
      binding,
      find.byKey(const ValueKey('result_name')),
      'img2pdf-result',
    );
    await snap('31-img-to-pdf-result');
    await home();

    // ---------- Chuyển đổi (có đường dẫn đầu vào) ----------
    Future<void> convert(String route, String input, String name) async {
      await open(route, input, '$name-open');
      await snap('$name-1-before');
      final button = find
          .descendant(
            of: find.byType(ConvertScreen),
            matching: find.byType(FilledButton),
          )
          .first;
      await tester.tap(button);
      await waitFor(
        tester,
        binding,
        find.byIcon(Icons.check_circle),
        '$name-done',
      );
      await snap('$name-2-done');
      await home();
    }

    await convert(Routes.wordToPdf, fx.docx, '32-word-to-pdf');
    await convert(Routes.excelToPdf, fx.xlsx, '33-excel-to-pdf');
    await convert(Routes.textToPdf, fx.txt, '34-text-to-pdf');
    await convert(Routes.pdfToText, fx.pdf, '35-pdf-to-text');
    await convert(Routes.pdfToWord, fx.pdf, '36-pdf-to-word');
    await convert(Routes.pdfToExcel, fx.pdf, '37-pdf-to-excel');

    // ---------- PDF -> ảnh ----------
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
}
