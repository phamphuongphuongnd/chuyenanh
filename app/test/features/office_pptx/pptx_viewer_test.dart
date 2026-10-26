import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/l10n/app_localizations.dart';
import 'package:pdf_office/features/office_pptx/office_pptx_providers.dart';
import 'package:pdf_office/features/office_pptx/pptx_engine_impl.dart';
import 'package:pdf_office/features/office_pptx/pptx_viewer_screen.dart';
import 'package:pdf_office/features/office_pptx/slide_view.dart';
import 'package:pptx_reader/pptx_reader.dart';

const _fixtures = '../packages/pptx_reader/test/fixtures/real';

PptxTextShape _text(String t, {int x = 0, int y = 0}) => PptxTextShape(
  frame: PptxRect(x, y, 4000000, 1000000),
  fill: const PptxFill.solid(0xFFFFF2CC),
  line: const PptxLine(colorArgb: 0xFF000000, widthEmu: 12700),
  paragraphs: [
    PptxParagraph(
      bulletChar: '•',
      marginLeftEmu: 342900,
      indentEmu: -342900,
      runs: [PptxRun(text: t, bold: true, fontSizePt: 24)],
    ),
    const PptxParagraph(
      numbered: true,
      runs: [PptxRun(text: 'hai', italic: true, strike: true)],
    ),
  ],
);

PptxDeck _deck() => PptxDeck(
  slideWidthEmu: 9144000,
  slideHeightEmu: 5143500,
  slides: [
    PptxSlide(
      index: 0,
      background: const PptxFill.solid(0xFFEEEEFF),
      notesText: 'Ghi chu mot',
      shapes: [
        _text('Slide mot'),
        const PptxTextShape(
          frame: PptxRect(0, 2000000, 2000000, 1000000),
          unsupportedKind: 'chart',
        ),
        PptxGroupShape(
          frame: const PptxRect(5000000, 2000000, 1000000, 1000000),
          rotationDeg: 30,
          children: [_text('trong nhom', x: 5000000, y: 2000000)],
        ),
        PptxTableShape(
          frame: const PptxRect(0, 3200000, 4000000, 800000),
          columnWidthsEmu: const [2000000, 2000000],
          rows: const [
            PptxTableRow(
              heightEmu: 400000,
              cells: [
                PptxTableCell(
                  paragraphs: [
                    PptxParagraph(runs: [PptxRun(text: 'A')]),
                  ],
                ),
                PptxTableCell(
                  paragraphs: [
                    PptxParagraph(runs: [PptxRun(text: 'B')]),
                  ],
                ),
              ],
            ),
          ],
        ),
        const PptxTextShape(
          frame: PptxRect(6000000, 3000000, 2000000, 1000000),
          geometry: PptxGeometry.other,
          customPaths: [
            PptxCustomPath(
              widthEmu: 100,
              heightEmu: 100,
              commands: [
                PptxPathCommand(PptxPathOp.moveTo, [0, 0]),
                PptxPathCommand(PptxPathOp.lineTo, [100, 50]),
                PptxPathCommand(PptxPathOp.lineTo, [0, 100]),
                PptxPathCommand(PptxPathOp.close),
              ],
            ),
          ],
          fill: PptxFill.solid(0xFF3366CC),
        ),
      ],
    ),
    PptxSlide(
      index: 1,
      background: null,
      notesText: null,
      shapes: [_text('Slide hai')],
    ),
    PptxSlide(
      index: 2,
      background: null,
      notesText: null,
      hidden: true,
      shapes: [_text('Slide an')],
    ),
  ],
);

Widget _app(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: child,
      ),
    );

void main() {
  testWidgets('hiện slide đầu, chuyển slide bằng thumbnail, ghi chú, slide ẩn', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(PptxDeckView(deck: _deck(), title: 'x.pptx')),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.text('Not supported'), findsWidgets);

    // Ghi chú
    await tester.tap(find.byTooltip('Notes'));
    await tester.pump();
    expect(find.text('Ghi chu mot'), findsOneWidget);

    // Vuốt sang slide 2
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('No notes for this slide'), findsOneWidget);

    // Hiện slide ẩn
    await tester.tap(find.byTooltip('Show hidden slides'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);

    // Bấm thumbnail slide 3
    await tester.tap(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Slide 3'));
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
  });

  testWidgets('deck rỗng báo không có slide', (tester) async {
    await tester.pumpWidget(
      _app(
        const PptxDeckView(
          deck: PptxDeck(slideWidthEmu: 1, slideHeightEmu: 1, slides: []),
          title: 't',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('This presentation has no slides'), findsOneWidget);
  });

  testWidgets('màn xem nạp deck qua provider; lỗi → thông báo + thử lại', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const PptxViewerScreen(path: '/x/y.pptx'),
        overrides: [
          pptxDeckLoaderProvider.overrideWithValue(
            (_) async => throw Exception('hong'),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
  });

  for (final name in ['deck_16x9', 'deck_4x3_theme', 'deck_extras']) {
    testWidgets('vẽ file thật $name không lỗi layout', (tester) async {
      final PptxDeck deck = (await tester.runAsync(
        () => loadPptxDeckFromBytes(
          Uint8List.fromList(File('$_fixtures/$name.pptx').readAsBytesSync()),
        ),
      ))!;
      await tester.binding.setSurfaceSize(const Size(500, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(PptxDeckView(deck: deck, title: name)));
      await tester.pump();
      expect(find.byType(SlideView), findsWidgets);
      // Duyệt hết các slide để lộ mọi lỗi vẽ.
      final n = deck.slides.where((s) => !s.hidden).length;
      for (var i = 1; i < n; i++) {
        await tester.fling(find.byType(PageView), const Offset(-400, 0), 2000);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
