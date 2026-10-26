import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:office_reader/office_reader.dart' as rd;
import 'package:pdf_office/core/utils/link_opener.dart';
import 'package:pdf_office/features/office_pptx/slide_view.dart';
import 'package:pdf_office/features/office_viewer/widgets/docx_view.dart';
import 'package:pdf_office/l10n/app_localizations.dart';
import 'package:pptx_reader/pptx_reader.dart';

Widget host(Widget child, List<Uri> opened, {bool result = true}) =>
    ProviderScope(
      overrides: [
        linkLauncherProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return result;
        }),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: child)),
      ),
    );

Widget docx(String url) => DocxParagraphView(
  para: rd.DocxParagraph(
    inlines: [rd.DocxRun(text: 'clickme', hyperlink: url)],
  ),
  ctx: const DocxRenderCtx(),
);

Widget pptx(String url) => ParagraphWidget(
  paragraph: PptxParagraph(runs: [PptxRun(text: 'clickme', hyperlink: url)]),
  bullet: null,
  wrap: true,
  defaultColor: Colors.black,
);

Future<void> tapLink(WidgetTester tester) async {
  await tester.tapOnText(find.textRange.ofSubstring('clickme'));
  await tester.pump();
}

void main() {
  for (final entry in {'docx': docx, 'pptx': pptx}.entries) {
    group('mo lien ket ${entry.key}', () {
      testWidgets('https goi launcher va hien URL', (tester) async {
        final opened = <Uri>[];
        await tester.pumpWidget(host(entry.value('https://a.com/x'), opened));
        await tapLink(tester);
        expect(opened.single.toString(), 'https://a.com/x');
        expect(find.textContaining('https://a.com/x'), findsOneWidget);
      });

      testWidgets('scheme nguy hiem khong goi launcher, bao loi', (
        tester,
      ) async {
        final opened = <Uri>[];
        await tester.pumpWidget(
          host(entry.value('javascript:alert(1)'), opened),
        );
        await tapLink(tester);
        expect(opened, isEmpty);
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.textContaining('Could not open'), findsOneWidget);
      });

      testWidgets('launcher tra false thi bao loi, khong crash', (
        tester,
      ) async {
        final opened = <Uri>[];
        await tester.pumpWidget(
          host(entry.value('https://a.com'), opened, result: false),
        );
        await tapLink(tester);
        expect(opened, hasLength(1));
        expect(find.textContaining('Could not open'), findsOneWidget);
      });
    });
  }
}
