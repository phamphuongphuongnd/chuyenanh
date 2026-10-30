import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_symbols_icons/symbols.dart';
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/core/utils/output_directory.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/engines/pdf/pdf_tools_engine.dart';
import 'package:pdf_office/features/pdf_tools/engine/insert_pages.dart';
import 'package:pdf_office/features/pdf_tools/insert_pages_providers.dart';
import 'package:pdf_office/features/pdf_tools/pdf_tools_providers.dart';
import 'package:pdf_office/features/pdf_tools/ui/insert_pages_screen.dart';
import 'package:pdf_office/features/pdf_tools/ui/pdf_file_picker.dart';
import 'package:pdf_office/features/reader/reader_providers.dart'
    show pdfRenderEngineProvider;
import 'package:shared_preferences/shared_preferences.dart';

import 'tool_test_harness.dart'
    show FakePicker, FakeRender, FakeToolsEngine, settle, settleUntilFound;

/// Engine chèn trang giả: ghi lại lời gọi, trả kết quả ngay.
class _FakeInsertEngine implements InsertPagesEngine {
  final List<Map<String, Object?>> calls = [];

  @override
  Future<String> insertPages(
    String inputPath,
    int insertAfter,
    InsertContent content,
    String outputPath, {
    String? password,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    calls.add({
      'input': inputPath,
      'after': insertAfter,
      'content': content,
      'out': outputPath,
      'password': password,
    });
    onProgress?.call(1);
    return outputPath;
  }
}

/// Như `pumpTool` của harness, thêm override engine chèn trang; màn hình cao để khỏi cuộn.
Future<void> _pump(
  WidgetTester tester, {
  required _FakeInsertEngine insert,
  required FakeToolsEngine tools,
  required FakePicker picker,
  required Directory outDir,
  FakeRender? render,
  String path = '/x/doc.pdf',
}) async {
  tester.view.physicalSize = const Size(900, 2200);
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
        pdfFilePickerProvider.overrideWithValue(picker),
        insertPagesEngineProvider.overrideWithValue(insert),
        if (render != null) pdfRenderEngineProvider.overrideWithValue(render),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: InsertPagesScreen(path: path),
      ),
    ),
  );
  await settle(tester);
}

Finder get _insertButton => find.widgetWithText(FilledButton, 'Insert pages');

bool _enabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_insertButton).onPressed != null;

