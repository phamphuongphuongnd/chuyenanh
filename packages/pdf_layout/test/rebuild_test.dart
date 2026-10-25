import 'dart:isolate';

import 'package:pdf_layout/pdf_layout.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('paragraphs', () {
    test('joins wrapped lines and splits on paragraph spacing', () {
      final page = mkPage([
        mkLine(
          'The quick brown fox jumps over',
          marginL,
          100,
          width: fullWidth,
        ),
        mkLine(
          'the lazy dog and keeps running',
          marginL,
          112,
          width: fullWidth,
        ),
        mkLine('until the end.', marginL, 124, width: 120),
        mkLine(
          'Second paragraph starts here and',
          marginL,
          148,
          width: fullWidth,
        ),
        mkLine('finishes on this line.', marginL, 160, width: 200),
      ]);
      final blocks = rebuildDocument([page]);
      expect(blocks, hasLength(2));
      expect(blocks.every((b) => b is DocParagraph), isTrue);
      expect(
        blockText(blocks[0]),
        'The quick brown fox jumps over the lazy dog and keeps running '
        'until the end.',
      );
      expect(
        blockText(blocks[1]),
        'Second paragraph starts here and finishes on this line.',
      );
    });

    test('1.5 line spacing still joins lines (adaptive pitch)', () {
      const pitch = 20.7, s = 12.0;
      final page = mkPage([
        for (var i = 0; i < 4; i++)
          mkLine(
            'First paragraph line $i of text',
            marginL,
            100 + i * pitch,
            size: s,
            width: fullWidth,
          ),
        mkLine(
          'Second paragraph line',
          marginL,
          100 + 3 * pitch + 30,
          size: s,
          width: fullWidth,
        ),
        mkLine('ends here.', marginL, 100 + 4 * pitch + 30, size: s),
      ]);
      final blocks = rebuildDocument([page]);
      expect(blocks.map(blockText).toList(), [
        'First paragraph line 0 of text First paragraph line 1 of text '
            'First paragraph line 2 of text First paragraph line 3 of text',
        'Second paragraph line ends here.',
      ]);
    });

    test('short line ending with a period ends the paragraph', () {
      final page = mkPage([
        mkLine(
          'First paragraph has a full line of',
          marginL,
          100,
          width: fullWidth,
        ),
        mkLine('text that ends early.', marginL, 112, width: 150),
        mkLine(
          'Next paragraph without extra spacing',
          marginL,
          124,
          width: fullWidth,
        ),
        mkLine('continues here', marginL, 136, width: 120),
      ]);
      final blocks = rebuildDocument([page]);
      expect(blocks.map(blockText).toList(), [
        'First paragraph has a full line of text that ends early.',
        'Next paragraph without extra spacing continues here',
      ]);
    });

    test('first-line indent starts a new paragraph and keeps indent', () {
      final page = mkPage([
        mkLine('Indented opening line of the first', 100, 100, width: 423),
        mkLine(
          'paragraph continues at the margin',
          marginL,
          112,
          width: fullWidth,
        ),
        mkLine('and wraps once more', marginL, 124, width: 300),
        mkLine('Second paragraph is indented too', 100, 136, width: 423),
        mkLine('and ends here.', marginL, 148, width: 100),
      ]);
      final blocks = rebuildDocument([page]);
      expect(blocks, hasLength(2));
      final p = blocks[0] as DocParagraph;
      expect(
        p.text,
        startsWith('Indented opening line of the first paragraph'),
      );
      expect(p.firstLineIndentPt, closeTo(28, 0.6));
      expect(p.indentPt, closeTo(0, 0.6));
    });

    test('removes hyphen before lowercase Latin, keeps it otherwise', () {
      final page = mkPage([
        mkLine(
          'This sentence contains an infor-',
          marginL,
          100,
          width: fullWidth,
        ),
        mkLine('mation word and a well-', marginL, 112, width: fullWidth),
        mkLine('Known name plus đường-', marginL, 124, width: fullWidth),
        mkLine('ững tiếng Việt.', marginL, 136, width: 100),
      ]);
      final blocks = rebuildDocument([page]);
      expect(blocks, hasLength(1));
      expect(
        blockText(blocks.single),
        'This sentence contains an information word and a well- Known name '
        'plus đườngững tiếng Việt.',
      );
    });

    test('CJK and Thai lines are joined without spaces', () {
      final page = mkPage([
        mkLine(
          '这是第一行文字这是第一行文字',
          marginL,
          100,
          width: fullWidth,
          splitWords: false,
        ),
        mkLine('第二行', marginL, 112, width: 30, splitWords: false),
        mkLine(
          'ภาษาไทยบรรทัดแรกยาวมาก',
          marginL,
          140,
          width: fullWidth,
          splitWords: false,
        ),
        mkLine('บรรทัดที่สอง', marginL, 152, width: 60, splitWords: false),
      ]);
      final blocks = rebuildDocument([page]);
      expect(blocks.map(blockText).toList(), [
        '这是第一行文字这是第一行文字第二行',
        'ภาษาไทยบรรทัดแรกยาวมากบรรทัดที่สอง',
      ]);
    });

    test('centered line is detected', () {
      final page = mkPage([
        mkLine('Centered caption', 247.5, 100, width: 100),
        mkLine(
          'Body text that fills the full line',
          marginL,
          124,
          width: fullWidth,
        ),
        mkLine('and ends.', marginL, 136, width: 60),
      ]);
      final blocks = rebuildDocument([page]);
      expect((blocks[0] as DocParagraph).align, DocAlign.center);
      expect((blocks[1] as DocParagraph).align, isNot(DocAlign.center));
    });

    test('mixed bold words become separate spans', () {
      final line = LayoutLine(
        pageIndex: 0,
        text: 'Note: read this.',
        bounds: const LayoutRect(left: 72, top: 100, width: 100, height: 10),
        fontSize: 10,
        words: const [
          LayoutWord(
            text: 'Note:',
            bounds: LayoutRect(left: 72, top: 100, width: 25, height: 10),
            fontSize: 10,
            bold: true,
          ),
          LayoutWord(
            text: 'read',
            bounds: LayoutRect(left: 100, top: 100, width: 20, height: 10),
            fontSize: 10,
          ),
          LayoutWord(
            text: 'this.',
            bounds: LayoutRect(left: 123, top: 100, width: 25, height: 10),
            fontSize: 10,
          ),
        ],
      );
      final blocks = rebuildDocument([
        mkPage([line]),
      ]);
      final p = blocks.single as DocParagraph;
      expect(p.spans.first.bold, isTrue);
      expect(p.spans.first.text.trim(), 'Note:');
      expect(p.spans.last.bold, isFalse);
      expect(p.text, 'Note: read this.');
    });
  });

  group('headings', () {
    test('levels follow font size relative to the median', () {
      final body = <LayoutLine>[];
      var y = 200.0;
      for (var i = 0; i < 6; i++) {
        body.add(
          mkLine(
            'Body line number $i with enough text here',
            marginL,
            y,
            width: fullWidth,
          ),
        );
        y += 12;
      }
      body.add(mkLine('Last body line.', marginL, y, width: 100));
      final page = mkPage([
        mkLine('Big Title', marginL, 60, size: 20),
        mkLine('Section', marginL, 100, size: 14),
        mkLine('Subsection', marginL, 130, size: 12.5),
        mkLine('Bold run-in title', marginL, 160, bold: true),
        ...body,
      ]);
      final blocks = rebuildDocument([page]);
      final headings = blocks.whereType<DocHeading>().toList();
      expect(headings.map((h) => (h.level, h.text)).toList(), [
        (1, 'Big Title'),
        (2, 'Section'),
        (3, 'Subsection'),
        (3, 'Bold run-in title'),
      ]);
      expect(blocks.whereType<DocParagraph>(), hasLength(1));
    });

    test('a two-line title of the same large size is one heading', () {
      final page = mkPage([
        mkLine('A long document title that', marginL, 60, size: 20),
        mkLine('wraps onto two lines', marginL, 84, size: 20),
        mkLine(
          'Body text that fills the full line',
          marginL,
          130,
          width: fullWidth,
        ),
        mkLine(
          'and the second body line is here',
          marginL,
          142,
          width: fullWidth,
        ),
        mkLine('and ends.', marginL, 154, width: 60),
      ]);
      final blocks = rebuildDocument([page]);
      final h = blocks.first as DocHeading;
      expect(h.level, 1);
      expect(h.text, 'A long document title that wraps onto two lines');
    });
  });

  group('lists', () {
    test('recognises bullet, numbered and lettered markers', () {
      final page = mkPage([
        mkLine('• Apples', marginL, 100),
        mkLine('- Pears', marginL, 112),
        mkLine('* Plums', marginL, 124),
        mkLine('– Figs', marginL, 136),
        mkLine('1. First step', marginL, 160),
        mkLine('2) Second step', marginL, 172),
        mkLine('a. alpha', marginL, 196),
        mkLine('b) beta', marginL, 208),
      ]);
      final items = rebuildDocument([page]).cast<DocListItem>();
      expect(items.map((i) => (i.ordered, i.marker, i.text)).toList(), [
        (false, '•', 'Apples'),
        (false, '-', 'Pears'),
        (false, '*', 'Plums'),
        (false, '–', 'Figs'),
        (true, '1.', 'First step'),
        (true, '2)', 'Second step'),
        (true, 'a.', 'alpha'),
        (true, 'b)', 'beta'),
      ]);
    });

    test('numbered list with a tab after the marker is not a table', () {
      final page = mkPage([
        mkRow([('1.', 72), ('Prepare the data', 100)], 100),
        mkRow([('2.', 72), ('Run the import', 100)], 112),
        mkRow([('3.', 72), ('Check the result', 100)], 124),
      ]);
      final blocks = rebuildDocument([page]);
      expect(blocks.whereType<DocTable>(), isEmpty);
      expect(blocks.cast<DocListItem>().map((i) => i.text).toList(), [
        'Prepare the data',
        'Run the import',
        'Check the result',
      ]);
    });

    test('hanging continuation line joins the list item', () {
      final page = mkPage([
        mkLine(
          '1. A long list item that wraps onto',
          marginL,
          100,
          width: fullWidth,
        ),
        mkLine('the next line with hanging indent', 86, 112, width: 300),
        mkLine('2. Short item', marginL, 124),
      ]);
      final items = rebuildDocument([page]).cast<DocListItem>().toList();
      expect(items, hasLength(2));
      expect(
        items[0].text,
        'A long list item that wraps onto the next line with hanging indent',
      );
    });
  });

  group('header and footer', () {
    test('repeated header/footer (with page numbers) are removed', () {
      final pages = <LayoutPage>[];
      for (var p = 0; p < 3; p++) {
        pages.add(
          LayoutPage(
            index: p,
            width: pageW,
            height: pageH,
            lines: [
              mkLine('ACME Quarterly Report', marginL, 30, page: p),
              mkLine('Body of page ${p + 1} is here.', marginL, 300, page: p),
              if (p == 0) mkLine('Only on first page', marginL, 805, page: p),
              mkLine('Page ${p + 1} of 3', 270, 810 + p * 1.0, page: p),
            ],
          ),
        );
      }
      final blocks = rebuildDocument(pages);
      final texts = blocks.map(blockText).toList();
      expect(texts.where((t) => t.contains('ACME')), isEmpty);
      expect(texts.where((t) => t.startsWith('Page ')), isEmpty);
      expect(texts, contains('Only on first page'));
      expect(texts.where((t) => t.startsWith('Body of page')), hasLength(3));
      expect(blocks.whereType<DocPageBreak>(), hasLength(2));
    });

    test('single page keeps everything', () {
      final blocks = rebuildDocument([
        mkPage([
          mkLine('ACME Quarterly Report', marginL, 30),
          mkLine('Page 1 of 1', 270, 810),
        ]),
      ]);
      expect(blocks.map(blockText), contains('ACME Quarterly Report'));
    });
  });

  group('two columns', () {
    List<LayoutLine> columnPage({required bool merged}) {
      final lines = <LayoutLine>[
        mkLine('Two Column Article', 200, 50, size: 20),
      ];
      const leftX = 72.0, rightX = 310.0, colW = 213.0;
      for (var i = 0; i < 40; i++) {
        final y = 100.0 + i * 12;
        final last = i == 39;
        final lt = last ? 'left end.' : 'left words row $i';
        final rt = last ? 'right end.' : 'right words row $i';
        final l = mkLine(lt, leftX, y, width: last ? 50 : colW);
        final r = mkLine(rt, rightX, y, width: last ? 50 : colW);
        if (merged) {
          lines.add(
            LayoutLine(
              pageIndex: 0,
              text: '$lt $rt',
              bounds: LayoutRect(
                left: leftX,
                top: y,
                width: rightX + (last ? 50 : colW) - leftX,
                height: 10,
              ),
              fontSize: 10,
              words: [...l.words, ...r.words],
            ),
          );
        } else {
          lines
            ..add(l)
            ..add(r);
        }
      }
      return lines;
    }

    for (final merged in [false, true]) {
      test('reads left column before right column (merged=$merged)', () {
        final blocks = rebuildDocument([mkPage(columnPage(merged: merged))]);
        expect(blocks.first, isA<DocHeading>());
        final text = blocks.skip(1).map(blockText).join('\n');
        expect(blocks.skip(1).whereType<DocTable>(), isEmpty);
        final lastLeft = text.lastIndexOf('left');
        final firstRight = text.indexOf('right');
        expect(lastLeft, greaterThan(0));
        expect(firstRight, greaterThan(lastLeft));
        expect(blocks.skip(1).whereType<DocParagraph>(), hasLength(2));
      });
    }
  });

  test('runs inside Isolate.run', () async {
    final pages = [
      mkPage([
        mkLine('Title', marginL, 60, size: 20),
        mkLine('Body.', marginL, 100),
      ]),
    ];
    final blocks = await Isolate.run(() => rebuildDocument(pages));
    expect(blocks.map(blockText).toList(), ['Title', 'Body.']);
    final bytes = await Isolate.run(() => writeDocx(blocks));
    expect(bytes, isNotEmpty);
  });

  group('tables in documents', () {
    test('table rows become a DocTable between paragraphs', () {
      final page = mkPage([
        mkLine('Sales summary', marginL, 100),
        mkRow([('Name', 72), ('Qty', 250), ('Price', 400)], 130),
        mkRow([('Apple', 72), ('3', 250), ('1.50', 400)], 144),
        mkRow([('Banana', 72), ('2.00', 400)], 158),
        mkRow([('New York', 72), ('7', 250), ('3.25', 400)], 172),
        mkLine('Prices include tax.', marginL, 200),
      ]);
      final blocks = rebuildDocument([page]);
      expect(blocks.map((b) => b.runtimeType).toList(), [
        DocParagraph,
        DocTable,
        DocParagraph,
      ]);
      expect((blocks[1] as DocTable).cells, [
        ['Name', 'Qty', 'Price'],
        ['Apple', '3', '1.50'],
        ['Banana', '', '2.00'],
        ['New York', '7', '3.25'],
      ]);
    });
  });
}
