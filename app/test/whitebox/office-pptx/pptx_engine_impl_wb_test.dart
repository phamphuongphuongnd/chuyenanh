// Kiểm thử hộp trắng A14 — pptx_engine_impl.dart.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_layout/pdf_layout.dart' show PptxImageSlide, writeImagePptx;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/office/pptx_engine.dart' as eng;
import 'package:pdf_office/features/office_pptx/pptx_engine_impl.dart';
import 'package:pptx_reader/pptx_reader.dart' as pkg;

Uint8List _validPptx() => writeImagePptx(
  [
    PptxImageSlide(
      bytes: Uint8List.fromList([0xFF, 0xD8, 1, 0xFF, 0xD9]),
      widthPt: 720,
      heightPt: 405,
    ),
  ],
  slideWidthPt: 720,
  slideHeightPt: 405,
  title: 't',
);

const _f = pkg.PptxRect(1, 2, 3, 4);

pkg.PptxDeck _deckOf(List<pkg.PptxShape> shapes, {pkg.PptxFill? bg}) => pkg.PptxDeck(
  slideWidthEmu: 100,
  slideHeightEmu: 50,
  slides: [pkg.PptxSlide(index: 0, background: bg, shapes: shapes, notesText: 'n')],
);

eng.PptxShape _one(pkg.PptxShape s) => toEngineDeck(_deckOf([s])).slides.single.shapes.single;

pkg.PptxTextShape _text({
  String? preset = 'rightArrow',
  pkg.PptxFill? fill = const pkg.PptxFill.solid(0xFF112233),
  pkg.PptxLine? line = const pkg.PptxLine(colorArgb: 0xFF445566, widthEmu: 12700),
  pkg.PptxAnchor anchor = pkg.PptxAnchor.top,
  pkg.PptxAlign align = pkg.PptxAlign.left,
}) => pkg.PptxTextShape(
  frame: _f,
  geometry: pkg.PptxGeometry.other,
  presetGeometry: preset,
  fill: fill,
  line: line,
  verticalAnchor: anchor,
  paragraphs: [
    pkg.PptxParagraph(align: align, runs: const [pkg.PptxRun(text: 'Xin chào', bold: true)]),
  ],
);

