import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pdf_layout/pdf_layout.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/core/navigation/open_file_args.dart';
import 'package:pdf_office/features/reading/data/reflow_loader.dart';
import 'package:pdf_office/features/reading/logic/reflow_document.dart';
import 'package:pdf_office/features/reading/logic/reflow_prefs.dart';
import 'package:pdf_office/features/reading/reflow_args.dart';
import 'package:pdf_office/features/reading/reflow_hooks.dart';
import 'package:pdf_office/features/reading/reflow_screen.dart';

import '../reader/test_app.dart';

DocParagraph para(String text) => DocParagraph(spans: [DocSpan(text)]);

/// Tài liệu giả 2 trang: tiêu đề, đoạn, danh sách / bảng.
ReflowDocument sampleDoc() => buildReflowDocument([
  const DocHeading(level: 1, spans: [DocSpan('Báo cáo năm')]),
  para('Đoạn mở đầu nói về an toàn.'),
  const DocListItem(ordered: true, marker: '1.', spans: [DocSpan('Mục một')]),
  const DocPageBreak(),
  const DocTable(
    cells: [
      ['Tên', 'Tuổi'],
      ['An', '20'],
    ],
  ),
  para('Kết luận.'),
]);

class _Harness {
  final passwords = <String?>[];
  final translated = <List<String>>[];
  List<String>? barParagraphs;
  ValueChanged<int>? onParagraph;

  Widget build(
    Future<ReflowDocument> Function() load, {
    OpenFileArgs args = const OpenFileArgs('/docs/bao-cao.pdf'),
    ReflowMode mode = ReflowMode.read,
  }) => ProviderScope(
    overrides: [
      reflowLoaderProvider.overrideWithValue((path, {password}) {
        passwords.add(password);
        return load();
      }),
      reflowTranslatorProvider.overrideWithValue((context, paragraphs) async {
        translated.add(paragraphs);
      }),
      reflowReadAloudBuilderProvider.overrideWithValue((paragraphs, cb) {
        barParagraphs = paragraphs;
        onParagraph = cb;
        return const SizedBox(key: Key('fakeReadAloudBar'), height: 40);
      }),
    ],
    child: testApp(ReflowScreen(args: args, mode: mode)),
  );
}

ReflowPrefs prefsOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(ReflowScreen)),
).read(reflowPrefsProvider);