Uint8List _png() => Uint8List.fromList(
  img.encodePng(img.Image(width: 8, height: 6)..clear(img.ColorRgb8(0, 0, 255))),
);

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('insert_screen'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  testWidgets('trang trắng sau trang chọn bằng thumbnail; ô số sai thì khoá nút', (tester) async {
    final insert = _FakeInsertEngine();
    final render = FakeRender(_png());
    await _pump(
      tester,
      insert: insert,
      tools: FakeToolsEngine(pageCounts: {'/x/doc.pdf': 3}),
      picker: FakePicker(),
      render: render,
      outDir: tmp,
    );

    // mặc định: 1 trang trắng ở cuối → 4 trang
    expect(find.text('The new file will have 4 pages'), findsOneWidget);
    expect(find.text('Annotations, form fields and links are not kept in the new file.'), findsOneWidget);
    expect(_enabled(tester), isTrue);

    await tester.tap(find.text('After page…'));
    await settle(tester);
    expect(render.opened, 1);
    expect(find.byKey(const ValueKey('insert-after-3')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('insert-after-2')));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '2');

    // ô số ngoài phạm vi → báo lỗi, nút khoá
    await tester.enterText(find.byType(TextField), '9');
    await tester.pump();
    expect(find.text('Enter a page from 1 to 3.'), findsOneWidget);
    expect(_enabled(tester), isFalse);

    await tester.enterText(find.byType(TextField), '1');
    await tester.pump();
    await tester.tap(find.byTooltip('One more'));
    await tester.pump();
    expect(find.text('The new file will have 5 pages'), findsOneWidget);

    await tester.tap(_insertButton);
    await settleUntilFound(tester, find.text('All done!'));

    expect(insert.calls, hasLength(1));
    final call = insert.calls.single;
    expect(call['input'], '/x/doc.pdf');
    expect(call['after'], 1);
    expect((call['content']! as InsertBlank).count, 2);
    expect((call['out']! as String).replaceAll('\\', '/'), endsWith('/doc_inserted.pdf'));
    expect(find.text('All done!'), findsOneWidget);
  });

  testWidgets('ảnh: thêm nhiều ảnh, bỏ ảnh, ảnh sai định dạng bị từ chối', (tester) async {
    final insert = _FakeInsertEngine();
    final picker = FakePicker(image: _png());
    await _pump(
      tester,
      insert: insert,
      tools: FakeToolsEngine(pageCounts: {'/x/doc.pdf': 2}),
      picker: picker,
      outDir: tmp,
    );

    await tester.tap(find.text('Images'));
    await tester.pump();
    expect(find.text('No images yet. Each image becomes one page.'), findsOneWidget);
    expect(_enabled(tester), isFalse);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Add image'));
      await settle(tester, rounds: 2);
    }
    expect(find.byKey(const ValueKey('insert-image-2')), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('insert-image-0')),
        matching: find.byIcon(Symbols.close_rounded),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('insert-image-2')), findsNothing);

    picker.image = Uint8List.fromList([1, 2, 3]);
    await tester.tap(find.text('Add image'));
    await settle(tester, rounds: 2);
    expect(find.text('Choose a PNG or JPG image.'), findsOneWidget);
    expect(find.byKey(const ValueKey('insert-image-2')), findsNothing);

    await tester.tap(find.text('Same as neighbouring page'));
    await tester.tap(find.text('At the beginning'));
    await tester.pump();
    expect(find.text('The new file will have 4 pages'), findsOneWidget);

    await tester.tap(_insertButton);
    await settleUntilFound(tester, find.text('All done!'));
    final call = insert.calls.single;
    expect(call['after'], 0);
    final content = call['content']! as InsertImages;
    expect(content.images, hasLength(2));
    expect(content.fit, InsertImageFit.neighbor);
  });

  testWidgets('trang từ PDF khác có mật khẩu: hỏi mật khẩu, chọn khoảng trang', (tester) async {
    final insert = _FakeInsertEngine();
    final tools = FakeToolsEngine(
      pageCounts: {'/x/doc.pdf': 3, '/x/other.pdf': 5},
      passwords: {'/x/other.pdf': 'pw'},
    );
    await _pump(
      tester,
      insert: insert,
      tools: tools,
      picker: FakePicker(pdfs: ['/x/other.pdf']),
      outDir: tmp,
    );

    await tester.tap(find.text('Pages from another PDF'));
    await tester.pump();
    expect(_enabled(tester), isFalse);

    await tester.tap(find.text('Choose PDF file'));
    await settle(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'pw');
    await tester.tap(find.text('OK'));
    await settle(tester);
    await tester.pumpAndSettle();

    expect(find.text('other.pdf'), findsOneWidget);
    // tất cả trang: 3 + 5
    expect(find.text('The new file will have 8 pages'), findsOneWidget);

    await tester.tap(find.text('Page range'));
    await tester.pump();
    expect(_enabled(tester), isFalse); // chưa gõ khoảng
    await tester.enterText(find.byType(TextField), '4-9');
    await tester.pump();
    expect(find.text('Invalid range. Use pages from 1 to 5, e.g. 1-3, 5.'), findsOneWidget);
    expect(_enabled(tester), isFalse);
    await tester.enterText(find.byType(TextField), '2-3, 5');
    await tester.pump();
    expect(find.text('The new file will have 6 pages'), findsOneWidget);

    await tester.tap(_insertButton);
    await settleUntilFound(tester, find.text('All done!'));
    final call = insert.calls.single;
    expect(call['after'], 3); // mặc định: cuối tài liệu
    final content = call['content']! as InsertPdfPages;
    expect(content.path, '/x/other.pdf');
    expect(content.password, 'pw');
    expect(content.ranges, const [PageRange(2, 3), PageRange(5, 5)]);
  });
}
