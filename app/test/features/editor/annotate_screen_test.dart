import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/utils/output_directory.dart';
import 'package:pdf_office/features/editor/annotate_screen.dart';
import 'package:pdf_office/features/editor/annotation_toolbar.dart';
import 'package:pdf_office/features/editor/editor_viewer.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'editor_test_helpers.dart';

void main() {
  late Directory dir;
  late EditorViewerArgs viewerArgs;
  late bool saverFlatten;
  List<int> savedBytes = [37, 80, 68, 70];

  setUp(() {
    dir = Directory.systemTemp.createTempSync('annotate_test_');
    savedBytes = [37, 80, 68, 70];
    saverFlatten = false;
  });
  tearDown(() => dir.deleteSync(recursive: true));

  List<Override> overrides() => [
    outputDirectoryProvider.overrideWith((ref) async => dir.path),
    editorViewerBuilderProvider.overrideWithValue((context, args) {
      viewerArgs = args;
      return const SizedBox.expand(key: Key('fakeViewer'));
    }),
    editorDocumentSaverProvider.overrideWithValue(
      (controller, {bool flatten = false}) async {
        saverFlatten = flatten;
        return savedBytes;
      },
    ),
  ];

  Future<void> open(WidgetTester tester) => pumpEditorScreen(
    tester,
    screen: const AnnotateScreen(path: '/x/Bao cao.pdf'),
    overrides: overrides(),
  );

  testWidgets('hien ten file, goi y va du 5 cong cu', (tester) async {
    await open(tester);
    expect(find.text('Bao cao.pdf'), findsOneWidget);
    expect(find.byKey(const Key('fakeViewer')), findsOneWidget);
    expect(
      find.text('Pick a tool, then select text on the page.'),
      findsOneWidget,
    );
    for (final t in kAnnotationTools) {
      expect(find.byKey(Key('tool_${t.name}')), findsOneWidget);
    }
    expect(find.text('Highlight'), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);
  });

  testWidgets('chon cong cu dat annotationMode, bam lai thi tat', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('tool_underline')));
    await tester.pump();
    expect(viewerArgs.controller.annotationMode, PdfAnnotationMode.underline);

    await tester.tap(find.byKey(const Key('tool_underline')));
    await tester.pump();
    expect(viewerArgs.controller.annotationMode, PdfAnnotationMode.none);
  });

  testWidgets('cong cu ghi chu doi goi y', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('tool_stickyNote')));
    await tester.pump();
    expect(find.text('Tap on the page to add a note.'), findsOneWidget);
  });

  testWidgets('chon mau ap dung cho moi loai chu thich', (tester) async {
    await open(tester);
    await tester.tap(find.bySemanticsLabel('Color').first);
    await tester.pump();
    final s = viewerArgs.controller.annotationSettings;
    expect(s.highlight.color, kAnnotationColors.first);
    expect(s.underline.color, kAnnotationColors.first);
    expect(s.squiggly.color, kAnnotationColors.first);
    expect(s.stickyNote.color, kAnnotationColors.first);
  });

  testWidgets('luu khi chua thay doi: bao khong co gi de luu', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('save')));
    await tester.pump();
    expect(
      find.text('There are no changes to save yet.'),
      findsAtLeastNWidgets(1),
    );
    expect(dir.listSync(), isEmpty);
  });

  testWidgets('co thay doi -> luu ra file moi, hien hop thoai da luu', (
    tester,
  ) async {
    await open(tester);
    viewerArgs.onChanged!();
    await tester.pump();

    await tester.tap(find.byKey(const Key('save')));
    await settle(tester, until: () => find.text('Saved').evaluate().isNotEmpty);

    final out = File('${dir.path}${Platform.pathSeparator}Bao cao_annotated.pdf');
    expect(out.existsSync(), isTrue);
    expect(out.readAsBytesSync(), savedBytes);
    expect(saverFlatten, isFalse);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.textContaining('Bao cao_annotated.pdf'), findsOneWidget);

    // Sau khi lưu, thoát không còn bị hỏi.
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(AnnotateScreen), findsNothing);
  });

  testWidgets('bytes rong -> bao loi, khong tao file', (tester) async {
    savedBytes = [];
    await open(tester);
    viewerArgs.onChanged!();
    await tester.pump();
    await tester.tap(find.byKey(const Key('save')));
    await settle(
      tester,
      until: () => find.byType(SnackBar).evaluate().isNotEmpty,
    );
    expect(dir.listSync(), isEmpty);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('thoat khi con thay doi: hoi xac nhan', (tester) async {
    await open(tester);
    viewerArgs.onChanged!();
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.byType(AnnotateScreen), findsOneWidget);

    // Huỷ → ở lại.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AnnotateScreen), findsOneWidget);

    // Bỏ → thoát.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(AnnotateScreen), findsNothing);
  });

  testWidgets('thoat khi chua doi gi: khong hoi', (tester) async {
    await open(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.byType(AnnotateScreen), findsNothing);
  });

  testWidgets('chon chu thich thi hien nut xoa, bo chon thi an', (
    tester,
  ) async {
    await open(tester);
    expect(find.byKey(const Key('deleteAnnotation')), findsNothing);
    final a = HighlightAnnotation(
      textBoundsCollection: [
        PdfTextLine(const Rect.fromLTWH(0, 0, 10, 10), 'x', 1),
      ],
    );
    viewerArgs.onAnnotationSelected!(a);
    await tester.pump();
    expect(find.byKey(const Key('deleteAnnotation')), findsOneWidget);

    viewerArgs.onAnnotationSelected!(null);
    await tester.pump();
    expect(find.byKey(const Key('deleteAnnotation')), findsNothing);
  });

  testWidgets('viewer bao loi mo file -> man loi, nut luu bi khoa', (
    tester,
  ) async {
    await open(tester);
    viewerArgs.onLoadFailed!();
    await tester.pump();
    expect(find.text('Cannot open this PDF.'), findsOneWidget);
    final save = tester.widget<IconButton>(find.byKey(const Key('save')));
    expect(save.onPressed, isNull);
  });

  testWidgets('chuoi tieng Viet', (tester) async {
    await pumpEditorScreen(
      tester,
      screen: const AnnotateScreen(path: '/x/a.pdf'),
      overrides: overrides(),
      locale: const Locale('vi'),
    );
    expect(find.text('Tô sáng'), findsOneWidget);
    expect(find.text('Gạch chân'), findsOneWidget);
  });
}
