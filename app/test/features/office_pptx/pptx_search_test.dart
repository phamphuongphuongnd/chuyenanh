import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/office_pptx/pptx_search.dart';
import 'package:pptx_reader/pptx_reader.dart';

PptxTextShape _t(String t) => PptxTextShape(
  frame: const PptxRect(0, 0, 100, 100),
  paragraphs: [
    PptxParagraph(runs: [PptxRun(text: t)]),
  ],
);

PptxSlide _s(int i, List<PptxShape> shapes, {String? notes, bool hidden = false}) =>
    PptxSlide(
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
      PptxGroupShape(frame: const PptxRect(0, 0, 100, 100), children: [_t('chao chao')]),
    ]),
    _s(2, [_t('an chao')], hidden: true),
    _s(3, [
      PptxTableShape(
        frame: const PptxRect(0, 0, 100, 100),
        columnWidthsEmu: const [50],
        rows: const [
          PptxTableRow(heightEmu: 10, cells: [
            PptxTableCell(paragraphs: [
              PptxParagraph(runs: [PptxRun(text: 'CHAO')]),
            ]),
          ]),
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
}
