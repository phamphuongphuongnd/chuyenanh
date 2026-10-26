import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:office_reader/office_reader.dart' as rd;
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/features/office_viewer/data/text_decoder.dart';
import 'package:pdf_office/features/office_viewer/widgets/docx_view.dart';
import 'package:pdf_office/features/office_viewer/widgets/txt_viewer_page.dart';
import 'package:pdf_office/features/office_viewer/widgets/xlsx_view.dart';

Widget app(Widget home) => ProviderScope(
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

rd.XlsxCell cell(String text, {bool bold = false, int? fill}) => rd.XlsxCell(
  display: text,
  raw: text,
  type: rd.XlsxCellType.string,
  style: rd.XlsxStyle(bold: bold, fillArgb: fill),
);

rd.DocxParagraph para(String text, {int? heading, String? label}) =>
    rd.DocxParagraph(
      headingLevel: heading,
      listLevel: label == null ? null : 0,
      listLabel: label,
      inlines: [rd.DocxRun(text: text)],
    );

void main() {
  group('XlsxViewerPage', () {
    final wb = rd.XlsxWorkbook(
      sheets: [
        rd.XlsxSheet(
          name: 'Alpha',
          maxRow: 3,
          maxCol: 3,
          cells: {
            (0, 0): cell('Tieu de gop', bold: true, fill: 0xFFFFEB9C),
            (1, 0): cell('a-one'),
            (2, 2): cell('c3'),
          },
          merges: const [rd.XlsxRange(0, 0, 0, 2)],
          frozenRows: 1,
        ),
        rd.XlsxSheet(
          name: 'Secret',
          maxRow: 1,
          maxCol: 1,
          cells: {(0, 0): cell('hidden-text')},
          hidden: true,
        ),
        rd.XlsxSheet(
          name: 'Beta',
          maxRow: 1,
          maxCol: 1,
          cells: {(0, 0): cell('beta-cell')},
        ),
      ],
    );

    testWidgets('hiện sheet đầu, ẩn sheet hidden, chuyển tab đổi nội dung', (
      tester,
    ) async {
      await tester.pumpWidget(app(XlsxViewerPage(path: '/x/b.xlsx', workbook: wb)));
      await tester.pumpAndSettle();

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Secret'), findsNothing);
      expect(find.text('Tieu de gop'), findsOneWidget);
      expect(find.text('a-one'), findsOneWidget);
      expect(find.text('beta-cell'), findsNothing);
      // Nhãn cột/hàng
      expect(find.text('A'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('sheetTab1')));
      await tester.pumpAndSettle();
      expect(find.text('beta-cell'), findsOneWidget);
      expect(find.text('a-one'), findsNothing);
    });

    testWidgets('ô gộp rộng bằng tổng 3 cột', (tester) async {
      await tester.pumpWidget(app(XlsxViewerPage(path: '/x/b.xlsx', workbook: wb)));
      await tester.pumpAndSettle();
      final merged = tester.getSize(find.text('Tieu de gop').first);
      expect(merged.width, greaterThan(0));
      // Ô đầu tiên (gộp) rộng hơn một cột mặc định.
      final box = tester.getRect(
        find
            .ancestor(
              of: find.text('Tieu de gop'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(box.width, greaterThanOrEqualTo((8.43 * 7 + 5) * 3 - 1));
    });

    testWidgets('sheet trống hiện thông báo', (tester) async {
      await tester.pumpWidget(
        app(
          XlsxViewerPage(
            path: '/x/e.xlsx',
            workbook: rd.XlsxWorkbook(
              sheets: [
                rd.XlsxSheet(name: 'E', maxRow: 0, maxCol: 0, cells: const {}),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('This sheet is empty'), findsOneWidget);
    });
  });

  group('DocxViewerPage', () {
    final doc = rd.DocxDocument(
      page: rd.DocxPageSetup.a4,
      blocks: [
        para('Chuong mot', heading: 1),
        para('Noi dung doan van dau tien.'),
        para('Muc A', label: '1.'),
        rd.DocxTable(
          columnWidthsTwips: const [3000, 3000],
          bordered: true,
          rows: [
            rd.DocxTableRow(
              cells: [
                rd.DocxTableCell(
                  blocks: [para('Gop ngang')],
                  gridSpan: 2,
                ),
              ],
            ),
            rd.DocxTableRow(
              cells: [
                rd.DocxTableCell(blocks: [para('Gop doc')], rowSpan: 2),
                rd.DocxTableCell(blocks: [para('o-phai-tren')]),
              ],
            ),
            rd.DocxTableRow(
              cells: [
                const rd.DocxTableCell(blocks: [], vMergeContinue: true),
                rd.DocxTableCell(blocks: [para('o-phai-duoi')]),
              ],
            ),
          ],
        ),
        rd.DocxParagraph(
          inlines: [
            rd.DocxImage(
              bytes: Uint8List.fromList([1, 2, 3]),
              extension: 'emf',
              widthEmu: 12700 * 50,
              heightEmu: 12700 * 20,
            ),
          ],
        ),
        para('Cuoi cung'),
      ],
    );

    testWidgets('vẽ đoạn, list, bảng gộp ô, ảnh lỗi → placeholder', (
      tester,
    ) async {
      await tester.pumpWidget(app(DocxViewerPage(path: '/x/a.docx', document: doc)));
      await tester.pumpAndSettle();

      expect(find.text('Chuong mot'), findsOneWidget);
      expect(find.text('1.'), findsOneWidget);
      expect(find.text('Muc A'), findsOneWidget);
      expect(find.text('Gop ngang'), findsOneWidget);
      expect(find.text('o-phai-duoi'), findsOneWidget);
      expect(find.text("Image can't be displayed"), findsOneWidget);

      // Ô "Gop doc" cao bằng 2 hàng (rowSpan 2) -> cao hơn ô bên phải trên.
      final left = tester.getRect(
        find.ancestor(of: find.text('Gop doc'), matching: find.byType(DecoratedBox)).first,
      );
      final rt = tester.getRect(
        find.ancestor(of: find.text('o-phai-tren'), matching: find.byType(DecoratedBox)).first,
      );
      expect(left.height, greaterThan(rt.height * 1.5));
      // Ô "Gop ngang" rộng gấp đôi ô "o-phai-tren".
      final top = tester.getRect(
        find.ancestor(of: find.text('Gop ngang'), matching: find.byType(DecoratedBox)).first,
      );
      expect(top.width, closeTo(rt.width * 2, 1));
    });

    testWidgets('tìm chữ: đếm kết quả và tô màu', (tester) async {
      await tester.pumpWidget(app(DocxViewerPage(path: '/x/a.docx', document: doc)));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'o-phai');
      await tester.pumpAndSettle();
      expect(find.text('1/2'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'khongco');
      await tester.pumpAndSettle();
      expect(find.text('No results'), findsOneWidget);
    });
  });

  group('TxtViewerPage', () {
    final content = DecodedText(
      List.generate(50, (i) => 'dong $i xin chao').join('\n'),
      TextEncoding.utf16le,
    );

    testWidgets('hiện dòng, bảng mã, tìm chữ và đổi cỡ chữ', (tester) async {
      await tester.pumpWidget(app(TxtViewerPage(path: '/x/n.txt', content: content)));
      await tester.pumpAndSettle();

      expect(find.text('dong 0 xin chao'), findsOneWidget);
      expect(find.text('Encoding: UTF-16 LE'), findsOneWidget);

      final before = tester.widget<Text>(find.text('dong 0 xin chao')).style!.fontSize!;
      await tester.tap(find.byIcon(Icons.text_increase));
      await tester.pumpAndSettle();
      final after = tester.widget<Text>(find.text('dong 0 xin chao')).style!.fontSize!;
      expect(after, before + 2);

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'dong 4');
      await tester.pumpAndSettle();
      // dong 4, 40..49 -> 11 kết quả
      expect(find.text('1/11'), findsOneWidget);
    });

    testWidgets('tìm xa: cuộn tới dòng khớp', (tester) async {
      await tester.pumpWidget(app(TxtViewerPage(path: '/x/n.txt', content: content)));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'dong 49');
      await tester.pumpAndSettle();
      expect(find.textContaining('dong 49', findRichText: true), findsWidgets);
    });
  });
}