void main() {
  group('U1 loadPptxDeckFromBytes', () {
    test('U1.P1 bytes PPTX hợp lệ ⇒ deck 1 slide 720×405 pt', () async {
      final d = await loadPptxDeckFromBytes(_validPptx());
      expect(d.slides, hasLength(1));
      expect(d.slideWidthEmu, 720 * 12700);
    });
    test('U1.P2 bytes rác ⇒ CorruptFile mang message của PptxFormatException (nhánh D2 Đ)', () async {
      final r = await loadPptxDeckFromBytes(Uint8List.fromList([1, 2, 3]))
          .then<Object>((v) => v, onError: (Object e) => e);
      expect(r, isA<CorruptFile>());
      // D2 Đ: detail = e.message (không có tiền tố "PptxFormatException:").
      expect((r as CorruptFile).detail, isNot(startsWith('PptxFormatException')));
    });
  });

  group('U2 loadPptxDeckFromFile', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('wb_pptx_impl'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('U2.P1 file có thật ⇒ deck', () async {
      final f = File(p.join(dir.path, 'a.pptx'))..writeAsBytesSync(_validPptx());
      final d = await loadPptxDeckFromFile(f.path);
      expect(d.slides, hasLength(1));
    });
    test('U2.P2 file không tồn tại ⇒ AppError (không phải CorruptFile)', () async {
      final r = await loadPptxDeckFromFile(p.join(dir.path, 'none.pptx'))
          .then<Object>((v) => v, onError: (Object e) => e);
      expect(r, isA<AppError>());
      expect(r, isNot(isA<CorruptFile>()));
    });
  });

  group('U3 toEngineDeck', () {
    test('U3.P1 slide có nền màu ⇒ backgroundArgb = màu, giữ notes + kích thước', () {
      final d = toEngineDeck(_deckOf(const [], bg: const pkg.PptxFill.solid(0xFFABCDEF)));
      expect(d.slideWidthEmu, 100);
      expect(d.slideHeightEmu, 50);
      expect(d.slides.single.backgroundArgb, 0xFFABCDEF);
      expect(d.slides.single.notes, 'n');
    });
    test('U3.P2 slide không nền ⇒ backgroundArgb null', () {
      expect(toEngineDeck(_deckOf(const [])).slides.single.backgroundArgb, isNull);
    });
  });

  group('U4 _shape', () {
    test('U4.P1 khung chữ đủ thuộc tính ⇒ PptxShapeText giữ preset/fill/line/top', () {
      final s = _one(_text()) as eng.PptxShapeText;
      expect(s.geometry, 'rightArrow');
      expect(s.fillArgb, 0xFF112233);
      expect(s.lineArgb, 0xFF445566);
      expect(s.lineWidthEmu, 12700);
      expect(s.verticalAlign, eng.PptxVAlign.top);
      expect((s.frame.x, s.frame.y, s.frame.cx, s.frame.cy), (1, 2, 3, 4));
      expect(s.paragraphs.single.runs.single.text, 'Xin chào');
      expect(s.paragraphs.single.runs.single.bold, isTrue);
    });
    test('U4.P2 ảnh ⇒ PptxPicture, contentType image/<đuôi>', () {
      final bytes = Uint8List.fromList([1, 2]);
      final s = _one(pkg.PptxPictureShape(frame: _f, bytes: bytes, extension: 'png')) as eng.PptxPicture;
      expect(s.bytes, bytes);
      expect(s.contentType, 'image/png');
    });
    test('U4.P3 bảng ⇒ PptxTable, chữ mỗi ô nối các đoạn bằng \\n', () {
      final s = _one(const pkg.PptxTableShape(
        frame: _f,
        columnWidthsEmu: [10, 20],
        rows: [
          pkg.PptxTableRow(heightEmu: 5, cells: [
            pkg.PptxTableCell(paragraphs: [
              pkg.PptxParagraph(runs: [pkg.PptxRun(text: 'a')]),
              pkg.PptxParagraph(runs: [pkg.PptxRun(text: 'b')]),
            ]),
            pkg.PptxTableCell(),
          ]),
        ],
      )) as eng.PptxTable;
      expect(s.rows, [
        ['a\nb', ''],
      ]);
      expect(s.columnWidthsEmu, [10, 20]);
    });
    test('U4.P4 nhóm ⇒ PptxGroup, con đổi đệ quy', () {
      final s = _one(pkg.PptxGroupShape(frame: _f, children: [_text()])) as eng.PptxGroup;
      expect(s.children.single, isA<eng.PptxShapeText>());
    });
    test('U4.P5 không có prstGeom ⇒ geometry = tên enum', () {
      final s = _one(_text(preset: null)) as eng.PptxShapeText;
      expect(s.geometry, 'other');
    });
    test('U4.P6 không fill ⇒ fillArgb null', () {
      expect((_one(_text(fill: null)) as eng.PptxShapeText).fillArgb, isNull);
    });
    test('U4.P7* không viền ⇒ lineArgb và lineWidthEmu null', () {
      final s = _one(_text(line: null)) as eng.PptxShapeText;
      expect(s.lineArgb, isNull);
      expect(s.lineWidthEmu, isNull);
    });
    test('U4.P9 neo giữa ⇒ VAlign.middle', () {
      expect((_one(_text(anchor: pkg.PptxAnchor.middle)) as eng.PptxShapeText).verticalAlign,
          eng.PptxVAlign.middle);
    });
    test('U4.P10 neo dưới ⇒ VAlign.bottom', () {
      expect((_one(_text(anchor: pkg.PptxAnchor.bottom)) as eng.PptxShapeText).verticalAlign,
          eng.PptxVAlign.bottom);
    });
  });

  group('U5 _paragraph', () {
    eng.PptxAlign alignOf(pkg.PptxAlign a) =>
        (_one(_text(align: a)) as eng.PptxShapeText).paragraphs.single.align;
    test('U5.P1 left', () => expect(alignOf(pkg.PptxAlign.left), eng.PptxAlign.left));
    test('U5.P2 center', () => expect(alignOf(pkg.PptxAlign.center), eng.PptxAlign.center));
    test('U5.P3 right', () => expect(alignOf(pkg.PptxAlign.right), eng.PptxAlign.right));
    test('U5.P4 justify', () => expect(alignOf(pkg.PptxAlign.justify), eng.PptxAlign.justify));
  });
}
