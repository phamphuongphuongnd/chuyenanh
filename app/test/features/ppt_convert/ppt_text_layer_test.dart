// Lớp chữ vô hình của PowerPoint → PDF: chữ của slide phải còn trích được từ PDF kết quả,
// nằm đúng chỗ, kể cả khi thiếu font (rơi về font chuẩn, không ném lỗi).
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf_office/features/convert/engine/font_set.dart';
import 'package:pdf_office/features/convert/text/line_wrap.dart';
import 'package:pdf_office/features/convert/text/script_runs.dart';
import 'package:pdf_office/features/ppt_convert/engine/ppt_text_layer.dart';
import 'package:pdf_office/features/ppt_convert/engine/ppt_to_pdf.dart';
import 'package:pptx_reader/pptx_reader.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

const _emu = 12700;

PptxTextShape _shape(
  double x,
  double y,
  double w,
  double h,
  List<PptxParagraph> paras, {
  PptxAnchor anchor = PptxAnchor.top,
  bool wrap = true,
  double rot = 0,
}) => PptxTextShape(
  frame: PptxRect(
    (x * _emu).round(),
    (y * _emu).round(),
    (w * _emu).round(),
    (h * _emu).round(),
  ),
  paragraphs: paras,
  verticalAnchor: anchor,
  wrap: wrap,
  rotationDeg: rot,
);

PptxParagraph _para(
  String text, {
  double size = 20,
  PptxAlign align = PptxAlign.left,
  bool bold = false,
}) => PptxParagraph(
  align: align,
  runs: [PptxRun(text: text, fontSizePt: size, bold: bold)],
);

PptxSlide _slide(List<PptxShape> shapes, {bool hidden = false, int index = 0}) =>
    PptxSlide(
      index: index,
      background: null,
      shapes: shapes,
      notesText: null,
      hidden: hidden,
    );

/// 720 × 405 pt.
PptxDeck _deck(List<PptxSlide> slides) =>
    PptxDeck(slideWidthEmu: 9144000, slideHeightEmu: 5143500, slides: slides);

/// Đo giả: mỗi ký tự rộng đúng cỡ chữ × 0.5.
class _FakeMeasurer implements TextMeasurer {
  @override
  double width(ScriptFace face, StyledSpan style, String text) =>
      text.runes.length * (style.size ?? 12) * 0.5;

  @override
  double spaceWidth(ScriptFace face, StyledSpan style) => (style.size ?? 12) * 0.5;
}

class _Raster implements SlideRasterizer {
  static final Uint8List _jpg = Uint8List.fromList(
    img.encodeJpg(img.Image(width: 16, height: 9)..clear(img.ColorRgb8(240, 240, 240))),
  );

  @override
  Future<Uint8List> renderSlide(
    PptxDeck deck,
    PptxSlide slide, {
    required int dpi,
  }) async => _jpg;
}

final _fontPaths = {
  FontSlot.regular: 'assets/fonts/NotoSans-Regular.ttf',
  FontSlot.bold: 'assets/fonts/NotoSans-Bold.ttf',
};

/// Các dòng chữ trích được từ trang [i] của PDF [path].
List<sf.TextLine> _lines(String path, int i) {
  final doc = sf.PdfDocument(inputBytes: File(path).readAsBytesSync());
  try {
    return sf.PdfTextExtractor(doc).extractTextLines(startPageIndex: i, endPageIndex: i);
  } finally {
    doc.dispose();
  }
}

String _allText(String path, int pages) {
  final doc = sf.PdfDocument(inputBytes: File(path).readAsBytesSync());
  try {
    final ex = sf.PdfTextExtractor(doc);
    return [
      for (var i = 0; i < pages; i++) ex.extractText(startPageIndex: i, endPageIndex: i),
    ].join('\n');
  } finally {
    doc.dispose();
  }
}

