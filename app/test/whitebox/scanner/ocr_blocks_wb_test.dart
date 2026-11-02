// Kiểm thử hộp trắng A07 — scanner/ocr/ocr_blocks.dart (Bước 6).
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_layout/pdf_layout.dart';
import 'package:pdf_office/engines/ocr/ocr_engine.dart';
import 'package:pdf_office/features/scanner/ocr/ocr_blocks.dart';

OcrLine _l(String t, {double h = 20, double top = 0}) => OcrLine(t, Rect.fromLTWH(0, top, 100, h));
OcrBlock _b(List<OcrLine> lines, {String? text}) =>
    OcrBlock(text ?? lines.map((l) => l.text).join('\n'), Rect.zero, lines);
OcrResult _p(List<OcrBlock> blocks) =>
    OcrResult(text: blocks.map((b) => b.text).join('\n\n'), blocks: blocks);

/// Trang có 1 block cần xét + 2 block thân bài cao 20 (trung vị 20).
List<DocBlock> _withBody(OcrBlock probe) => ocrPagesToDocBlocks([
      _p([
        probe,
        _b([_l('thân một', top: 100)]),
        _b([_l('thân hai', top: 130)]),
      ]),
    ]);

void main() {
  group('U1 joinOcrLines', () {
    test('U1-B1 hai dòng Latin ⇒ nối bằng dấu cách', () => expect(joinOcrLines(['a', 'b']), 'a b'));
    test('U1-B2 không có dòng ⇒ rỗng', () => expect(joinOcrLines([]), ''));
    test('U1-B3 dòng rỗng bị bỏ', () => expect(joinOcrLines(['  ', 'b']), 'b'));
    test('U1-B5 dòng trước kết thúc bằng chữ Hán ⇒ nối liền', () => expect(joinOcrLines(['这', 'b']), '这b'));
    test('U1-B6 dòng sau bắt đầu bằng kana ⇒ nối liền', () => expect(joinOcrLines(['a', 'せかい']), 'aせかい'));
    test('U1-X1 Hangul nửa độ rộng (U+FFA1) ⇒ vẫn có dấu cách (comment: KHÔNG gồm Hangul)', () {
      expect(joinOcrLines(['ﾡ', 'b']), 'ﾡ b');
    });
  });

  group('U2 ocrPagesToDocBlocks', () {
    test('U2-B1 một trang ⇒ không ngắt trang', () {
      final r = ocrPagesToDocBlocks([_p([_b([_l('A')])])]);
      expect(r.whereType<DocPageBreak>(), isEmpty);
      expect(r, hasLength(1));
    });
    test('U2-B2 không trang ⇒ rỗng', () => expect(ocrPagesToDocBlocks([]), isEmpty));
    test('U2-B3 hai trang ⇒ 1 ngắt trang ở giữa', () {
      final r = ocrPagesToDocBlocks([_p([_b([_l('A')])]), _p([_b([_l('B')])])]);
      expect(r.map((b) => b.runtimeType).toList(), [DocParagraph, DocPageBreak, DocParagraph]);
    });
  });

  group('U3 _pageBlocks', () {
    test('U3-B1 chữ đồng đều ⇒ đoạn văn', () {
      final r = ocrPagesToDocBlocks([_p([_b([_l('một'), _l('hai', top: 22)])])]);
      expect((r.single as DocParagraph).text, 'một hai');
    });
    test('U3-B2 không dòng nào cao > 0 ⇒ trung vị 0, không tiêu đề', () {
      final r = ocrPagesToDocBlocks([_p([_b([_l('TO', h: 0)])])]);
      expect(r.single, isA<DocParagraph>());
    });
    test('U3-B3 trang không block ⇒ rỗng', () => expect(ocrPagesToDocBlocks([OcrResult.empty]), isEmpty));
    test('U3-B4 block không có dòng ⇒ tách text theo xuống dòng', () {
      final r = _withBody(const OcrBlock('một\nhai', Rect.zero, []));
      expect((r.first as DocParagraph).text, 'một hai');
    });
    test('U3-B5 block chữ rỗng ⇒ bỏ', () {
      final r = _withBody(_b([_l('  ')]));
      expect(r, hasLength(2));
    });
    test('U3-B6 block chữ to ⇒ tiêu đề in đậm', () {
      final r = _withBody(_b([_l('TIÊU ĐỀ', h: 40)]));
      expect(r.first, isA<DocHeading>());
      expect((r.first as DocHeading).text, 'TIÊU ĐỀ');
    });
  });

  group('U4 _headingLevel', () {
    test('U4-B1 cao 2× trung vị, 1 dòng ngắn ⇒ tiêu đề', () {
      expect(_withBody(_b([_l('LỚN', h: 40)])).first, isA<DocHeading>());
    });
    test('U4-B2 trung vị 0 ⇒ không tiêu đề', () {
      final r = ocrPagesToDocBlocks([_p([_b([_l('A', h: 0)]), _b([_l('B', h: -5)])])]);
      expect(r.every((b) => b is DocParagraph), isTrue);
    });
    test('U4-B3 block không dòng ⇒ không tiêu đề', () {
      expect(_withBody(const OcrBlock('TO', Rect.zero, [])).first, isA<DocParagraph>());
    });
    test('U4-B4 ba dòng ⇒ không tiêu đề', () {
      expect(_withBody(_b([_l('A', h: 40), _l('B', h: 40), _l('C', h: 40)])).first, isA<DocParagraph>());
    });
    test('U4-B5 chữ dài ⇒ không tiêu đề', () {
      final long = 'x' * 300;
      expect(_withBody(_b([_l(long, h: 40)])).first, isA<DocParagraph>());
    });
    test('U4-B6 cao 1,5× trung vị ⇒ tiêu đề', () {
      expect(_withBody(_b([_l('VỪA', h: 30)])).first, isA<DocHeading>());
    });
    test('U4-B7 cao 1× trung vị ⇒ đoạn văn', () {
      expect(_withBody(_b([_l('thường', h: 20)])).first, isA<DocParagraph>());
    });
  });
}
