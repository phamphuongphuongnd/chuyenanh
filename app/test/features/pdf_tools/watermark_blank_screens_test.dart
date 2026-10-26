import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_office/engines/pdf/pdf_tools_engine.dart';
import 'package:pdf_office/features/pdf_tools/engine/watermark_layout.dart';
import 'package:pdf_office/features/pdf_tools/ui/create_blank_screen.dart';
import 'package:pdf_office/features/pdf_tools/ui/watermark_screen.dart';

import 'tool_test_harness.dart';

void main() {
  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tools_widget3');
  });
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('WatermarkScreen', () {
    testWidgets('chữ mặc định, đổi vị trí & độ mờ → engine nhận PlacedWatermarkSpec', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final engine = FakeToolsEngine(pageCounts: {'/x/doc.pdf': 2});
      await pumpTool(
        tester,
        const WatermarkScreen(path: '/x/doc.pdf'),
        engine: engine,
        picker: FakePicker(),
        outDir: tmp,
      );
      await settle(tester);

      await tester.enterText(find.byType(TextField), 'DRAFT');
      await tester.tap(find.byKey(const ValueKey('pos_-1_-1')));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'APPLY'));
      await settle(tester);

      expect(engine.watermarks, hasLength(1));
      final spec = engine.watermarks.single['spec']! as PlacedWatermarkSpec;
      expect(spec.text, 'DRAFT');
      expect(spec.alignX, -1);
      expect(spec.alignY, -1);
      expect(spec.angle, -45);
      expect(spec.opacity, closeTo(0.3, 1e-9));
      expect(
        (engine.watermarks.single['out'] as String).replaceAll('\\', '/'),
        endsWith('/doc_watermark.pdf'),
      );
      expect(find.text('All done!'), findsOneWidget);
    });

    testWidgets('chữ trống bị chặn; chữ ngoài Latin có cảnh báo', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final engine = FakeToolsEngine(pageCounts: {'/x/doc.pdf': 2});
      await pumpTool(
        tester,
        const WatermarkScreen(path: '/x/doc.pdf'),
        engine: engine,
        picker: FakePicker(),
        outDir: tmp,
      );
      await settle(tester);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.widgetWithText(FilledButton, 'APPLY'));
      await tester.pump();
      expect(find.text('Enter the watermark text.'), findsOneWidget);
      expect(engine.watermarks, isEmpty);

      await tester.enterText(find.byType(TextField), 'BẢO MẬT');
      await tester.pump();
      expect(find.textContaining('embedded font'), findsOneWidget);
    });

    testWidgets('chế độ ảnh: cần chọn ảnh PNG/JPG hợp lệ', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final engine = FakeToolsEngine(pageCounts: {'/x/doc.pdf': 2});
      final picker = FakePicker(image: Uint8List.fromList([1, 2, 3, 4]));
      await pumpTool(
        tester,
        const WatermarkScreen(path: '/x/doc.pdf'),
        engine: engine,
        picker: picker,
        outDir: tmp,
      );
      await settle(tester);
      await tester.tap(find.text('Image'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'APPLY'));
      await tester.pump();
      expect(find.text('Choose a PNG or JPG image.'), findsOneWidget);

      // ảnh không phải PNG/JPG bị từ chối
      await tester.tap(find.text('Choose image'));
      await tester.pump();
      expect(engine.watermarks, isEmpty);

      picker.image = Uint8List.fromList(
        img.encodePng(img.Image(width: 4, height: 4)..clear(img.ColorRgb8(1, 2, 3))),
      );
      await tester.tap(find.text('Choose image'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'APPLY'));
      await settle(tester);
      final spec = engine.watermarks.single['spec']! as PlacedWatermarkSpec;
      expect(spec.imageBytes, isNotNull);
      expect(spec.text, isNull);
      expect(spec.angle, 0);
    });
  });

  group('CreateBlankScreen', () {
    testWidgets('mặc định → createBlank với BlankDocSpec mặc định, tên theo tiêu đề', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final engine = FakeToolsEngine();
      await pumpTool(
        tester,
        const CreateBlankScreen(),
        engine: engine,
        picker: FakePicker(),
        outDir: tmp,
      );
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, '').first, 'Notes 1');
      await tester.tap(find.text('Grid'));
      await tester.tap(find.text('Landscape'));
      await tester.tap(find.text('Letter'));
      await tester.tap(find.text('Work'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add)); // 1 → 2 trang
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'CREATE'));
      await settle(tester);

      expect(engine.blanks, hasLength(1));
      final spec = engine.blanks.single['spec']! as BlankDocSpec;
      expect(spec.template, BlankTemplate.grid);
      expect(spec.title, 'Notes 1');
      expect(spec.pageSize, PageSizeOption.letter);
      expect(spec.landscape, isTrue);
      expect(spec.category, 'Work');
      expect(spec.pageCount, 2);
      expect(
        (engine.blanks.single['out'] as String).replaceAll('\\', '/'),
        endsWith('/Notes 1.pdf'),
      );
      expect(find.text('All done!'), findsOneWidget);
    });

    testWidgets('số trang ngoài 1..1000 bị chặn', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final engine = FakeToolsEngine();
      await pumpTool(
        tester,
        const CreateBlankScreen(),
        engine: engine,
        picker: FakePicker(),
        outDir: tmp,
      );
      await tester.pump();
      final pages = find.byType(TextField).last;
      await tester.enterText(pages, '1001');
      await tester.pump();
      expect(find.text('Enter a number from 1 to 1000.'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, 'CREATE'));
      await tester.pump();
      expect(engine.blanks, isEmpty);

      await tester.enterText(pages, '1000');
      await tester.tap(find.widgetWithText(FilledButton, 'CREATE'));
      await settle(tester);
      expect((engine.blanks.single['spec']! as BlankDocSpec).pageCount, 1000);
      expect(
        (engine.blanks.single['out'] as String).replaceAll('\\', '/'),
        endsWith('/Blank document.pdf'),
      );
    });
  });
}
