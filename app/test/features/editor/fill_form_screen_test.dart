import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/utils/output_directory.dart';
import 'package:pdf_office/features/editor/editor_viewer.dart';
import 'package:pdf_office/features/editor/fill_form_screen.dart';

import 'editor_test_helpers.dart';

void main() {
  late Directory dir;
  late EditorViewerArgs viewerArgs;
  bool? saverFlatten;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('fillform_test_');
    saverFlatten = null;
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
        return [37, 80, 68, 70];
      },
    ),
  ];

  Future<void> open(WidgetTester tester) => pumpEditorScreen(
    tester,
    screen: const FillFormScreen(path: '/x/Don xin viec.pdf'),
    overrides: overrides(),
  );

  testWidgets('hien goi y dien form', (tester) async {
    await open(tester);
    expect(find.text('Don xin viec.pdf'), findsOneWidget);
    expect(find.text('Tap a field on the page to fill it in.'), findsOneWidget);
  });

  testWidgets('PDF khong co o form: hien canh bao sau khi nap xong', (
    tester,
  ) async {
    await open(tester);
    // Controller chưa gắn viewer thật → getFormFields() rỗng.
    viewerArgs.onLoaded!();
    await tester.pump();
    expect(find.text('This PDF has no fillable form fields.'), findsOneWidget);
  });

  testWidgets('luu khi chua dien gi: bao khong co thay doi', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('save')));
    await tester.pump();
    expect(
      find.text('There are no changes to save yet.'),
      findsAtLeastNWidgets(1),
    );
    expect(dir.listSync(), isEmpty);
  });

  testWidgets('dien xong -> luu file moi _filled, giu cac o sua duoc', (
    tester,
  ) async {
    await open(tester);
    viewerArgs.onChanged!();
    await tester.pump();
    await tester.tap(find.byKey(const Key('save')));
    await settle(tester, until: () => find.text('Saved').evaluate().isNotEmpty);

    expect(
      File('${dir.path}${Platform.pathSeparator}Don xin viec_filled.pdf')
          .existsSync(),
      isTrue,
    );
    expect(saverFlatten, isFalse);
  });

  testWidgets('luu ban phang qua menu: truyen flatten = true', (tester) async {
    await open(tester);
    viewerArgs.onChanged!();
    await tester.pump();
    await tester.tap(find.byKey(const Key('saveMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Save flattened'));
    await settle(tester, until: () => find.text('Saved').evaluate().isNotEmpty);

    expect(saverFlatten, isTrue);
    expect(dir.listSync(), hasLength(1));
  });

  testWidgets('thoat khi da dien nhung chua luu: hoi xac nhan', (tester) async {
    await open(tester);
    viewerArgs.onChanged!();
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
  });
}