void main() {
  testWidgets('hiện tiêu đề, đoạn, danh sách, hàng bảng và ngăn trang', (
    tester,
  ) async {
    final h = _Harness();
    await tester.pumpWidget(h.build(() async => sampleDoc()));
    await tester.pumpAndSettle();

    expect(find.text('bao-cao.pdf'), findsOneWidget);
    expect(find.text('Báo cáo năm'), findsOneWidget);
    expect(find.text('Đoạn mở đầu nói về an toàn.'), findsOneWidget);
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('Mục một'), findsOneWidget);
    expect(find.text('Tên · Tuổi'), findsOneWidget);
    expect(find.text('— Page 1 —'), findsOneWidget);
    expect(find.text('— Page 2 —'), findsOneWidget);
    // Chế độ đọc thường: chưa có thanh đọc to.
    expect(find.byKey(const Key('fakeReadAloudBar')), findsNothing);
    expect(h.passwords, [null]);
  });

  testWidgets('truyền mật khẩu đã nhập cho phần trích chữ', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(
      h.build(
        () async => sampleDoc(),
        args: const OpenFileArgs('/a.pdf', password: 'pw-test'),
      ),
    );
    await tester.pumpAndSettle();
    expect(h.passwords, ['pw-test']);
  });

  testWidgets('PDF quét → EmptyState + nút mở PDF sang văn bản', (
    tester,
  ) async {
    final h = _Harness();
    await tester.pumpWidget(
      h.build(() async => const ReflowDocument.empty(pageCount: 2)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reflow_noText')), findsOneWidget);
    expect(find.text('This page is an image, no text yet'), findsOneWidget);
    expect(find.text('Open PDF to text'), findsOneWidget);
  });

  testWidgets('lỗi đọc file → EmptyState lỗi', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(
      h.build(() async => throw const CorruptFile('bad')),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Symbols.error_rounded), findsOneWidget);
  });

  testWidgets('tìm chữ: đếm kết quả trên mọi dòng', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build(() async => sampleDoc()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reflow_searchButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reflow_searchBar')), findsOneWidget);

    // "an" có trong "an toàn" và hàng bảng "An · 20" (không phân biệt hoa thường).
    await tester.enterText(find.byType(TextField), 'an');
    await tester.pumpAndSettle();
    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets('bảng Hiển thị: A+ tăng cỡ chữ, chọn nền sepia, giãn dòng rộng', (
    tester,
  ) async {
    final h = _Harness();
    await tester.pumpWidget(h.build(() async => sampleDoc()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reflow_displayButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reflow_fontLarger')));
    await tester.pumpAndSettle();
    expect(prefsOf(tester).fontSize, kReflowDefaultFont + 2);
    expect(find.text('${(kReflowDefaultFont + 2).round()}'), findsOneWidget);

    await tester.tap(find.byKey(const Key('reflow_theme_sepia')));
    await tester.pumpAndSettle();
    expect(prefsOf(tester).theme, ReflowTheme.sepia);

    await tester.tap(find.byKey(const Key('reflow_spacing_2')));
    await tester.pumpAndSettle();
    expect(prefsOf(tester).lineHeight, kReflowLineHeights[2]);
  });

  testWidgets('chế độ đọc to: có thanh đọc to, báo đoạn → tô nhẹ đoạn đó', (
    tester,
  ) async {
    final h = _Harness();
    final doc = sampleDoc();
    await tester.pumpWidget(
      h.build(() async => doc, mode: ReflowMode.readAloud),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fakeReadAloudBar')), findsOneWidget);
    expect(h.barParagraphs, doc.paragraphs);
    expect(find.byKey(const Key('reflow_speaking')), findsNothing);

    h.onParagraph!(1);
    await tester.pumpAndSettle();
    final speaking = find.byKey(const Key('reflow_speaking'));
    expect(speaking, findsOneWidget);
    expect(
      find.descendant(
        of: speaking,
        matching: find.text('Đoạn mở đầu nói về an toàn.'),
      ),
      findsOneWidget,
    );

    // Nút trên thanh tiêu đề ẩn thanh đọc to.
    await tester.tap(find.byKey(const Key('reflow_readAloudButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fakeReadAloudBar')), findsNothing);
    expect(find.byKey(const Key('reflow_speaking')), findsNothing);
  });

  testWidgets('nút Dịch → dịch cả tài liệu', (tester) async {
    final h = _Harness();
    final doc = sampleDoc();
    await tester.pumpWidget(h.build(() async => doc));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reflow_translateButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Translate whole document'));
    await tester.pumpAndSettle();
    expect(h.translated, [doc.paragraphs]);
  });

  testWidgets('nút Dịch → dịch đoạn đang thấy', (tester) async {
    final h = _Harness();
    final doc = sampleDoc();
    await tester.pumpWidget(h.build(() async => doc));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reflow_translateButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Translate visible text'));
    await tester.pumpAndSettle();
    // Tài liệu ngắn, thấy hết trên màn.
    expect(h.translated, [doc.paragraphs]);
  });

  testWidgets('chế độ dịch: mở bảng dịch cho trang đang đọc', (tester) async {
    final h = _Harness();
    final doc = sampleDoc();
    await tester.pumpWidget(
      h.build(
        () async => doc,
        args: const OpenFileArgs('/a.pdf', initialPage: 1),
        mode: ReflowMode.translate,
      ),
    );
    await tester.pumpAndSettle();
    expect(h.translated, [doc.paragraphsOfPage(1)]);
    expect(h.translated.single, ['Tên, Tuổi', 'An, 20', 'Kết luận.']);
  });

  testWidgets('cuộn tới trang initialPage', (tester) async {
    final h = _Harness();
    final long = List.filled(12, 'Một đoạn văn khá dài để chiếm chỗ trên màn hình đọc.');
    final blocks = <DocBlock>[
      for (var page = 0; page < 8; page++) ...[
        if (page > 0) const DocPageBreak(),
        DocHeading(level: 2, spans: [DocSpan('Tiêu đề trang ${page + 1}')]),
        for (final t in long) para(t),
      ],
    ];
    await tester.pumpWidget(
      h.build(
        () async => buildReflowDocument(blocks),
        args: const OpenFileArgs('/a.pdf', initialPage: 6),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tiêu đề trang 7').hitTestable(), findsOneWidget);
    expect(find.text('Tiêu đề trang 1').hitTestable(), findsNothing);
  });
}
