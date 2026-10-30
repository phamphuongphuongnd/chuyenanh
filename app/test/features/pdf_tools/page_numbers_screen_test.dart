import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/core/utils/output_directory.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/engines/pdf/pdf_tools_engine.dart';
import 'package:pdf_office/features/pdf_tools/engine/page_numbers.dart';
import 'package:pdf_office/features/pdf_tools/page_numbers_providers.dart';
import 'package:pdf_office/features/pdf_tools/pdf_tools_providers.dart';
import 'package:pdf_office/features/pdf_tools/ui/page_numbers_screen.dart';
import 'package:pdf_office/features/pdf_tools/ui/pdf_file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tool_test_harness.dart' show FakePicker, FakeToolsEngine, settle;

/// Engine đánh số giả: ghi lại lời gọi, trả kết quả ngay.
class _FakePageNumbers implements PageNumbersEngine {
  final List<Map<String, Object?>> calls = [];

  @override
  Future<String> addPageNumbers(
    String inputPath,
    PageNumberSpec spec,
    String outputPath, {
    String? password,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    calls.add({
      'input': inputPath,
      'spec': spec,
      'out': outputPath,
      'password': password,
    });
    onProgress?.call(1);
    return outputPath;
  }
}

/// Như `pumpTool` của harness nhưng thêm override engine đánh số.
Future<void> _pump(
  WidgetTester tester, {
  required FakeToolsEngine tools,
  required _FakePageNumbers numbers,
  required Directory outDir,
  String path = '/x/doc.pdf',
}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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
        pdfFilePickerProvider.overrideWithValue(FakePicker()),
        pageNumbersEngineProvider.overrideWithValue(numbers),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: PageNumbersScreen(path: path),
      ),
    ),
  );
  await settle(tester);
}

Future<void> _apply(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Add page numbers'));
  await settle(tester);
}

void main() {
  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('page_numbers_widget');
  });
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  testWidgets('mặc định → spec dưới giữa, cỡ 11, lề 24, tên _numbered', (
    tester,
  ) async {
    final tools = FakeToolsEngine(pageCounts: {'/x/doc.pdf': 3});
    final numbers = _FakePageNumbers();
    await _pump(tester, tools: tools, numbers: numbers, outDir: tmp);

    // chip kiểu số hiện nhãn mẫu theo ngôn ngữ app
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('Page 1'), findsOneWidget);
    expect(find.text('- 1 -'), findsOneWidget);
    expect(find.text('3 pages will be numbered'), findsOneWidget);
    expect(find.byKey(const ValueKey('pagenum_preview_label')), findsOneWidget);

    await _apply(tester);

    expect(numbers.calls, hasLength(1));
    final call = numbers.calls.single;
    final spec = call['spec']! as PageNumberSpec;
    expect(call['input'], '/x/doc.pdf');
    expect(spec.style, PageNumberStyle.plain);
    expect(spec.vAlign, PageNumberVAlign.bottom);
    expect(spec.hAlign, PageNumberHAlign.center);
    expect(spec.fontSize, 11);
    expect(spec.margin, 24);
    expect(spec.startNumber, 1);
    expect(spec.ranges, isNull);
    expect(spec.skipFirstPage, isFalse);
    expect(spec.colorArgb, 0xFF000000);
    expect(spec.pageWordTemplate, 'Page {n}');
    expect(
      (call['out']! as String).replaceAll('\\', '/'),
      endsWith('/doc_numbered.pdf'),
    );
    expect(find.text('All done!'), findsOneWidget);
  });

  testWidgets('đổi kiểu, vị trí, số bắt đầu, khoảng trang, bỏ bìa', (
    tester,
  ) async {
    final tools = FakeToolsEngine(pageCounts: {'/x/doc.pdf': 4});
    final numbers = _FakePageNumbers();
    await _pump(tester, tools: tools, numbers: numbers, outDir: tmp);

    await tester.tap(find.byKey(const ValueKey('style_pageWord')));
    await tester.tap(find.byKey(const ValueKey('pos_top_right')));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('pagenum_start')), '5');
    await tester.pump();
    await tester.tap(find.text('Page range'));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('pagenum_range')), '1-3');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pagenum_skipFirst')));
    await tester.pump();

    // trang 2, 3 → số 5, 6
    expect(find.text('2 pages will be numbered'), findsOneWidget);
    expect(find.text('5 / 6'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('pagenum_preview_label')))
          .data,
      'Page 5',
    );

    await _apply(tester);
    final spec = numbers.calls.single['spec']! as PageNumberSpec;
    expect(spec.style, PageNumberStyle.pageWord);
    expect(spec.vAlign, PageNumberVAlign.top);
    expect(spec.hAlign, PageNumberHAlign.right);
    expect(spec.startNumber, 5);
    expect(spec.ranges, const [PageRange(1, 3)]);
    expect(spec.skipFirstPage, isTrue);
  });

  testWidgets('khoảng trang / số bắt đầu sai bị chặn', (tester) async {
    final tools = FakeToolsEngine(pageCounts: {'/x/doc.pdf': 3});
    final numbers = _FakePageNumbers();
    await _pump(tester, tools: tools, numbers: numbers, outDir: tmp);

    await tester.tap(find.text('Page range'));
    await tester.pump();
    // chưa nhập khoảng → nhấn nút báo lỗi
    await _apply(tester);
    expect(numbers.calls, isEmpty);

    await tester.enterText(find.byKey(const ValueKey('pagenum_range')), '2-9');
    await tester.pump();
    expect(
      find.text('Invalid range. Use pages from 1 to 3, e.g. 1-3, 5.'),
      findsWidgets,
    );
    await _apply(tester);
    expect(numbers.calls, isEmpty);

    await tester.enterText(find.byKey(const ValueKey('pagenum_range')), '2');
    await tester.enterText(find.byKey(const ValueKey('pagenum_start')), '0');
    await tester.pump();
    expect(find.text('Enter a whole number from 1 to 99999.'), findsWidgets);
    await _apply(tester);
    expect(numbers.calls, isEmpty);

    await tester.enterText(find.byKey(const ValueKey('pagenum_start')), '1');
    await tester.pump();
    await _apply(tester);
    expect(numbers.calls, hasLength(1));
  });

  testWidgets('PDF 1 trang + bỏ bìa → không còn trang để đánh số', (
    tester,
  ) async {
    final tools = FakeToolsEngine(pageCounts: {'/x/one.pdf': 1});
    final numbers = _FakePageNumbers();
    await _pump(
      tester,
      tools: tools,
      numbers: numbers,
      outDir: tmp,
      path: '/x/one.pdf',
    );
    await tester.tap(find.byKey(const ValueKey('pagenum_skipFirst')));
    await tester.pump();
    expect(find.text('There are no pages left to number.'), findsOneWidget);
    await _apply(tester);
    expect(numbers.calls, isEmpty);
  });

  testWidgets('file có mật khẩu: mật khẩu được chuyển cho engine', (
    tester,
  ) async {
    final tools = FakeToolsEngine(
      pageCounts: {'/x/doc.pdf': 2},
      passwords: {'/x/doc.pdf': 'pw'},
    );
    final numbers = _FakePageNumbers();
    await _pump(tester, tools: tools, numbers: numbers, outDir: tmp);
    // hộp thoại hỏi mật khẩu (chưa có màn tuỳ chọn phía sau)
    expect(find.text('Enter password'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'pw');
    await tester.tap(find.text('OK'));
    await settle(tester);
    expect(find.text('Add page numbers'), findsOneWidget);
    await _apply(tester);
    expect(numbers.calls.single['password'], 'pw');
  });
}
