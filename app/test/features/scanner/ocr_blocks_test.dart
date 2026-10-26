import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_layout/pdf_layout.dart';
import 'package:pdf_office/engines/ocr/ocr_engine.dart';
import 'package:pdf_office/features/scanner/ocr/ocr_blocks.dart';

OcrLine line(String t, {double top = 0, double h = 20}) =>
    OcrLine(t, Rect.fromLTWH(0, top, 100, h));

OcrBlock block(List<OcrLine> lines) => OcrBlock(
  lines.map((l) => l.text).join('\n'),
  lines.fold<Rect>(lines.first.bounds, (r, l) => r.expandToInclude(l.bounds)),
  lines,
);

OcrResult page(List<OcrBlock> blocks) =>
    OcrResult(text: blocks.map((b) => b.text).join('\n\n'), blocks: blocks);

void main() {
  group('joinOcrLines', () {
    test('nối dòng Latin bằng dấu cách', () {
      expect(joinOcrLines(['Xin chào', 'các bạn']), 'Xin chào các bạn');
    });

    test('giữ dấu tiếng Việt chồng nguyên vẹn', () {
      expect(joinOcrLines(['Nguyễn Thị', 'Hoàng Ngữ']), 'Nguyễn Thị Hoàng Ngữ');
    });

    test('Trung/Nhật nối liền không dấu cách', () {
      expect(joinOcrLines(['这是第一行', '这是第二行']), '这是第一行这是第二行');
      expect(joinOcrLines(['こんにちは', 'せかい']), 'こんにちはせかい');
    });

    test('Hàn vẫn có dấu cách giữa các dòng', () {
      expect(joinOcrLines(['안녕하세요', '여러분']), '안녕하세요 여러분');
    });

    test('bỏ dòng rỗng và cắt khoảng trắng', () {
      expect(joinOcrLines(['  a ', '', ' b']), 'a b');
      expect(joinOcrLines([]), '');
    });
  });

  group('ocrPagesToDocBlocks', () {
    test('không có trang → rỗng', () {
      expect(ocrPagesToDocBlocks([]), isEmpty);
    });

    test('mỗi block thành một đoạn, dòng trong block được nối', () {
      final blocks = ocrPagesToDocBlocks([
        page([
          block([line('Dòng một'), line('dòng hai', top: 22)]),
          block([line('Đoạn ba', top: 80)]),
        ]),
      ]);
      expect(blocks, hasLength(2));
      expect(blocks[0], isA<DocParagraph>());
      expect((blocks[0] as DocParagraph).text, 'Dòng một dòng hai');
      expect((blocks[1] as DocParagraph).text, 'Đoạn ba');
    });

    test('ngắt trang giữa các trang, kể cả trang trống', () {
      final blocks = ocrPagesToDocBlocks([
        page([
          block([line('A')]),
        ]),
        OcrResult.empty,
        page([
          block([line('C')]),
        ]),
      ]);
      expect(blocks.map((b) => b.runtimeType).toList(), [
        DocParagraph,
        DocPageBreak,
        DocPageBreak,
        DocParagraph,
      ]);
    });

    test('block chữ to hơn hẳn mặt bằng → tiêu đề', () {
      final blocks = ocrPagesToDocBlocks([
        page([
          block([line('TIÊU ĐỀ', h: 44)]),
          block([line('thân bài một', top: 60), line('thân bài hai', top: 82)]),
          block([line('thân bài ba', top: 120)]),
          block([line('thân bài bốn', top: 142)]),
        ]),
      ]);
      expect(blocks.first, isA<DocHeading>());
      expect((blocks.first as DocHeading).text, 'TIÊU ĐỀ');
      expect(blocks.skip(1).every((b) => b is DocParagraph), isTrue);
    });

    test('chữ đồng đều → không có tiêu đề nào', () {
      final blocks = ocrPagesToDocBlocks([
        page([
          block([line('một')]),
          block([line('hai', top: 30)]),
        ]),
      ]);
      expect(blocks.every((b) => b is DocParagraph), isTrue);
    });

    test('block không có dòng nhưng có text → tách theo xuống dòng', () {
      final blocks = ocrPagesToDocBlocks([
        const OcrResult(
          text: 'x',
          blocks: [OcrBlock('một\nhai', Rect.fromLTWH(0, 0, 10, 10), [])],
        ),
      ]);
      expect((blocks.single as DocParagraph).text, 'một hai');
    });

    test('kết quả ghi được thành docx', () {
      final bytes = writeDocx(
        ocrPagesToDocBlocks([
          page([
            block([line('Xin chào')]),
          ]),
        ]),
      );
      expect(bytes.sublist(0, 2), [0x50, 0x4b]); // "PK"
    });
  });

  group('ocrPagesToText', () {
    test('nối các trang bằng dòng trống, bỏ trang rỗng', () {
      final text = ocrPagesToText([
        const OcrResult(text: 'Trang 1\n', blocks: []),
        OcrResult.empty,
        const OcrResult(text: ' Trang 3', blocks: []),
      ]);
      expect(text, 'Trang 1\n\nTrang 3');
    });

    test('tất cả rỗng → chuỗi rỗng', () {
      expect(ocrPagesToText([OcrResult.empty]), '');
    });
  });
}
