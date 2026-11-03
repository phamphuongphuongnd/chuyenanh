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
import 'package:pdf_office/features/pdf_tools/engine/compress_pdf.dart';
import 'package:pdf_office/features/pdf_tools/pdf_tools_providers.dart';
import 'package:pdf_office/features/pdf_tools/ui/compress_screen.dart';
import 'package:pdf_office/features/pdf_tools/ui/pdf_file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tool_test_harness.dart'
    show FakePicker, FakeToolsEngine, settle, settleUntilFound;

/// Engine nén giả: ghi file kết quả [outputSize] byte, ghi lại lời gọi.
class _FakeCompress implements CompressEngine {
  _FakeCompress({required this.outputSize, this.optimal = false, this.lost = 0, this.fellBack = false});

  int outputSize;

  /// Giả lập "không nén thêm được": không ghi file, `alreadyOptimal`.
  final bool optimal;
  final int lost;
  final bool fellBack;
  final List<({String input, String output, CompressLevel level, String? password})>
  calls = [];

  @override
  Future<CompressResult> compress(
    String inputPath,
    String outputPath,
    CompressLevel level, {
    String? password,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    calls.add((
      input: inputPath,
      output: outputPath,
      level: level,
      password: password,
    ));
    onProgress?.call(0.5);
    if (optimal) {
      final orig = File(inputPath).lengthSync();
      return CompressResult(
        outputPath: outputPath,
        originalBytes: orig,
        outputBytes: orig,
        alreadyOptimal: true,
      );
    }
    File(outputPath).writeAsBytesSync(List.filled(outputSize, 1));
    onProgress?.call(1);
    return CompressResult(
      outputPath: outputPath,
      originalBytes: File(inputPath).lengthSync(),
      outputBytes: outputSize,
      lostAnnotations: lost,
      fellBackToLight: fellBack,
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required FakeToolsEngine engine,
  required _FakeCompress compress,
  required Directory outDir,
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
        pdfToolsEngineProvider.overrideWithValue(engine),
        pdfFilePickerProvider.overrideWithValue(FakePicker()),
        compressEngineProvider.overrideWithValue(compress),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: child,
      ),
    ),
  );
}

const _rasterWarning =
    'Pages become images, but text stays selectable and searchable. Links, highlights and notes are kept; form fields and drawings may be lost. Scanned pages without text stay plain images.';
const _passwordNote =
    'The original file is password protected. The compressed file will not have a password.';

void main() {
  late Directory tmp;
  late Directory out;
  late File src;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('compress_widget');
    out = Directory(p.join(tmp.path, 'out'))..createSync();
    src = File(p.join(tmp.path, 'doc.pdf'))
      ..writeAsBytesSync(List.filled(1000, 7));
  });
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  testWidgets('chọn mức Mạnh → cảnh báo; Nén → file _compressed + dòng giảm %', (
    tester,
  ) async {
    final compress = _FakeCompress(outputSize: 400);
    await _pump(
      tester,
      CompressScreen(path: src.path),
      engine: FakeToolsEngine(pageCounts: {src.path: 3}),
      compress: compress,
      outDir: out,
    );
    await settle(tester);

    // Thẻ file hiện số trang + dung lượng gốc.
    expect(find.text('3 pages • 1000 B'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Strong'), findsOneWidget);
    expect(find.text(_passwordNote), findsNothing);

    // Mức Nhẹ: không cảnh báo.
    await tester.tap(find.text('Light'));
    await tester.pump();
    expect(find.text(_rasterWarning), findsNothing);
    expect(find.textContaining('only optimizes the file structure'), findsOneWidget);

    await tester.tap(find.text('Strong'));
    await tester.pump();
    expect(find.text(_rasterWarning), findsOneWidget);
    expect(find.textContaining('100 dpi'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Compress'));
    await settleUntilFound(tester, find.text('All done!'));

    expect(compress.calls, hasLength(1));
    final call = compress.calls.single;
    expect(call.level, CompressLevel.strong);
    expect(call.password, isNull);
    expect(call.output.replaceAll('\\', '/'), endsWith('/out/doc_compressed.pdf'));
    expect(File(call.output).existsSync(), isTrue);
    expect(src.lengthSync(), 1000); // file gốc không đổi
    expect(find.text('All done!'), findsOneWidget);
    expect(find.text('From 1000 B → 400 B (60% smaller)'), findsOneWidget);
  });

  testWidgets('không nén thêm được: báo "đã tối ưu", không có file mới, nén lại được', (tester) async {
    final compress = _FakeCompress(outputSize: 0, optimal: true);
    await _pump(
      tester,
      CompressScreen(path: src.path),
      engine: FakeToolsEngine(pageCounts: {src.path: 1}),
      compress: compress,
      outDir: out,
    );
    await settle(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Compress'));
    await settleUntilFound(tester, find.textContaining('This file is already optimized'));
    expect(find.textContaining('current size 1000 B'), findsOneWidget);
    expect(find.text('All done!'), findsNothing);
    expect(File(compress.calls.single.output).existsSync(), isFalse);
    // Vẫn ở màn chọn mức để thử mức khác.
    expect(find.widgetWithText(FilledButton, 'Compress'), findsOneWidget);
    expect(src.lengthSync(), 1000);
  });

  testWidgets('kết quả: báo dùng mức Nhẹ thay thế và số chú thích không giữ được', (tester) async {
    final compress = _FakeCompress(outputSize: 800, lost: 3, fellBack: true);
    await _pump(
      tester,
      CompressScreen(path: src.path),
      engine: FakeToolsEngine(pageCounts: {src.path: 1}),
      compress: compress,
      outDir: out,
    );
    await settle(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Compress'));
    await settleUntilFound(tester, find.text('All done!'));
    expect(find.text('From 1000 B → 800 B (20% smaller)'), findsOneWidget);
    expect(find.textContaining('the Light level was used'), findsOneWidget);
    expect(find.textContaining('3 annotations'), findsOneWidget);
  });

  testWidgets('file có mật khẩu: hỏi mật khẩu, ghi chú bỏ mật khẩu, truyền mật khẩu cho engine', (
    tester,
  ) async {
    final compress = _FakeCompress(outputSize: 100);
    await _pump(
      tester,
      CompressScreen(path: src.path),
      engine: FakeToolsEngine(
        pageCounts: {src.path: 2},
        passwords: {src.path: 'secret'},
      ),
      compress: compress,
      outDir: out,
    );
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'secret');
    await tester.tap(find.text('OK'));
    await settle(tester);
    await tester.pumpAndSettle();

    expect(find.text(_passwordNote), findsOneWidget);
    // Mặc định mức Vừa → có cảnh báo (chữ vẫn chọn được; mất liên kết/chú thích).
    expect(find.text(_rasterWarning), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Compress'));
    await settleUntilFound(tester, find.text('All done!'));
    expect(compress.calls.single.password, 'secret');
    expect(compress.calls.single.level, CompressLevel.medium);
    expect(find.text('From 1000 B → 100 B (90% smaller)'), findsOneWidget);
  });
}
