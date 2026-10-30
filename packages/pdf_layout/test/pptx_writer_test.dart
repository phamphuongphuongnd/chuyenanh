import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pdf_layout/pdf_layout.dart';
import 'package:pptx_reader/pptx_reader.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

/// "Ảnh" giả: chỉ cần bytes khác nhau, writer không giải mã ảnh.
Uint8List _fakeJpeg(int seed) => Uint8List.fromList([
  0xFF, 0xD8, 0xFF, 0xE0, seed, seed + 1, seed + 2, 0xFF, 0xD9, //
]);

void main() {
  group('writeImagePptx', () {
    final img1 = _fakeJpeg(1);
    final img2 = _fakeJpeg(7);
    late Uint8List bytes;

    setUpAll(() {
      bytes = writeImagePptx(
        [
          PptxImageSlide(bytes: img1, widthPt: 595, heightPt: 842), // A4 dọc
          PptxImageSlide(bytes: img2, widthPt: 842, heightPt: 595), // A4 ngang
        ],
        slideWidthPt: 595,
        slideHeightPt: 842,
        title: 'Báo cáo <1> & "2"',
        created: DateTime.utc(2026, 1, 2, 3, 4, 5),
      );
    });

    test('là zip, đọc lại bằng readPptx thấy 2 slide, đúng cỡ, có ảnh', () {
      expect(bytes.sublist(0, 2), [0x50, 0x4B]); // "PK"
      final deck = readPptx(bytes);
      expect(deck.slides, hasLength(2));
      expect(deck.slideWidthEmu, 595 * 12700);
      expect(deck.slideHeightEmu, 842 * 12700);

      final pics1 = deck.slides[0].shapes.whereType<PptxPictureShape>().toList();
      expect(pics1, hasLength(1));
      expect(pics1.single.bytes, img1);
      expect(pics1.single.extension, 'jpg');
      // Trang 1 cùng cỡ slide → phủ kín.
      expect(pics1.single.frame, PptxRect(0, 0, 595 * 12700, 842 * 12700));

      final pics2 = deck.slides[1].shapes.whereType<PptxPictureShape>().toList();
      expect(pics2, hasLength(1));
      expect(pics2.single.bytes, img2);
      // Trang ngang trên slide dọc → rộng bằng slide, nằm giữa theo chiều dọc.
      final f = pics2.single.frame;
      expect(f.x, 0);
      expect(f.cx, 595 * 12700);
      expect(f.cy, closeTo(595 * 12700 * 595 / 842, 2));
      expect(f.y, closeTo((842 * 12700 - f.cy) / 2, 1));
    });

    test('đủ part chuẩn, XML hợp lệ, content type khớp', () {
      final zip = ZipDecoder().decodeBytes(bytes);
      final names = zip.files.map((f) => f.name).toSet();
      expect(zip.files.first.name, '[Content_Types].xml');
      for (final part in [
        '[Content_Types].xml',
        '_rels/.rels',
        'docProps/core.xml',
        'docProps/app.xml',
        'ppt/presentation.xml',
        'ppt/_rels/presentation.xml.rels',
        'ppt/presProps.xml',
        'ppt/viewProps.xml',
        'ppt/tableStyles.xml',
        'ppt/theme/theme1.xml',
        'ppt/slideMasters/slideMaster1.xml',
        'ppt/slideMasters/_rels/slideMaster1.xml.rels',
        'ppt/slideLayouts/slideLayout1.xml',
        'ppt/slideLayouts/_rels/slideLayout1.xml.rels',
        'ppt/slides/slide1.xml',
        'ppt/slides/_rels/slide1.xml.rels',
        'ppt/slides/slide2.xml',
        'ppt/slides/_rels/slide2.xml.rels',
        'ppt/media/image1.jpg',
        'ppt/media/image2.jpg',
      ]) {
        expect(names, contains(part));
      }
      // Mọi part XML phải parse được.
      for (final f in zip.files) {
        if (f.name.endsWith('.xml') || f.name.endsWith('.rels')) {
          expect(
            () => XmlDocument.parse(utf8.decode(f.content)),
            returnsNormally,
            reason: f.name,
          );
        }
      }
      final ct = XmlDocument.parse(
        utf8.decode(zip.findFile('[Content_Types].xml')!.content),
      );
      final defaults = {
        for (final e in ct.findAllElements('Default'))
          e.getAttribute('Extension'): e.getAttribute('ContentType'),
      };
      expect(defaults['jpg'], 'image/jpeg');
      expect(defaults.containsKey('png'), isFalse);
      final overrides = ct
          .findAllElements('Override')
          .map((e) => e.getAttribute('PartName'))
          .toSet();
      // Mọi part XML (trừ .rels) phải có Override.
      for (final n in names) {
        if (n.endsWith('.xml') && n != '[Content_Types].xml') {
          expect(overrides, contains('/$n'));
        }
      }

      final core = utf8.decode(zip.findFile('docProps/core.xml')!.content);
      expect(core, contains('2026-01-02T03:04:05Z'));
      expect(
        XmlDocument.parse(core).findAllElements('dc:title').single.innerText,
        'Báo cáo <1> & "2"',
      );
      // Ảnh lưu thẳng, không nén lại.
      expect(
        zip.findFile('ppt/media/image1.jpg')!.compression,
        CompressionType.none,
      );
    });

    test('mặc định lấy cỡ slide đầu; PNG có content type riêng', () {
      final out = writeImagePptx([
        PptxImageSlide(
          bytes: _fakeJpeg(3),
          widthPt: 720,
          heightPt: 405,
          format: PptxImageFormat.png,
        ),
      ]);
      final deck = readPptx(out);
      expect(deck.slideWidthEmu, 720 * 12700);
      expect(deck.slideHeightEmu, 405 * 12700);
      final pic = deck.slides.single.shapes.whereType<PptxPictureShape>().single;
      expect(pic.extension, 'png');
    });

    test('slide rỗng → ArgumentError', () {
      expect(() => writeImagePptx(const []), throwsArgumentError);
    });
  });

  group('slideSizeEmu', () {
    test('giữ nguyên cỡ hợp lệ', () {
      expect(slideSizeEmu(595, 842), (595 * 12700, 842 * 12700));
    });

    test('quá lớn → co giữ tỉ lệ, cạnh dài = 56 inch', () {
      final (w, h) = slideSizeEmu(14400, 7200); // 200 × 100 inch
      expect(w, 51206400);
      expect(h, 25603200);
    });

    test('quá nhỏ → giãn giữ tỉ lệ, cạnh ngắn = 1 inch', () {
      final (w, h) = slideSizeEmu(36, 18); // 0,5 × 0,25 inch
      expect(h, 914400);
      expect(w, 1828800);
    });

    test('không hợp lệ → 16:9 mặc định', () {
      expect(slideSizeEmu(0, 842), (720 * 12700, 405 * 12700));
      expect(slideSizeEmu(double.nan, 1), (720 * 12700, 405 * 12700));
    });
  });

  group('fitImageEmu', () {
    test('ảnh dọc trên slide ngang → cao bằng slide, nằm giữa ngang', () {
      final (x, y, cx, cy) = fitImageEmu(100, 200, 4000, 1000);
      expect((x, y, cx, cy), (1750, 0, 500, 1000));
    });

    test('tỉ lệ không hợp lệ → phủ kín', () {
      expect(fitImageEmu(0, 0, 4000, 1000), (0, 0, 4000, 1000));
    });
  });
}
