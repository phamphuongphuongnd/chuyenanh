import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/office_pptx/pptx_search.dart';
import 'package:pptx_reader/pptx_reader.dart';

PptxTextShape _t(String t) => PptxTextShape(
  frame: const PptxRect(0, 0, 100, 100),
  paragraphs: [
    PptxParagraph(runs: [PptxRun(text: t)]),
  ],
);

PptxSlide _s(
  int i,
  List<PptxShape> shapes, {
  String? notes,
  bool hidden = false,
}) => PptxSlide(
  index: i,
  background: null,
  shapes: shapes,
  notesText: notes,
  hidden: hidden,
);

PptxDeck _deck() => PptxDeck(
  slideWidthEmu: 9144000,
  slideHeightEmu: 5143500,
  slides: [
    _s(0, [_t('Xin Chao')], notes: 'chao ban'),
    _s(1, [
      PptxGroupShape(
        frame: const PptxRect(0, 0, 100, 100),
        children: [_t('chao chao')],
      ),
    ]),
    _s(2, [_t('an chao')], hidden: true),
    _s(3, [
      PptxTableShape(
        frame: const PptxRect(0, 0, 100, 100),
        columnWidthsEmu: const [50],
        rows: const [
          PptxTableRow(
            heightEmu: 10,
            cells: [
              PptxTableCell(
                paragraphs: [
                  PptxParagraph(runs: [PptxRun(text: 'CHAO')]),
                ],
              ),
            ],
          ),
        ],
      ),
    ]),
  ],
);

void main() {
  test('tìm không phân biệt hoa thường, đếm từng lần, trong nhóm và bảng', () {
    final hits = findPptxHits(_deck(), [0, 1, 3], 'ChAo');
    expect(hits.map((h) => h.page).toList(), [0, 1, 1, 2]);
    expect(hits.map((h) => h.slideIndex).toList(), [0, 1, 1, 3]);
  });

  test('chỉ tìm trong slide đang hiển thị', () {
    expect(findPptxHits(_deck(), [0, 1, 3], 'an chao'), isEmpty);
    final all = findPptxHits(_deck(), [0, 1, 2, 3], 'an chao');
    expect(all.single.slideIndex, 2);
    expect(all.single.page, 2);
  });

  test('ghi chú chỉ tìm khi bật includeNotes', () {
    expect(findPptxHits(_deck(), [0], 'ban'), isEmpty);
    final h = findPptxHits(_deck(), [0], 'ban', includeNotes: true);
    expect(h.single.inNotes, isTrue);
  });

  test('truy vấn rỗng hoặc không khớp trả danh sách rỗng', () {
    expect(findPptxHits(_deck(), [0, 1], '  '), isEmpty);
    expect(findPptxHits(_deck(), [0, 1], 'zzz'), isEmpty);
  });

  test('indexPptxParagraphs + currentOccurrenceInSlide: thứ tự kết quả trong slide', () {
    final deck = _deck();
    final hits = findPptxHits(deck, [0, 1, 3], 'chao');
    // slide 1 có 2 kết quả ('chao chao') trong nhóm.
    expect(hits.map((h) => h.slideIndex).toList(), [0, 1, 1, 3]);
    expect(currentOccurrenceInSlide(hits, 0), 0);
    expect(currentOccurrenceInSlide(hits, 1), 0);
    expect(currentOccurrenceInSlide(hits, 2), 1);
    expect(currentOccurrenceInSlide(hits, 3), 0);
    expect(currentOccurrenceInSlide(hits, 9), -1);

    final index = indexPptxParagraphs(deck, [0, 1, 3], 'chao');
    final group = deck.slides[1].shapes.single as PptxGroupShape;
    final para = (group.children.single as PptxTextShape).paragraphs.single;
    expect(index[para]?.slideIndex, 1);
    expect(index[para]?.firstOccurrence, 0);
    // Slide ẩn không có trong bảng tra.
    final hidden =
        (deck.slides[2].shapes.single as PptxTextShape).paragraphs.single;
    expect(index.containsKey(hidden), isFalse);
  });

  test('findMatchRanges: không chồng lấn, theo vị trí', () {
    expect(findMatchRanges('aaaa', 'aa'), [(0, 2), (2, 4)]);
    expect(findMatchRanges('xyz', 'q'), isEmpty);
    expect(findMatchRanges('xyz', ''), isEmpty);
  });
}
