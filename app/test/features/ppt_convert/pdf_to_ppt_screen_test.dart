import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/core/utils/output_directory.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/engines/pdf/pdf_render_engine.dart';
import 'package:pdf_office/features/pdf_tools/pdf_tools_providers.dart';
import 'package:pdf_office/features/pdf_tools/ui/pdf_file_picker.dart';
import 'package:pdf_office/features/ppt_convert/engine/pdf_to_ppt.dart';
import 'package:pdf_office/features/ppt_convert/ui/pdf_to_ppt_screen.dart';
import 'package:pptx_reader/pptx_reader.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pdf_tools/tool_test_harness.dart'
    show FakePicker, FakeToolsEngine, settle, settleUntilFound;
import 'pdf_to_ppt_test_fakes.dart';

Future<AppDatabase> _pump(
  WidgetTester tester,
  Widget child, {
  required FakeToolsEngine tools,
  required FakePptRender render,
  required Directory outDir,
  FakePicker? picker,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        outputDirectoryProvider.overrideWith((ref) async => outDir.path),
        pdfToolsEngineProvider.overrideWithValue(tools),
        pdfFilePickerProvider.overrideWithValue(picker ?? FakePicker()),
        // Ghi PPTX đồng bộ: Isolate.run không chạy trơn trong FakeAsync của widget test.
        pdfToPptConverterProvider.overrideWithValue(
          PdfToPptConverter(render: render, encode: syncPptxEncoder),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: child,
      ),
    ),
  );
  return db;
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('pdf_to_ppt_ui'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  testWidgets('có path: hiện file + ghi chú, chọn 200 dpi → tạo report.pptx → màn kết quả', (
    tester,
  ) async {
    final render = FakePptRender();
    final db = await _pump(
      tester,
      const PdfToPptScreen(path: '/x/report.pdf'),
      tools: FakeToolsEngine(pageCounts: {'/x/report.pdf': 2}),
      render: render,
      outDir: tmp,
    );
    await settleUntilFound(tester, find.byKey(const Key('pdfppt_convert')));

    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.textContaining('2 pages'), findsOneWidget);
    expect(find.text('2 slides will be created'), findsOneWidget);
    expect(find.textContaining('cannot be edited in PowerPoint'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pdfppt_dpi_200')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('pdfppt_convert')));
    await settleUntilFound(tester, find.text('All done!'));
    await settle(tester);

    expect(find.text('All done!'), findsOneWidget);
    expect(find.text('report.pptx'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(render.renders.map((r) => r.dpi), [200, 200]);
    expect(render.openedPasswords, [null]);

    final out = File(p.join(tmp.path, 'report.pptx'));
    expect(out.existsSync(), isTrue);
    final deck = readPptx(out.readAsBytesSync());
    expect(deck.slides, hasLength(2));
    expect(deck.slideWidthEmu, 595 * 12700);
    expect(deck.slideHeightEmu, 842 * 12700);

    // Đã ghi vào bảng documents với đuôi pptx (hiện ngay ở trang chủ).
    final docs = await tester.runAsync(
      () => db.select(db.documents).get(),
    );
    expect(docs!.single.ext, 'pptx');
  });

  testWidgets('không có path: mở bộ chọn, mặc định 150 dpi', (tester) async {
    final render = FakePptRender(sizes: const [PdfPageSize(720, 405)]);
    final picker = FakePicker(pdfs: ['/x/deck.pdf']);
    await _pump(
      tester,
      const PdfToPptScreen(),
      tools: FakeToolsEngine(pageCounts: {'/x/deck.pdf': 1}),
      render: render,
      picker: picker,
      outDir: tmp,
    );
    await settleUntilFound(tester, find.byKey(const Key('pdfppt_convert')));
    expect(picker.pdfCalls, 1);
    expect(find.text('deck.pdf'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pdfppt_convert')));
    await settleUntilFound(tester, find.text('All done!'));
    expect(render.renders.single.dpi, 150);
    expect(File(p.join(tmp.path, 'deck.pptx')).existsSync(), isTrue);
  });

  testWidgets('huỷ bộ chọn → màn chọn file', (tester) async {
    await _pump(
      tester,
      const PdfToPptScreen(),
      tools: FakeToolsEngine(),
      render: FakePptRender(),
      picker: FakePicker(),
      outDir: tmp,
    );
    await settle(tester);
    expect(find.text('Choose PDF file'), findsOneWidget);
    expect(find.byKey(const Key('pdfppt_convert')), findsNothing);
  });
}
