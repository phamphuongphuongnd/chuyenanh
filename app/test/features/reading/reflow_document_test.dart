import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_layout/pdf_layout.dart';
import 'package:pdf_office/features/reading/logic/reflow_document.dart';

DocParagraph para(String text, {bool bold = false}) =>
    DocParagraph(spans: [DocSpan(text, bold: bold)]);

void main() {
  group('reflowParagraphs', () {
    test('tiêu đề, đoạn, danh sách, hàng bảng → mỗi thứ một đoạn; bỏ ngăn trang', () {
      final blocks = <DocBlock>[
        const DocHeading(level: 1, spans: [DocSpan('Chương 1')]),
        para('Đoạn   mở\nđầu. '),
        const DocListItem(
          ordered: false,
          marker: '•',
          spans: [DocSpan('Mục chấm')],
        ),
        const DocListItem(ordered: true, marker: '2.', spans: [DocSpan('Mục số')]),
        const DocPageBreak(),
        const DocTable(
          cells: [
            ['Tên', 'Tuổi'],
            ['', ''],
            ['An', ' 20 '],
          ],
        ),
      ];
      expect(reflowParagraphs(blocks), [
        'Chương 1',
        'Đoạn mở đầu.',
        'Mục chấm',
        '2. Mục số',
        'Tên, Tuổi',
        'An, 20',
      ]);
    });

    test('khối rỗng và tài liệu rỗng → không có đoạn', () {
      expect(reflowParagraphs(const []), isEmpty);
      expect(
        reflowParagraphs([para('   '), const DocPageBreak(), para('')]),
        isEmpty,
      );
    });

    test('gộp dấu tiếng Việt rời (NFD → NFC)', () {
      // "Việt" viết dạng NFD: e + mũ (U+0302) + nặng (U+0323).
      const nfd = 'Việt';
      expect(reflowParagraphs([para(nfd)]), ['Việt']);
    });
  });

  group('buildReflowDocument', () {
    test('nhiều trang: ngăn trang ở đầu mỗi trang, trang không chữ có dòng ảnh', () {
      final doc = buildReflowDocument([
        para('Trang một'),
        const DocPageBreak(),
        const DocPageBreak(),
        const DocHeading(level: 2, spans: [DocSpan('Trang ba')]),
      ]);
      expect(doc.pageCount, 3);
      expect(doc.items.map((i) => (i.kind, i.page)).toList(), [
        (ReflowKind.pageMarker, 0),
        (ReflowKind.paragraph, 0),
        (ReflowKind.pageMarker, 1),
        (ReflowKind.imagePage, 1),
        (ReflowKind.pageMarker, 2),
        (ReflowKind.heading, 2),
      ]);
      expect(doc.paragraphs, ['Trang một', 'Trang ba']);
      expect(doc.paragraphItems, [1, 5]);
      expect(doc.itemOfParagraph(1), 5);
      expect(doc.itemOfParagraph(2), isNull);
      expect(doc.itemOfParagraph(-1), isNull);
      expect(doc.firstItemOfPage(2), 4);
      expect(doc.firstItemOfPage(99), doc.items.length - 1);
      expect(doc.paragraphsOfPage(2), ['Trang ba']);
      expect(doc.paragraphsOfPage(1), isEmpty);
      expect(doc.paragraphsInRange(0, 3), ['Trang một']);
    });

    test('một trang: không có ngăn trang', () {
      final doc = buildReflowDocument([para('A'), para('B', bold: true)]);
      expect(doc.items.map((i) => i.kind), [
        ReflowKind.paragraph,
        ReflowKind.paragraph,
      ]);
      expect(doc.items[1].bold, isTrue);
      expect(doc.items[0].bold, isFalse);
    });

    test('hàng bảng hiện các ô nối bằng " · ", danh sách giữ dấu đầu dòng', () {
      final doc = buildReflowDocument(const [
        DocTable(
          cells: [
            ['a', 'b', 'c'],
          ],
        ),
        DocListItem(ordered: false, marker: ' ', spans: [DocSpan('x')]),
      ]);
      expect(doc.items[0].kind, ReflowKind.tableRow);
      expect(doc.items[0].text, 'a · b · c');
      expect(doc.items[0].cells, ['a', 'b', 'c']);
      expect(doc.items[1].marker, '•');
      expect(doc.itemTexts, ['a · b · c', 'x']);
    });

    test('toàn trang trống → tài liệu không có chữ nhưng giữ số trang', () {
      final doc = buildReflowDocument(const [DocPageBreak(), DocPageBreak()]);
      expect(doc.hasText, isFalse);
      expect(doc.pageCount, 3);
      expect(doc.items, isEmpty);
    });
  });
}
