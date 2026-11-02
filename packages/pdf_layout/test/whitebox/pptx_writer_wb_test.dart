// Kiểm thử hộp trắng (A18) — lib/src/pptx_writer.dart (MỚI). Mong đợi chép từ buoc-5-du-lieu-thu.md.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pdf_layout/pdf_layout.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

Uint8List _img(int seed) => Uint8List.fromList([0xFF, 0xD8, seed, 0xFF, 0xD9]);

PptxImageSlide _s(double w, double h, [PptxImageFormat f = PptxImageFormat.jpeg]) =>
    PptxImageSlide(bytes: _img(w.toInt() % 200), widthPt: w, heightPt: h, format: f);

Archive _zip(Uint8List b) => ZipDecoder().decodeBytes(b);

XmlDocument _part(Archive z, String name) =>
    XmlDocument.parse(utf8.decode(z.findFile(name)!.content));

(int, int) _sldSz(Uint8List b) {
  final e = _part(_zip(b), 'ppt/presentation.xml').findAllElements('p:sldSz').single;
  return (int.parse(e.getAttribute('cx')!), int.parse(e.getAttribute('cy')!));
}

const _def = (9144000, 5143500);

void main() {
  group('U1 writeImagePptx', () {
    test('U1-P1 không truyền cỡ ⇒ cỡ slide đầu; đủ 2 ảnh', () {
      final b = writeImagePptx([_s(595, 842), _s(842, 595)]);
      final z = _zip(b);
      // nhánh vòng lặp: đủ 2 slide và 2 ảnh
      expect(z.findFile('ppt/slides/slide2.xml'), isNotNull);
      expect(z.findFile('ppt/media/image1.jpg'), isNotNull);
      expect(z.findFile('ppt/media/image2.jpg'), isNotNull);
      expect(_sldSz(b), (7556500, 10693400));
    });
    test('U1-P2 rỗng ⇒ ArgumentError', () {
      expect(() => writeImagePptx(const []), throwsArgumentError);
    });
    test('U1-P3 chỉ truyền rộng ⇒ rộng tham số, cao slide đầu', () {
      expect(_sldSz(writeImagePptx([_s(595, 842)], slideWidthPt: 720)), (9144000, 10693400));
    });
    test('U1-P4 chỉ truyền cao ⇒ rộng slide đầu, cao tham số', () {
      expect(_sldSz(writeImagePptx([_s(595, 842)], slideHeightPt: 405)), (7556500, 5143500));
    });
  });

  group('U2 slideSizeEmu', () {
    test('U2-P1 hợp lệ ⇒ giữ nguyên', () => expect(slideSizeEmu(595, 842), (7556500, 10693400)));
    test('U2-P2 rộng 0 ⇒ 16:9', () => expect(slideSizeEmu(0, 842), _def));
    test('U2-P3 cao NaN ⇒ 16:9', () => expect(slideSizeEmu(595, double.nan), _def));
    test('U2-P6 quá lớn ⇒ cạnh dài 56 inch, giữ tỉ lệ', () {
      expect(slideSizeEmu(5000, 3000), (51206400, 30723840));
    });
    test('U2-P7 quá nhỏ ⇒ cạnh ngắn 1 inch, giữ tỉ lệ', () {
      expect(slideSizeEmu(36, 72), (914400, 1828800));
    });
    test('U2-B1 tỉ lệ > 56:1 ⇒ ép từng cạnh', () {
      expect(slideSizeEmu(10000, 10), (51206400, 914400));
    });
    test('U2-B2 cỡ cực lớn 1e308 ⇒ không ném, ép về 56 inch × 1 inch', () {
      final r = (() {
        try {
          return slideSizeEmu(1e308, 100);
        } catch (e) {
          return e;
        }
      })();
      expect(r, (51206400, 914400));
    });
    test('U2-B3 cỡ cực nhỏ 1e-320 vuông ⇒ không ném, 1 × 1 inch', () {
      final r = (() {
        try {
          return slideSizeEmu(1e-320, 1e-320);
        } catch (e) {
          return e;
        }
      })();
      expect(r, (914400, 914400));
    });
  });

  group('U3 ok(v)', () {
    test('U3-P1 595 ⇒ hợp lệ', () => expect(slideSizeEmu(595, 842), (7556500, 10693400)));
    test('U3-P2 vô cực ⇒ 16:9', () => expect(slideSizeEmu(double.infinity, 842), _def));
    test('U3-P3 âm ⇒ 16:9', () => expect(slideSizeEmu(-5, 842), _def));
  });

  group('U4 fitImageEmu', () {
    test('U4-P1 ảnh dọc trên slide ngang ⇒ cao bằng slide, giữa ngang', () {
      final (x, y, cx, cy) = fitImageEmu(595, 842, 9144000, 5143500);
      expect(cy, 5143500);
      expect(cx, closeTo(595 / 842 * 5143500, 1));
      expect(x, (9144000 - cx) ~/ 2);
      expect(y, 0);
    });
    final full = (0, 0, 9144000, 5143500);
    test('U4-P2 wPt NaN ⇒ phủ kín', () => expect(fitImageEmu(double.nan, 842, 9144000, 5143500), full));
    test('U4-P3 wPt 0 ⇒ phủ kín', () => expect(fitImageEmu(0, 842, 9144000, 5143500), full));
    test('U4-P4 hPt vô cực ⇒ phủ kín', () {
      expect(fitImageEmu(595, double.infinity, 9144000, 5143500), full);
    });
    test('U4-P5 hPt âm ⇒ phủ kín', () => expect(fitImageEmu(595, -1, 9144000, 5143500), full));
    test('U4-B1 ảnh vuông cực nhỏ ⇒ không ném, vừa khít slide vuông', () {
      final r = (() {
        try {
          return fitImageEmu(5e-324, 5e-324, 1000, 1000);
        } catch (e) {
          return e;
        }
      })();
      expect(r, (0, 0, 1000, 1000));
    });
  });

  group('U5 _contentTypes', () {
    Map<String?, String?> defaults(Uint8List b) => {
      for (final e in _part(_zip(b), '[Content_Types].xml').findAllElements('Default'))
        e.getAttribute('Extension'): e.getAttribute('ContentType'),
    };
    Set<String?> overrides(Uint8List b) => _part(_zip(b), '[Content_Types].xml')
        .findAllElements('Override')
        .map((e) => e.getAttribute('PartName'))
        .toSet();
    test('U5-P1/P2 chỉ JPEG ⇒ Default jpg, không Default png', () {
      final b = writeImagePptx([_s(720, 405)]);
      final d = defaults(b);
      expect(d['jpg'], 'image/jpeg');
      expect(d.containsKey('png'), isFalse);
      expect(overrides(b), contains('/ppt/slides/slide1.xml'));
    });
    test('U5-P1b JPEG + PNG ⇒ cả 2 Default, Override 2 slide', () {
      final b = writeImagePptx([_s(720, 405), _s(720, 405, PptxImageFormat.png)]);
      final d = defaults(b);
      expect(d['jpg'], 'image/jpeg');
      expect(d['png'], 'image/png');
      expect(overrides(b), containsAll(['/ppt/slides/slide1.xml', '/ppt/slides/slide2.xml']));
    });
  });

  group('U6 _core', () {
    XmlDocument core(Uint8List b) => _part(_zip(b), 'docProps/core.xml');
    test('U6-P1 có title + created', () {
      final c = core(writeImagePptx([_s(720, 405)], title: 'T & <x>', created: DateTime.utc(2026, 1, 2, 3, 4, 5)));
      expect(c.findAllElements('dc:title').single.innerText, 'T & <x>');
      expect(c.findAllElements('dcterms:created').single.innerText, '2026-01-02T03:04:05Z');
    });
    test('U6-P2 created null ⇒ giờ hiện tại UTC', () {
      final before = DateTime.now().toUtc();
      final c = core(writeImagePptx([_s(720, 405)]));
      final t = c.findAllElements('dcterms:created').single.innerText;
      expect(t, matches(RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$')));
      expect(DateTime.parse(t).difference(before).inSeconds.abs(), lessThanOrEqualTo(60));
    });
    test('U6-P3 title null ⇒ không dc:title; creator mặc định pdf_layout', () {
      final c = core(writeImagePptx([_s(720, 405)]));
      expect(c.findAllElements('dc:title'), isEmpty);
      expect(c.findAllElements('dc:creator').single.innerText, 'pdf_layout');
    });
  });

  test('U7-P1 2 slide ⇒ sldId 256/257, rId2/rId3 trỏ đúng slide', () {
    final z = _zip(writeImagePptx([_s(720, 405), _s(720, 405)]));
    final ids = _part(z, 'ppt/presentation.xml')
        .findAllElements('p:sldId')
        .map((e) => (e.getAttribute('id'), e.getAttribute('r:id')))
        .toList();
    expect(ids, [('256', 'rId2'), ('257', 'rId3')]);
    final rels = {
      for (final e in _part(z, 'ppt/_rels/presentation.xml.rels').findAllElements('Relationship'))
        e.getAttribute('Id'): e.getAttribute('Target'),
    };
    expect(rels['rId2'], 'slides/slide1.xml');
    expect(rels['rId3'], 'slides/slide2.xml');
  });
}