void main() {
  group('collectTextBoxes', () {
    test('hình chữ, nhóm, bảng; bỏ hộp rỗng, hình không hỗ trợ và ảnh', () {
      final tableCell = PptxTableCell(paragraphs: [_para('Ô 1')]);
      final slide = _slide([
        _shape(10, 20, 300, 50, [_para('Tiêu đề')]),
        _shape(0, 0, 100, 100, [_para('   ')]), // chỉ có khoảng trắng
        PptxGroupShape(
          frame: const PptxRect(0, 0, 1, 1),
          children: [_shape(50, 60, 100, 30, [_para('Trong nhóm')])],
        ),
        PptxTableShape(
          frame: PptxRect(100 * _emu, 200 * _emu, 200 * _emu, 40 * _emu),
          columnWidthsEmu: [100 * _emu, 100 * _emu],
          rows: [
            PptxTableRow(
              heightEmu: 40 * _emu,
              cells: [tableCell, const PptxTableCell()],
            ),
          ],
        ),
        PptxTextShape(
          frame: const PptxRect(0, 0, 100, 100),
          paragraphs: [_para('Biểu đồ')],
          unsupportedKind: 'chart',
        ),
      ]);
      final boxes = collectTextBoxes(slide);
      expect(boxes, hasLength(3));
      expect(boxes[0].rect, const Rect.fromLTWH(10, 20, 300, 50));
      expect(boxes[0].paragraphs.single.runs.single.text, 'Tiêu đề');
      expect(boxes[1].rect, const Rect.fromLTWH(50, 60, 100, 30));
      // Ô bảng cộng toạ độ gốc của bảng.
      expect(boxes[2].rect, const Rect.fromLTWH(100, 200, 100, 40));
    });

    test('chữ Việt dạng NFD được gộp thành NFC', () {
      const nfd = 'Tiếng Việt'; // Tiếng Việt, dấu rời
      final boxes = collectTextBoxes(_slide([_shape(0, 0, 200, 40, [_para(nfd)])]));
      expect(boxes.single.paragraphs.single.runs.single.text, 'Tiếng Việt');
    });

    test('xoay 90° đổi chiều khung quanh tâm', () {
      final boxes = collectTextBoxes(
        _slide([_shape(100, 100, 200, 40, [_para('x')], rot: 90)]),
      );
      expect(boxes.single.rect.center.dx, closeTo(200, 1e-9));
      expect(boxes.single.rect.width, closeTo(40, 1e-9));
      expect(boxes.single.rect.height, closeTo(200, 1e-9));
    });
  });

  group('layoutTextBox', () {
    final m = _FakeMeasurer();

    test('hộp hẹp → từ xuống dòng; y tăng đúng một dòng cao', () {
      // Cỡ 20 → ký tự rộng 10; hộp 80 − lề 14.4 = 65.6 ⇒ 4 ký tự (40) vừa, 9 ký tự (90) không.
      final box = collectTextBoxes(
        _slide([_shape(0, 0, 80, 200, [_para('aaaa bbbb cccc')])]),
      ).single;
      final placed = layoutTextBox(box, m);
      expect(placed.map((r) => r.text).toList(), ['aaaa', 'bbbb', 'cccc']);
      expect(placed[1].lineTop - placed[0].lineTop, closeTo(24, 1e-9)); // 20 × 1.2
      expect(placed[0].x, closeTo(7.2, 1e-9));
    });

    test('hộp rộng → cả câu một dòng', () {
      final box = collectTextBoxes(
        _slide([_shape(0, 0, 400, 200, [_para('aaaa bbbb cccc')])]),
      ).single;
      expect(layoutTextBox(box, m).map((r) => r.text).toList(), ['aaaa bbbb cccc']);
    });

    test('căn giữa / phải / dọc giữa', () {
      PlacedTextRun place(PptxParagraph para, {PptxAnchor anchor = PptxAnchor.top}) =>
          layoutTextBox(
            collectTextBoxes(
              _slide([_shape(0, 0, 214.4, 100, [para], anchor: anchor)]),
            ).single,
            m,
          ).single;
      // Chữ rộng 40 trong vùng 200 ⇒ lệch trái 80 + lề 7.2.
      expect(place(_para('abcd', align: PptxAlign.center)).x, closeTo(87.2, 1e-9));
      expect(place(_para('abcd', align: PptxAlign.right)).x, closeTo(167.2, 1e-9));
      // Vùng cao 100 − 7.2 = 92.8, chữ cao 24 ⇒ lệch (92.8 − 24) / 2 + lề trên 3.6.
      expect(
        place(_para('abcd'), anchor: PptxAnchor.middle).lineTop,
        closeTo(3.6 + (92.8 - 24) / 2, 1e-9),
      );
    });
  });

  group('DefaultPptToPdfEngine: chữ còn trích được từ PDF', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('ppttext_'));
    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    final engine = DefaultPptToPdfEngine(fontSource: FileFontSource(_fontPaths));

    test('chữ Latin + Việt nằm đúng chỗ trên đúng trang; slide ẩn bị bỏ', () async {
      final deck = _deck([
        _slide([
          _shape(36, 40, 600, 60, [_para('Hello World', size: 32)]),
          _shape(36, 200, 400, 120, [
            _para('Tiếng Việt có dấu: ặ ỗ ữ ề ở'),
            _para('Dòng thứ hai'),
          ]),
        ]),
        _slide([_shape(0, 0, 300, 50, [_para('Slide ẩn')])], hidden: true, index: 1),
        _slide([_shape(100, 100, 300, 50, [_para('Trang ba')])], index: 2),
      ]);
      final out = p.join(dir.path, 'a.pdf');
      await engine.convert(deck, out, rasterizer: _Raster());

      final all = _allText(out, 2);
      expect(all, contains('Hello World'));
      expect(all, contains('Tiếng Việt có dấu: ặ ỗ ữ ề ở'));
      expect(all, contains('Dòng thứ hai'));
      expect(all, contains('Trang ba'));
      expect(all, isNot(contains('Slide ẩn')));

      // Trang 1: "Hello World" ở gần (36 + lề, 40 + lề) pt; trang 2 không có chữ trang 1.
      final l1 = _lines(out, 0).firstWhere((l) => l.text.contains('Hello'));
      expect(l1.bounds.left, closeTo(36 + 7.2, 3));
      // Dòng 32 pt cao 38,4: đỉnh chữ do Syncfusion báo ≈ đường cơ sở − 0,75 × cỡ.
      expect(l1.bounds.top, closeTo(40 + 3.6 + 6, 6));
      expect(_lines(out, 1).map((l) => l.text).join(' '), isNot(contains('Hello')));
    });

    test('chữ Việt NFD (dấu rời) vẫn tìm được dạng NFC', () async {
      final deck = _deck([
        _slide([_shape(10, 10, 400, 40, [_para('Việt Nam')])]),
      ]);
      final out = p.join(dir.path, 'nfd.pdf');
      await engine.convert(deck, out, rasterizer: _Raster());
      expect(_allText(out, 1), contains('Việt Nam'));
    });

    test('bảng và nhóm cũng có chữ', () async {
      final deck = _deck([
        _slide([
          PptxGroupShape(
            frame: const PptxRect(0, 0, 1, 1),
            children: [_shape(20, 20, 300, 40, [_para('Trong nhóm')])],
          ),
          PptxTableShape(
            frame: PptxRect(50 * _emu, 150 * _emu, 200 * _emu, 40 * _emu),
            columnWidthsEmu: [200 * _emu],
            rows: [
              PptxTableRow(
                heightEmu: 40 * _emu,
                cells: [PptxTableCell(paragraphs: [_para('Ô bảng')])],
              ),
            ],
          ),
        ]),
      ]);
      final out = p.join(dir.path, 'tbl.pdf');
      await engine.convert(deck, out, rasterizer: _Raster());
      final all = _allText(out, 1);
      expect(all, contains('Trong nhóm'));
      expect(all, contains('Ô bảng'));
    });

    test('thiếu font: không ném lỗi, chữ Latin-1 vẫn trích được', () async {
      final deck = _deck([
        _slide([
          _shape(10, 10, 500, 40, [_para('Plain ASCII text')]),
          _shape(10, 100, 500, 40, [_para('Việt 汉字 한글')]),
        ]),
      ]);
      final out = p.join(dir.path, 'nofont.pdf');
      await const DefaultPptToPdfEngine(
        fontSource: NoFontSource(),
      ).convert(deck, out, rasterizer: _Raster());
      expect(_allText(out, 1), contains('Plain ASCII text'));
    });

    test('slide không có chữ → PDF ảnh như cũ, không cần font', () async {
      final deck = _deck([_slide(const [])]);
      final out = p.join(dir.path, 'empty.pdf');
      await const DefaultPptToPdfEngine(
        fontSource: NoFontSource(),
      ).convert(deck, out, rasterizer: _Raster());
      expect(_allText(out, 1).trim(), isEmpty);
    });
  });
}
