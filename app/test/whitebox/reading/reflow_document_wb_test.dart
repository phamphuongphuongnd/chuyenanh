// Kiểm thử hộp trắng (A15) — reflow_document.dart. Mã bộ theo
// test-output/whitebox/reading/reflow_document/buoc-5-du-lieu-thu.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_layout/pdf_layout.dart';
import 'package:pdf_office/features/reading/logic/reflow_document.dart';

DocParagraph _p(String text, {bool bold = false}) =>
    DocParagraph(spans: [DocSpan(text, bold: bold)]);

List<(ReflowKind, int)> _shape(ReflowDocument d) =>
    [for (final i in d.items) (i.kind, i.page)];

void main() {
  group('U1 ReflowItem.hasText', () {
    test('1-1 paragraph ⇒ true', () {
      expect(const ReflowItem(kind: ReflowKind.paragraph, page: 0).hasText, isTrue);
    });
    test('1-2 pageMarker ⇒ false', () {
      expect(const ReflowItem(kind: ReflowKind.pageMarker, page: 0).hasText, isFalse);
    });
    test('1-3 imagePage ⇒ false', () {
      expect(const ReflowItem(kind: ReflowKind.imagePage, page: 0).hasText, isFalse);
    });
  });

  group('U2 ReflowItem.speech', () {
    test('2-1 tableRow ⇒ ô nối bằng ", "', () {
      const i = ReflowItem(
        kind: ReflowKind.tableRow,
        page: 0,
        text: 'a · b',
        cells: ['a', 'b'],
      );
      expect(i.speech, 'a, b');
    });
    test('2-2 listItem đánh số ⇒ giữ số thứ tự', () {
      const i = ReflowItem(
        kind: ReflowKind.listItem,
        page: 0,
        text: 'x',
        marker: '2.',
        ordered: true,
      );
      expect(i.speech, '2. x');
    });
    test('2-3 listItem chấm ⇒ chỉ chữ', () {
      const i = ReflowItem(kind: ReflowKind.listItem, page: 0, text: 'x', marker: '•');
      expect(i.speech, 'x');
    });
    test('2-4 paragraph ⇒ chữ', () {
      const i = ReflowItem(kind: ReflowKind.paragraph, page: 0, text: 'p');
      expect(i.speech, 'p');
    });
  });

  group('U3 itemOfParagraph', () {
    final doc = buildReflowDocument([_p('A'), _p('B')]);
    test('3-1 đoạn 0 ⇒ dòng 0', () => expect(doc.itemOfParagraph(0), 0));
    test('3-2 -1 ⇒ null', () => expect(doc.itemOfParagraph(-1), isNull));
    test('3-3 2 (= số đoạn) ⇒ null', () => expect(doc.itemOfParagraph(2), isNull));
  });

  group('U4 firstItemOfPage', () {
    // [marker0, A, marker1, B]
    final doc = buildReflowDocument([_p('A'), const DocPageBreak(), _p('B')]);
    test('4-1 tài liệu rỗng ⇒ 0', () {
      expect(const ReflowDocument.empty().firstItemOfPage(3), 0);
    });
    test('4-2 trang 0 ⇒ dòng 0 (ngăn trang)', () => expect(doc.firstItemOfPage(0), 0));
    test('4-3 trang 99 ⇒ kẹp về dòng cuối', () => expect(doc.firstItemOfPage(99), 3));
    test('4-4 trang 1 ⇒ dòng 2', () => expect(doc.firstItemOfPage(1), 2));
  });

  group('U5 _allBold (qua buildReflowDocument)', () {
    test('5-1 mọi span in đậm ⇒ bold', () {
      final d = buildReflowDocument([
        const DocParagraph(spans: [DocSpan('A ', bold: true), DocSpan('B', bold: true)]),
      ]);
      expect(d.items.single.bold, isTrue);
    });
    test('5-2 chỉ span khoảng trắng ⇒ đoạn rỗng bị bỏ (kết quả bold không quan sát được)', () {
      final d = buildReflowDocument([
        const DocParagraph(spans: [DocSpan('   ', bold: true)]),
      ]);
      expect(d.items, isEmpty);
    });
    test('5-3 span đậm lẫn thường ⇒ không bold', () {
      final d = buildReflowDocument([
        const DocParagraph(spans: [DocSpan('A ', bold: true), DocSpan('B')]),
      ]);
      expect(d.items.single.bold, isFalse);
    });
  });

  group('U6 buildReflowDocument', () {
    test('6-1 một đoạn, một trang ⇒ 1 dòng paragraph, không ngăn trang', () {
      final d = buildReflowDocument([_p('A')]);
      expect(_shape(d), [(ReflowKind.paragraph, 0)]);
      expect(d.pageCount, 1);
      expect(d.paragraphs, ['A']);
    });
    test('6-2 không khối ⇒ rỗng, 0 trang', () {
      final d = buildReflowDocument(const []);
      expect(d.items, isEmpty);
      expect(d.pageCount, 0);
    });
    test('6-3 hai trang ⇒ ngăn trang đầu mỗi trang', () {
      final d = buildReflowDocument([_p('A'), const DocPageBreak(), _p('B')]);
      expect(_shape(d), [
        (ReflowKind.pageMarker, 0),
        (ReflowKind.paragraph, 0),
        (ReflowKind.pageMarker, 1),
        (ReflowKind.paragraph, 1),
      ]);
      expect(d.pageCount, 2);
    });
    test('6-4 tiêu đề cấp 5 ⇒ cấp 3, in đậm', () {
      final d = buildReflowDocument([
        const DocHeading(level: 5, spans: [DocSpan('T')]),
      ]);
      final h = d.items.single;
      expect(h.kind, ReflowKind.heading);
      expect(h.level, 3);
      expect(h.bold, isTrue);
    });
    test('6-5 mục đánh số marker " 1. " ⇒ marker "1.", ordered', () {
      final d = buildReflowDocument([
        const DocListItem(ordered: true, marker: ' 1. ', spans: [DocSpan('x')]),
      ]);
      final i = d.items.single;
      expect(i.kind, ReflowKind.listItem);
      expect(i.marker, '1.');
      expect(i.ordered, isTrue);
    });
    test('6-6 mục marker trống ⇒ "•"', () {
      final d = buildReflowDocument([
        const DocListItem(ordered: false, marker: '  ', spans: [DocSpan('x')]),
      ]);
      expect(d.items.single.marker, '•');
    });
    test('6-7 bảng 1 hàng ⇒ tableRow "a · b", ô đã làm sạch', () {
      final d = buildReflowDocument(const [
        DocTable(cells: [
          ['a', ' b '],
        ]),
      ]);
      final r = d.items.single;
      expect(r.kind, ReflowKind.tableRow);
      expect(r.text, 'a · b');
      expect(r.cells, ['a', 'b']);
    });
    test('6-8 hàng toàn ô trống bị bỏ', () {
      final d = buildReflowDocument(const [
        DocTable(cells: [
          ['', ' '],
          ['c'],
        ]),
      ]);
      expect(d.items.map((i) => i.text), ['c']);
    });
    test('6-9 bảng không hàng ⇒ tài liệu không chữ, 1 trang', () {
      final d = buildReflowDocument(const [DocTable(cells: [])]);
      expect(d.items, isEmpty);
      expect(d.hasText, isFalse);
      expect(d.pageCount, 1);
    });
    test('6-10 đoạn chỉ khoảng trắng ⇒ không chữ, 1 trang', () {
      final d = buildReflowDocument([_p('   ')]);
      expect(d.items, isEmpty);
      expect(d.pageCount, 1);
    });
    test('6-11 chỉ ngăn trang ⇒ không chữ, giữ 2 trang', () {
      final d = buildReflowDocument(const [DocPageBreak()]);
      expect(d.items, isEmpty);
      expect(d.hasText, isFalse);
      expect(d.pageCount, 2);
    });
  });

  group('U7 startPage / U8 endPage / U9 add', () {
    test('7-1 một trang ⇒ không ngăn trang', () {
      expect(buildReflowDocument([_p('A')]).items.first.kind, ReflowKind.paragraph);
    });
    test('7-2 nhiều trang ⇒ có ngăn trang', () {
      final d = buildReflowDocument([_p('A'), const DocPageBreak(), _p('B')]);
      expect(d.items.first.kind, ReflowKind.pageMarker);
    });
    test('8-1 một trang không chữ ⇒ không thêm dòng ảnh', () {
      // trang duy nhất có chữ: không có imagePage
      final d = buildReflowDocument([_p('A')]);
      expect(d.items.where((i) => i.kind == ReflowKind.imagePage), isEmpty);
    });
    test('8-2 nhiều trang, trang có chữ ⇒ không dòng ảnh', () {
      final d = buildReflowDocument([_p('A'), const DocPageBreak(), _p('B')]);
      expect(d.items.where((i) => i.kind == ReflowKind.imagePage), isEmpty);
    });
    test('8-3 nhiều trang, trang 0 không chữ ⇒ dòng ảnh trang 0', () {
      final d = buildReflowDocument([const DocPageBreak(), _p('B')]);
      expect(_shape(d), [
        (ReflowKind.pageMarker, 0),
        (ReflowKind.imagePage, 0),
        (ReflowKind.pageMarker, 1),
        (ReflowKind.paragraph, 1),
      ]);
    });
    test('9-1 chữ rỗng ⇒ bỏ', () {
      final d = buildReflowDocument([_p(''), _p('B')]);
      expect(d.items.map((i) => i.text), ['B']);
    });
    test('9-2 chữ có ⇒ thêm', () {
      expect(buildReflowDocument([_p('B')]).items.single.text, 'B');
    });
  });
}
