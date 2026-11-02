// Kiểm thử hộp trắng (A18) — lib/src/rebuild.dart. Mong đợi chép từ buoc-5-du-lieu-thu.md.
import 'package:pdf_layout/pdf_layout.dart';
import 'package:test/test.dart';

import '../helpers.dart';

/// 3 dòng thân bài 10 pt ngang cột (72..523) ở y 600/612/624 — cố định lề cột và cỡ thân bài.
List<LayoutLine> _ref() => [
  for (var i = 0; i < 3; i++)
    mkLine('Reference body text that fills the whole column width number $i', marginL, 600.0 + 12 * i, width: fullWidth),
];

/// Khối dựng từ [lines] + khối tham chiếu, đã bỏ khối tham chiếu.
List<DocBlock> _rb(List<LayoutLine> lines, {bool ref = true, RebuildOptions o = const RebuildOptions()}) =>
    rebuildDocument([
      mkPage([...lines, if (ref) ..._ref()]),
    ], options: o).where((b) => !blockText(b).startsWith('Reference')).toList();

DocParagraph _para(List<DocBlock> b) => b.single as DocParagraph;

LayoutLine _tall(String text, double x, double y, double w) => LayoutLine(
  pageIndex: 0,
  text: text,
  bounds: LayoutRect(left: x, top: y, width: w, height: 30),
  fontSize: 10,
  words: [
    LayoutWord(text: text, bounds: LayoutRect(left: x, top: y, width: w, height: 30), fontSize: 10),
  ],
);

const _full = 'First line of body text that wraps around';
const _full2 = 'second line of the same paragraph here';

