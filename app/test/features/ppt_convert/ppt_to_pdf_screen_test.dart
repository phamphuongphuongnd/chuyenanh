import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/core/utils/cancel_token.dart';
import 'package:pdf_office/core/utils/output_directory.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/features/pdf_tools/ui/tool_widgets.dart';
import 'package:pdf_office/features/ppt_convert/engine/ppt_to_pdf.dart';
import 'package:pdf_office/features/ppt_convert/engine/ppt_to_pdf_providers.dart';
import 'package:pdf_office/features/ppt_convert/ui/ppt_to_pdf_screen.dart';
import 'package:pptx_reader/pptx_reader.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pdf_tools/tool_test_harness.dart' show settle, settleUntilFound;

PptxSlide _slide(int i, {bool hidden = false}) => PptxSlide(
  index: i,
  background: null,
  shapes: const [],
  notesText: null,
  hidden: hidden,
);

PptxDeck _deck() => PptxDeck(
  slideWidthEmu: 9144000,
  slideHeightEmu: 5143500,
  slides: [_slide(0), _slide(1, hidden: true), _slide(2)],
);

/// Engine giả: kiểm đuôi như bản thật, ghi lại lời gọi convert, ghi file rỗng ra đích.
class _FakeEngine implements PptToPdfEngine {
  final List<String> opened = [];
  final List<({String out, PptToPdfOptions options})> converts = [];

  @override
  Future<PptxDeck> openDeck(String path) async {
    ensurePptxPath(path);
    opened.add(path);
    return _deck();
  }

  @override
  Future<String> convert(
    PptxDeck deck,
    String outputPath, {
    required SlideRasterizer rasterizer,
    PptToPdfOptions options = const PptToPdfOptions(),
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    converts.add((out: outputPath, options: options));
    File(outputPath).writeAsBytesSync(const [37, 80, 68, 70]);
    onProgress?.call(1);
    return outputPath;
  }
}

class _FakeRasterizer implements SlideRasterizer {
  @override
  Future<Uint8List> renderSlide(
    PptxDeck deck,
    PptxSlide slide, {
    required int dpi,
  }) async => Uint8List(0);
}

class _FakePicker implements PptxFilePicker {
  _FakePicker(this.result);
  String? result;
  int calls = 0;

  @override
  Future<String?> pickPresentation() async {
    calls++;
    return result;
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required _FakeEngine engine,
  required _FakePicker picker,
  required Directory outDir,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.binding.setSurfaceSize(const Size(400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        outputDirectoryProvider.overrideWith((ref) async => outDir.path),
        pptToPdfEngineProvider.overrideWithValue(engine),
        pptxFilePickerProvider.overrideWithValue(picker),
        slideRasterizerFactoryProvider.overrideWithValue(
          (_) => _FakeRasterizer(),
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
}

void main() {
  late Directory outDir;
  setUp(() => outDir = Directory.systemTemp.createTempSync('pptpdf_ui'));
  tearDown(() {
    if (outDir.existsSync()) outDir.deleteSync(recursive: true);
  });

  testWidgets('có path: tuỳ chọn, bỏ slide ẩn, chuyển → màn kết quả', (
    tester,
  ) async {
    final engine = _FakeEngine();
    final picker = _FakePicker(null);
    await _pump(
      tester,
      const PptToPdfScreen(path: '/docs/Bao cao.pptx'),
      engine: engine,
      picker: picker,
      outDir: outDir,
    );
    await settleUntilFound(tester, find.text('Bao cao.pptx'));

    expect(picker.calls, 0);
    expect(engine.opened, ['/docs/Bao cao.pptx']);
    expect(find.text('PowerPoint to PDF'), findsOneWidget);
    expect(find.textContaining('3 slides'), findsOneWidget);
    expect(find.byType(NoteBanner), findsOneWidget);
    expect(find.textContaining('cannot be selected'), findsOneWidget);
    // Mặc định bỏ slide ẩn → 2 trang.
    expect(find.text('2 PDF pages will be created'), findsOneWidget);
    expect(find.text('This presentation has 1 hidden slide'), findsOneWidget);

    // Tắt "Bỏ slide ẩn" → 3 trang; chọn chất lượng cao.
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.text('3 PDF pages will be created'), findsOneWidget);
    await tester.tap(find.text('High (200 dpi)'));
    await tester.pump();

    await tester.tap(find.text('Convert to PDF'));
    await settleUntilFound(tester, find.byType(ToolResultView));
    await settle(tester, rounds: 3);

    expect(engine.converts, hasLength(1));
    final call = engine.converts.single;
    expect(call.options.quality, PptPdfQuality.high);
    expect(call.options.includeHidden, isTrue);
    expect(call.out, endsWith('Bao cao.pdf'));
    expect(call.out, startsWith(outDir.path));
    expect(find.byType(ToolResultView), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('tên ra không đè file cũ', (tester) async {
    File('${outDir.path}/Bao cao.pdf').writeAsBytesSync(const [1]);
    final engine = _FakeEngine();
    await _pump(
      tester,
      const PptToPdfScreen(path: '/docs/Bao cao.pptx'),
      engine: engine,
      picker: _FakePicker(null),
      outDir: outDir,
    );
    await settleUntilFound(tester, find.text('Convert to PDF'));
    await tester.tap(find.text('Convert to PDF'));
    await settleUntilFound(tester, find.byType(ToolResultView));
    expect(engine.converts.single.out, endsWith('Bao cao (1).pdf'));
  });

  testWidgets('không có path: mở bộ chọn; .ppt cũ → báo không hỗ trợ', (
    tester,
  ) async {
    final engine = _FakeEngine();
    final picker = _FakePicker('/docs/old.ppt');
    await _pump(
      tester,
      const PptToPdfScreen(),
      engine: engine,
      picker: picker,
      outDir: outDir,
    );
    await settleUntilFound(tester, find.byType(SnackBar));

    expect(picker.calls, 1);
    expect(engine.opened, isEmpty);
    expect(
      find.textContaining('old .ppt format is not supported'),
      findsOneWidget,
    );
    // Vẫn ở màn chọn file.
    expect(find.text('Choose PowerPoint file'), findsOneWidget);

    // Chọn lại file .pptx hợp lệ.
    picker.result = '/docs/new.pptx';
    await tester.tap(find.text('Choose PowerPoint file'));
    await settleUntilFound(tester, find.text('new.pptx'));
    expect(picker.calls, 2);
    expect(engine.opened, ['/docs/new.pptx']);
  });

  testWidgets('huỷ bộ chọn → màn trống có nút chọn file', (tester) async {
    final picker = _FakePicker(null);
    await _pump(
      tester,
      const PptToPdfScreen(),
      engine: _FakeEngine(),
      picker: picker,
      outDir: outDir,
    );
    await settle(tester, rounds: 3);
    expect(picker.calls, 1);
    expect(
      find.text('Choose a PowerPoint presentation (.pptx) to convert to PDF'),
      findsOneWidget,
    );
    expect(find.text('Choose PowerPoint file'), findsOneWidget);
  });

  test('UnsupportedFormat của .ppt mang đuôi "ppt"', () {
    expect(
      () => ensurePptxPath('a.ppt'),
      throwsA(isA<UnsupportedFormat>().having((e) => e.extension, 'e', 'ppt')),
    );
  });
}
