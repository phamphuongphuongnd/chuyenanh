import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pdf_office/core/widgets/widgets.dart';
import 'package:pdf_office/engines/pdf/pdf_tools_engine.dart';
import 'package:pdf_office/features/pdf_tools/ui/merge_screen.dart';
import 'package:pdf_office/features/pdf_tools/ui/split_screen.dart';

import 'tool_test_harness.dart';

void main() {
  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tools_widget');
  });
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('MergeScreen', () {
    testWidgets('chọn 2 file → đặt tên → gộp → màn kết quả', (tester) async {
      final engine = FakeToolsEngine(pageCounts: {'/x/a.pdf': 3, '/x/b.pdf': 5});
      final picker = FakePicker(pdfs: ['/x/a.pdf', '/x/b.pdf']);
      await pumpTool(
        tester,
        const MergeScreen(),
        engine: engine,
        picker: picker,
        outDir: tmp,
      );
      await settle(tester);

      expect(picker.lastMultiple, isTrue);
      expect(find.text('a.pdf'), findsOneWidget);
      expect(find.text('b.pdf'), findsOneWidget);
      expect(find.textContaining('3 pages'), findsOneWidget);
      expect(find.textContaining('5 pages'), findsOneWidget);
      // cảnh báo mất annotation/form/link
      expect(find.textContaining('Annotations'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Merge'));
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsOneWidget);
      // tên gợi ý "A & B"
      expect(find.widgetWithText(TextField, 'a & b'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'my merged');
      await tester.tap(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Merge'),
        ),
      );
      await settle(tester);

      expect(engine.merges, hasLength(1));
      expect(engine.merges.single['inputs'], ['/x/a.pdf', '/x/b.pdf']);
      expect(
        (engine.merges.single['out'] as String).replaceAll('\\', '/'),
        endsWith('/my merged.pdf'),
      );
      expect(find.text('All done!'), findsOneWidget);
    });

    testWidgets('mới 1 file: nút Merge bị khoá và có nhắc chọn thêm', (tester) async {
      final engine = FakeToolsEngine(pageCounts: {'/x/a.pdf': 3});
      await pumpTool(
        tester,
        const MergeScreen(path: '/x/a.pdf'),
        engine: engine,
        picker: FakePicker(),
        outDir: tmp,
      );
      await settle(tester);
      expect(find.text('a.pdf'), findsOneWidget);
      expect(find.text('Select at least 2 PDF files.'), findsOneWidget);
      final merge = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Merge'),
      );
      expect(merge.onPressed, isNull);
    });

    testWidgets('file có mật khẩu: hỏi mật khẩu, sai thì hỏi lại, đúng thì truyền vào gộp', (tester) async {
      final engine = FakeToolsEngine(
        pageCounts: {'/x/a.pdf': 1, '/x/b.pdf': 2},
        passwords: {'/x/b.pdf': 'pw1'},
      );
      await pumpTool(
        tester,
        const MergeScreen(),
        engine: engine,
        picker: FakePicker(pdfs: ['/x/a.pdf', '/x/b.pdf']),
        outDir: tmp,
      );
      await settle(tester);
      expect(find.text('Enter password'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'bad');
      await tester.tap(find.text('OK'));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.text('Incorrect password.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'pw1');
      await tester.tap(find.text('OK'));
      await settle(tester);

      expect(find.text('b.pdf'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Merge'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Merge'),
        ),
      );
      await settle(tester);
      expect(engine.merges.single['passwords'], {'/x/b.pdf': 'pw1'});
    });

    testWidgets('file hỏng bị bỏ qua kèm thông báo, file tốt vẫn vào danh sách', (tester) async {
      final engine = FakeToolsEngine(pageCounts: {'/x/a.pdf': 1});
      await pumpTool(
        tester,
        const MergeScreen(),
        engine: engine,
        picker: FakePicker(pdfs: ['/x/bad.pdf', '/x/a.pdf']),
        outDir: tmp,
      );
      await settle(tester);
      expect(find.text('a.pdf'), findsOneWidget);
      expect(find.text('bad.pdf'), findsNothing);
    });

    testWidgets('bỏ một file và đổi thứ tự bằng kéo thả', (tester) async {
      final engine = FakeToolsEngine(
        pageCounts: {'/x/a.pdf': 1, '/x/b.pdf': 1, '/x/c.pdf': 1},
      );
      await pumpTool(
        tester,
        const MergeScreen(),
        engine: engine,
        picker: FakePicker(pdfs: ['/x/a.pdf', '/x/b.pdf', '/x/c.pdf']),
        outDir: tmp,
      );
      await settle(tester);

      // kéo a.pdf xuống dưới b.pdf
      await tester.drag(find.byIcon(Symbols.drag_indicator_rounded).first, const Offset(0, 130));
      await tester.pumpAndSettle();
      final order = tester
          .widgetList<Text>(find.textContaining('.pdf'))
          .map((t) => t.data)
          .toList();
      expect(order.first, 'b.pdf');

      await tester.tap(find.byTooltip('Remove').first);
      await tester.pump();
      expect(find.text('b.pdf'), findsNothing);
    });
  });

  group('SplitScreen', () {
    testWidgets('khoảng trang: kiểm tra hợp lệ, đếm file, tách', (tester) async {
      final engine = FakeToolsEngine(pageCounts: {'/x/doc.pdf': 10});
      await pumpTool(
        tester,
        const SplitScreen(path: '/x/doc.pdf'),
        engine: engine,
        picker: FakePicker(),
        outDir: tmp,
      );
      await settle(tester);
      expect(find.text('10 pages'), findsOneWidget);

      // chưa nhập gì → nút khoá
      FilledButton split() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Split'),
      );
      expect(split().onPressed, isNull);

      await tester.enterText(find.byType(TextField), '1-99');
      await tester.pump();
      expect(
        find.text('Invalid range. Use pages from 1 to 10, e.g. 1-3, 5.'),
        findsOneWidget,
      );
      expect(split().onPressed, isNull);

      await tester.enterText(find.byType(TextField), '1-3, 5');
      await tester.pump();
      expect(find.text('2 files will be created'), findsOneWidget);
      expect(split().onPressed, isNotNull);

      await tester.tap(find.widgetWithText(FilledButton, 'Split'));
      await settle(tester);
      expect(engine.splits, hasLength(1));
      final mode = engine.splits.single['mode']! as SplitByRanges;
      expect(mode.ranges, const [PageRange(1, 3), PageRange(5, 5)]);
      expect(engine.splits.single['base'], 'doc');
      expect(engine.splits.single['dir'], tmp.path);
      expect(find.text('2 files created'), findsOneWidget);
      expect(find.text('doc (1).pdf'), findsOneWidget);
    });

    testWidgets('mỗi trang một file và mỗi N trang', (tester) async {
      final engine = FakeToolsEngine(pageCounts: {'/x/doc.pdf': 10});
      await pumpTool(
        tester,
        const SplitScreen(path: '/x/doc.pdf'),
        engine: engine,
        picker: FakePicker(),
        outDir: tmp,
      );
      await settle(tester);
      await tester.tap(find.text('Every page'));
      await tester.pump();
      expect(find.text('10 files will be created'), findsOneWidget);

      await tester.tap(find.text('Every N pages'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '4');
      await tester.pump();
      expect(find.text('3 files will be created'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '0');
      await tester.pump();
      expect(find.text('Enter a whole number, 1 or more.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '4');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Split'));
      await settle(tester);
      expect(engine.splits.single['mode'], isA<SplitEveryN>());
      expect((engine.splits.single['mode']! as SplitEveryN).pagesPerFile, 4);
    });

    testWidgets('không có path: tự mở hộp chọn file; huỷ thì hiện nút chọn', (tester) async {
      final picker = FakePicker();
      await pumpTool(
        tester,
        const SplitScreen(),
        engine: FakeToolsEngine(),
        picker: picker,
        outDir: tmp,
      );
      await settle(tester);
      expect(picker.pdfCalls, 1);
      expect(find.text('Choose a PDF file to get started.'), findsOneWidget);
      picker.pdfs = ['/x/doc.pdf'];
      // engine không biết file → CorruptFile → thông báo, vẫn ở màn chọn
      await tester.tap(find.text('Choose PDF file'));
      await settle(tester);
      expect(picker.pdfCalls, 2);
      expect(find.text('The file is damaged or cannot be read.'), findsOneWidget);
    });
  });
}