void main() {
  group('U1 rebuildDocument', () {
    test('U1-P1 1 trang 1 dòng ⇒ 1 đoạn', () {
      final b = rebuildDocument([mkPage([mkLine('Hello world', 72, 100)])]);
      expect(b.single, isA<DocParagraph>());
    });
    test('U1-P2 2 trang ⇒ ngắt trang giữa', () {
      final b = rebuildDocument([
        mkPage([mkLine('Page one', 72, 100)]),
        mkPage([mkLine('Page two', 72, 100, page: 1)], index: 1),
      ]);
      expect(b.map((e) => e.runtimeType), [DocParagraph, DocPageBreak, DocParagraph]);
    });
    test('U1-P3 2 trang, insertPageBreaks false ⇒ không ngắt', () {
      final b = rebuildDocument([
        mkPage([mkLine('Page one', 72, 100)]),
        mkPage([mkLine('Page two', 72, 100, page: 1)], index: 1),
      ], options: const RebuildOptions(insertPageBreaks: false));
      expect(b.map((e) => e.runtimeType), [DocParagraph, DocParagraph]);
    });
    test('U1-P4 có bảng ⇒ DocTable', () {
      final b = rebuildDocument([
        mkPage([for (var r = 0; r < 3; r++) mkRow([('A$r', 72), ('B$r', 200), ('C$r', 330)], 100.0 + 14 * r)]),
      ]);
      expect(b.whereType<DocTable>(), hasLength(1));
    });
    test('U1-P5 0 trang ⇒ rỗng', () => expect(rebuildDocument(const []), isEmpty));
  });

  group('U2 _Metrics.of', () {
    test('U2-P1/P3 giãn dòng 1,6 ⇒ vẫn 1 đoạn (pitch thích nghi)', () {
      final b = _rb([for (var i = 0; i < 3; i++) mkLine('Line $i of the adaptive paragraph text', 72, 100.0 + 16 * i, width: fullWidth)], ref: false);
      expect(b, hasLength(1));
    });
    test('U2-P2 bảng chen giữa ⇒ [đoạn, bảng, đoạn]', () {
      final b = _rb([
        mkLine('Before table', 72, 100),
        for (var r = 0; r < 3; r++) mkRow([('A$r', 72), ('B$r', 200), ('C$r', 330)], 130.0 + 14 * r),
        mkLine('After table', 72, 200),
      ]);
      expect(b.map((e) => e.runtimeType), [DocParagraph, DocTable, DocParagraph]);
    });
    test('U2-P4 tiêu đề 20pt rồi thân bài ⇒ heading 1 + đoạn', () {
      final b = _rb([mkLine('Big Title', 72, 100, size: 20), mkLine('Body after title', 72, 126)]);
      expect((b[0] as DocHeading).level, 1);
      expect(b[1], isA<DocParagraph>());
    });
    test('U2-P5 hai hàng cùng top ⇒ 2 khối, không ném', () {
      final b = _rb([mkLine(_full, 72, 100, width: fullWidth), _tall('Tall line box', 72, 100, fullWidth)]);
      expect(b, hasLength(2));
    });
    test('U2-P6 khe 3 lần cao dòng ⇒ 2 đoạn', () {
      expect(_rb([mkLine(_full, 72, 100, width: fullWidth), mkLine(_full2, 72, 140, width: fullWidth)]), hasLength(2));
    });
    test('U2-P7 trang chỉ có bảng ⇒ chỉ DocTable', () {
      final b = _rb([for (var r = 0; r < 3; r++) mkRow([('A$r', 72), ('B$r', 200), ('C$r', 330)], 100.0 + 14 * r)], ref: false);
      expect(b.single, isA<DocTable>());
    });
    test('U2-P8 chú thích 8pt ngắn + thân 10pt ⇒ thân là đoạn, chú thích có cỡ 8', () {
      final b = _rb([mkLine('fn', 72, 100, size: 8), mkLine('Body text line here', 72, 300)]);
      final fn = b.firstWhere((e) => blockText(e) == 'fn') as DocParagraph;
      expect(fn.spans.single.fontSizePt, 8);
      expect(b.firstWhere((e) => blockText(e).startsWith('Body')), isA<DocParagraph>());
      expect(b.whereType<DocHeading>(), isEmpty);
    });
    test('U2-P9 1 dòng ⇒ 1 đoạn', () => expect(_rb([mkLine('Only line', 72, 100)], ref: false), hasLength(1)));
  });

  group('U3 add', () {
    test('U3-P1/P2 2 dòng gộp được ⇒ 1 đoạn', () {
      expect(_rb([mkLine(_full, 72, 100, width: fullWidth), mkLine(_full2, 72, 112, width: 200)]), hasLength(1));
    });
    test('U3-P3 không gộp ⇒ 2 đoạn', () {
      expect(_rb([mkLine(_full, 72, 100, width: fullWidth), mkLine(_full2, 72, 160, width: 200)]), hasLength(2));
    });
    test('U3-P4 thụt dòng đầu 3 dòng ⇒ 1 đoạn, firstLine 18', () {
      final p = _para(_rb([
        mkLine(_full, 90, 100, width: 433),
        mkLine(_full2, 72, 112, width: fullWidth),
        mkLine('third line', 72, 124, width: 200),
      ]));
      expect((p.indentPt, p.firstLineIndentPt), (0, 18));
    });
    test('U3-P5 3 dòng căn giữa ⇒ 1 đoạn center', () {
      final p = _para(_rb([
        mkLine('Centered title line one', 197.5, 100, width: 200),
        mkLine('Centered line two', 222.5, 112, width: 150),
        mkLine('Line three', 247.5, 124, width: 100),
      ]));
      expect(p.align, DocAlign.center);
    });
  });

  group('U4 _isCenteredRow', () {
    test('U4-P1 dòng ngắn giữa cột ⇒ center', () {
      expect(_para(_rb([mkLine('Centered caption', 247.5, 100, width: 100)])).align, DocAlign.center);
    });
    test('U4-P2 lệch trái ⇒ không center', () {
      expect(_para(_rb([mkLine('Off centre text', 100, 100, width: 100)])).align, isNot(DocAlign.center));
    });
    test('U4-P3 gần kín cột (lề trái 8) ⇒ không center', () {
      expect(_para(_rb([mkLine('Almost full width line of text', 80, 100, width: 435)])).align, isNot(DocAlign.center));
    });
    test('U4-P4 lề phải 11 ≤ 2fs ⇒ không center', () {
      expect(_para(_rb([mkLine('Shifted line of text here', 101, 100, width: 411)])).align, isNot(DocAlign.center));
    });
  });

  group('U5 _canMerge', () {
    LayoutLine f1([double y = 100]) => mkLine(_full, 72, y, width: fullWidth);
    test('U5-P1 2 dòng đầy ⇒ gộp', () => expect(_rb([f1(), mkLine(_full2, 72, 112, width: fullWidth)]), hasLength(1)));
    test('U5-P2 dòng sau là bullet ⇒ tách', () => expect(_rb([f1(), mkLine('• bullet item', 72, 112)]), hasLength(2)));
    test('U5-P3 khác cỡ ⇒ tách', () => expect(_rb([f1(), mkLine(_full2, 72, 112, size: 12, width: fullWidth)]), hasLength(2)));
    test('U5-P4 khác đậm ⇒ tách', () => expect(_rb([f1(), mkLine(_full2, 72, 112, bold: true, width: fullWidth)]), hasLength(2)));
    test('U5-P5 cùng top ⇒ tách', () => expect(_rb([f1(), _tall('Tall line box', 72, 100, fullWidth)]), hasLength(2)));
    test('U5-P6 khe 40 ⇒ tách', () => expect(_rb([f1(), mkLine(_full2, 72, 140, width: fullWidth)]), hasLength(2)));
    test('U5-P7 dòng ngắn không chấm ⇒ gộp', () {
      expect(_rb([mkLine('short line without stop', 72, 100, width: 200), mkLine(_full2, 72, 112, width: fullWidth)]), hasLength(1));
    });
    test('U5-P8 dòng ngắn có chấm ⇒ tách', () {
      expect(_rb([mkLine('short line with a stop.', 72, 100, width: 200), mkLine(_full2, 72, 112, width: fullWidth)]), hasLength(2));
    });
    test('U5-P9/P18 3 dòng căn giữa ⇒ 1 khối center', () {
      final b = _rb([
        mkLine('Centered title line one', 197.5, 100, width: 200),
        mkLine('Centered line two', 222.5, 112, width: 150),
        mkLine('Line three', 247.5, 124, width: 100),
      ]);
      expect(b, hasLength(1));
      expect(_para(b).align, DocAlign.center);
    });
    test('U5-P10/P11 thụt dòng đầu ⇒ gộp 3 dòng', () {
      expect(_rb([mkLine(_full, 90, 100, width: 433), f1(112), mkLine('third', 72, 124, width: 300)]), hasLength(1));
    });
    test('U5-P12 dòng 2 thụt vào ⇒ tách', () => expect(_rb([f1(), mkLine(_full2, 90, 112, width: 433)]), hasLength(2)));
    test('U5-P13 dòng 1 thụt 68 > 60 ⇒ tách', () => expect(_rb([mkLine(_full, 140, 100, width: 383), f1(112)]), hasLength(2)));
    test('U5-P14 dòng 1 thụt nhưng ngắn ⇒ tách', () => expect(_rb([mkLine('short indented', 90, 100, width: 150), f1(112)]), hasLength(2)));
    test('U5-P15 list thụt treo ⇒ gộp, là DocListItem', () {
      final b = _rb([mkLine('1. item text that is long enough to wrap the line', 72, 100, width: fullWidth), mkLine('continued item', 90, 112, width: 200)]);
      expect(b.single, isA<DocListItem>());
    });
    test('U5-P16 list ngắn thụt, dòng sau về lề ⇒ tách', () {
      expect(_rb([mkLine('• short item', 90, 100, width: 150), f1(112)]), hasLength(2));
    });
    test('U5-P17 list, dòng sau thụt 68 > 60 ⇒ tách', () {
      expect(_rb([mkLine('• item text that fills the line', 72, 100, width: fullWidth), mkLine('far', 140, 112, width: 200)]), hasLength(2));
    });
    test('U5-P19 dòng giữa rồi dòng lề trái ⇒ tách', () {
      expect(_rb([mkLine('Centered title line one', 197.5, 100, width: 200), mkLine('left aligned text', 72, 112, width: 228)]), hasLength(2));
    });
  });

  test('U6-P2 trang bắt đầu bằng bảng ⇒ khối đầu là DocTable (không đoạn rỗng)', () {
    final b = _rb([for (var r = 0; r < 3; r++) mkRow([('A$r', 72), ('B$r', 200), ('C$r', 330)], 100.0 + 14 * r)]);
    expect(b.first, isA<DocTable>());
  });

  group('U7 _toBlock', () {
    test('U7-P1 2 dòng trái ⇒ đoạn left, thụt 0, không cỡ riêng', () {
      final p = _para(_rb([mkLine(_full, 72, 100, width: 328), mkLine(_full2, 72, 112, width: 228)]));
      expect((p.align, p.indentPt, p.firstLineIndentPt), (DocAlign.left, 0, 0));
      expect(p.spans.every((s) => s.fontSizePt == null), isTrue);
    });
    test('U7-P2 cỡ 10,6 ⇒ đoạn có fontSizePt 10,6', () {
      final p = _para(_rb([mkLine(_full, 72, 100, size: 10.6, width: 328), mkLine(_full2, 72, 112.7, size: 10.6, width: 228)]));
      expect(p.spans.first.fontSizePt, closeTo(10.6, 1e-9));
    });
    test('U7-P3/P4/P5 20 / 14 / 12,5 pt ⇒ heading 1 / 2 / 3', () {
      int lv(double s) => (_rb([mkLine('Big Title', 72, 100, size: s)]).single as DocHeading).level;
      expect([lv(20), lv(14), lv(12.5)], [1, 2, 3]);
    });
    test('U7-P6 2 dòng đậm ⇒ đoạn đậm', () {
      final p = _para(_rb([mkLine('Bold paragraph line one here', 72, 100, bold: true, width: 328), mkLine('Bold line two', 72, 112, bold: true, width: 200)]));
      expect(p.spans.every((s) => s.bold), isTrue);
    });
    test('U7-P7 1 dòng đậm ngắn ⇒ heading 3', () {
      final h = _rb([mkLine('Bold Section', 72, 100, bold: true)]).single as DocHeading;
      expect(h.level, 3);
    });
    test('U7-P8 1 dòng đậm > 80 ký tự ⇒ đoạn', () {
      final long = List.filled(9, 'boldword1').join(' '); // 89 ký tự
      expect(_rb([mkLine(long, 72, 100, bold: true, width: fullWidth)]).single, isA<DocParagraph>());
    });
    test('U7-P9 bullet 2 dòng ⇒ DocListItem không thứ tự, marker •', () {
      final l = _rb([mkLine('• Bullet item text that is long enough', 72, 100, width: fullWidth), mkLine('continued here', 90, 112, width: 200)]).single as DocListItem;
      expect((l.ordered, l.marker), (false, '•'));
      expect(l.text, startsWith('Bullet'));
    });
    test('U7-P10 số 2 dòng ⇒ DocListItem có thứ tự', () {
      final l = _rb([mkLine('1. Numbered item text that is long enough', 72, 100, width: fullWidth), mkLine('continued here', 90, 112, width: 200)]).single as DocListItem;
      expect((l.ordered, l.marker), (true, '1.'));
    });
    test('U7-P11 1 dòng đậm "1. Introduction" ⇒ heading 3', () {
      final h = _rb([mkLine('1. Introduction', 72, 100, bold: true)]).single as DocHeading;
      expect((h.level, h.text), (3, '1. Introduction'));
    });
    test('U7-P13 2 dòng giữa ⇒ center', () {
      final p = _para(_rb([mkLine('Centered title line one', 197.5, 100, width: 200), mkLine('Centered line two', 222.5, 112, width: 150)]));
      expect((p.align, p.indentPt), (DocAlign.center, 0));
    });
    test('U7-P14 1 dòng trái ⇒ left, 0, 0', () {
      final p = _para(_rb([mkLine('Single left line', 72, 100, width: 200)]));
      expect((p.align, p.indentPt, p.firstLineIndentPt), (DocAlign.left, 0, 0));
    });
    test('U7-P15 1 dòng giữa ⇒ center', () {
      expect(_para(_rb([mkLine('Centered caption', 247.5, 100, width: 100)])).align, DocAlign.center);
    });
    test('U7-P16 1 dòng thụt 48 ⇒ left, indent 48', () {
      final p = _para(_rb([mkLine('Indented single line', 120, 100, width: 100)]));
      expect((p.align, p.indentPt), (DocAlign.left, 48));
    });
    test('U7-P17 1 dòng sát phải ⇒ right', () {
      expect(_para(_rb([mkLine('Right aligned date line', 300, 100, width: 223)])).align, DocAlign.right);
    });
    test('U7-P19 dòng 1 kín cột ⇒ justify, indent 0', () {
      final p = _para(_rb([mkLine(_full, 72, 100, width: fullWidth), mkLine(_full2, 72, 112, width: 200)]));
      expect((p.align, p.indentPt), (DocAlign.justify, 0));
    });
  });

  group('U8 _round', () {
    test('U8-P1 lệch 18 ⇒ 18', () => expect(_para(_rb([mkLine('Indented single line', 90, 100, width: 100)])).indentPt, 18));
    test('U8-P2 lệch 0,6 ⇒ 0', () => expect(_para(_rb([mkLine('Nearly flush line', 72.6, 100, width: 100)])).indentPt, 0));
  });

  group('U9 _spans', () {
    test('U9-P1/P3/P4 2 dòng cùng kiểu ⇒ 1 span nối bằng dấu cách', () {
      final p = _para(_rb([mkLine(_full, 72, 100, width: 328), mkLine(_full2, 72, 112, width: 228)]));
      expect(p.spans, hasLength(1));
      expect(p.text, '$_full $_full2');
    });
    test('U9-P2 dòng có words nhưng text rỗng ⇒ chữ của words vẫn có trong kết quả', () {
      const l = LayoutLine(
        pageIndex: 0,
        text: '',
        bounds: LayoutRect(left: 72, top: 300, width: 30, height: 10),
        fontSize: 10,
        words: [LayoutWord(text: 'Hello', bounds: LayoutRect(left: 72, top: 300, width: 30, height: 10), fontSize: 10)],
      );
      final b = _rb([l]);
      expect(b.map(blockText).join('|'), contains('Hello'));
    });
    test('U9-P5 đậm xen thường ⇒ 2 span', () {
      const line = LayoutLine(
        pageIndex: 0,
        text: 'Note: read this',
        bounds: LayoutRect(left: 72, top: 100, width: 100, height: 10),
        fontSize: 10,
        words: [
          LayoutWord(text: 'Note:', bounds: LayoutRect(left: 72, top: 100, width: 25, height: 10), fontSize: 10, bold: true),
          LayoutWord(text: 'read', bounds: LayoutRect(left: 100, top: 100, width: 20, height: 10), fontSize: 10),
          LayoutWord(text: 'this', bounds: LayoutRect(left: 123, top: 100, width: 20, height: 10), fontSize: 10),
        ],
      );
      final p = _para(_rb([line]));
      expect(p.spans.map((s) => s.bold), [true, false]);
      expect(p.text, 'Note: read this');
    });
  });

  group('U10 _dropPrefix', () {
    test('U10-P1 "• item" ⇒ spans "item"', () {
      final l = _rb([mkLine('• item', 72, 100)]).single as DocListItem;
      expect(l.spans.map((s) => s.text), ['item']);
    });
    test('U10-P2 "• Hello" thường + "World" đậm ⇒ ["Hello ", "World"(đậm)]', () {
      const line = LayoutLine(
        pageIndex: 0,
        text: '• Hello World',
        bounds: LayoutRect(left: 72, top: 100, width: 80, height: 10),
        fontSize: 10,
        words: [
          LayoutWord(text: '•', bounds: LayoutRect(left: 72, top: 100, width: 5, height: 10), fontSize: 10),
          LayoutWord(text: 'Hello', bounds: LayoutRect(left: 80, top: 100, width: 25, height: 10), fontSize: 10),
          LayoutWord(text: 'World', bounds: LayoutRect(left: 108, top: 100, width: 25, height: 10), fontSize: 10, bold: true),
        ],
      );
      final l = _rb([line]).single as DocListItem;
      expect(l.spans.map((s) => (s.text, s.bold)), [('Hello ', false), ('World', true)]);
    });
    test('U10-P3 "•" đậm + "item" thường ⇒ chỉ ["item"]', () {
      const line = LayoutLine(
        pageIndex: 0,
        text: '• item',
        bounds: LayoutRect(left: 72, top: 100, width: 30, height: 10),
        fontSize: 10,
        words: [
          LayoutWord(text: '•', bounds: LayoutRect(left: 72, top: 100, width: 5, height: 10), fontSize: 10, bold: true),
          LayoutWord(text: 'item', bounds: LayoutRect(left: 80, top: 100, width: 20, height: 10), fontSize: 10),
        ],
      );
      final l = _rb([line]).single as DocListItem;
      expect(l.spans.map((s) => (s.text, s.bold)), [('item', false)]);
    });
  });
}
