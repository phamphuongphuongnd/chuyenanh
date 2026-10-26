import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_office/app.dart';
import 'package:pdf_office/core/router/app_router.dart';
import 'package:pdf_office/core/router/routes.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/features/documents/documents_logic.dart';
import 'package:pdf_office/features/documents/documents_providers.dart';
import 'package:pdf_office/features/documents/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  String? locale,
}) async {
  SharedPreferences.setMockInitialValues({SettingsRepository.kLocale: ?locale});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        // Stream của drift để lại timer sau khi cây widget bị huỷ → dùng giá trị cố định.
        documentsProvider.overrideWith(
          (ref) => Stream.value(const <DocItem>[]),
        ),
      ],
      child: const PdfOfficeApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PdfOfficeApp)));
}

void main() {
  testWidgets('app khởi động vào trang chủ Tài liệu', (tester) async {
    await _pumpApp(tester, locale: 'en');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.widgetWithText(Tab, 'All'), findsOneWidget);
  });

  testWidgets('locale từ cài đặt (vi)', (tester) async {
    await _pumpApp(tester, locale: 'vi');
    expect(find.widgetWithText(Tab, 'Tất cả'), findsOneWidget);
  });

  testWidgets('mọi route trong Routes đều đăng ký', (tester) async {
    final container = await _pumpApp(tester, locale: 'en');
    final router = container.read(appRouterProvider);
    final registered = router.configuration.routes
        .whereType<GoRoute>()
        .map((r) => r.path)
        .toSet();
    const all = [
      Routes.home,
      Routes.search,
      Routes.recents,
      Routes.favorites,
      Routes.imageToPdf,
      Routes.pdfReader,
      Routes.pdfToImage,
      Routes.merge,
      Routes.split,
      Routes.organize,
      Routes.lock,
      Routes.unlock,
      Routes.watermark,
      Routes.createBlank,
      Routes.annotate,
      Routes.sign,
      Routes.fillForm,
      Routes.textToPdf,
      Routes.wordToPdf,
      Routes.excelToPdf,
      Routes.pdfToText,
      Routes.pdfToWord,
      Routes.pdfToExcel,
      Routes.docxViewer,
      Routes.xlsxViewer,
      Routes.txtViewer,
      Routes.pptxViewer,
      Routes.scanner,
      Routes.settings,
      Routes.language,
      Routes.about,
    ];
    expect(registered, containsAll(all));

    router.push(Routes.merge, extra: '/x/a.pdf');
    await tester.pumpAndSettle();
    expect(find.text('/x/a.pdf'), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
  });
}
