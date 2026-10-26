// Đọc PPTX bằng packages/pptx_reader trong Isolate + impl `PptxEngine` (model gọn của
// interface). Màn xem dùng thẳng model đầy đủ của pptx_reader qua [loadPptxDeckFromFile].
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:pptx_reader/pptx_reader.dart' as pkg;

import '../../core/errors/app_error.dart';
import '../../engines/office/pptx_engine.dart' as eng;

/// Parse bytes → model đầy đủ của pptx_reader (trong isolate riêng).
/// Lỗi: [CorruptFile].
Future<pkg.PptxDeck> loadPptxDeckFromBytes(Uint8List bytes) async {
  try {
    return await Isolate.run(() => pkg.readPptx(bytes));
  } on pkg.PptxFormatException catch (e) {
    throw CorruptFile(e.message);
  } on AppError {
    rethrow;
  } on Object catch (e) {
    // Isolate.run ném lại lỗi gốc; lỗi lạ khi parse XML/zip = file hỏng.
    throw CorruptFile(e.toString());
  }
}

/// Đọc file → model đầy đủ. Lỗi IO → [AppError.from]; nội dung hỏng → [CorruptFile].
Future<pkg.PptxDeck> loadPptxDeckFromFile(String path) async {
  final Uint8List bytes;
  try {
    bytes = await File(path).readAsBytes();
  } on Object catch (e) {
    throw AppError.from(e);
  }
  return loadPptxDeckFromBytes(bytes);
}

/// Impl của interface `PptxEngine`: parse bằng pptx_reader rồi đổi sang model gọn.
class PackagePptxEngine implements eng.PptxEngine {
  const PackagePptxEngine();

  @override
  Future<eng.PptxDeck> parseFile(String path) async =>
      toEngineDeck(await loadPptxDeckFromFile(path));

  @override
  Future<eng.PptxDeck> parseBytes(Uint8List bytes) async =>
      toEngineDeck(await loadPptxDeckFromBytes(bytes));
}

eng.PptxDeck toEngineDeck(pkg.PptxDeck deck) => eng.PptxDeck(
  slideWidthEmu: deck.slideWidthEmu,
  slideHeightEmu: deck.slideHeightEmu,
  slides: [
    for (final s in deck.slides)
      eng.PptxSlide(
        shapes: [for (final sh in s.shapes) _shape(sh)],
        backgroundArgb: s.background?.colorArgb,
        notes: s.notesText,
      ),
  ],
);

eng.PptxFrame _frame(pkg.PptxShape s) => eng.PptxFrame(
  s.frame.x,
  s.frame.y,
  s.frame.cx,
  s.frame.cy,
  rotation: s.rotationDeg,
  flipH: s.flipH,
  flipV: s.flipV,
);

eng.PptxShape _shape(pkg.PptxShape s) => switch (s) {
  pkg.PptxTextShape() => eng.PptxShapeText(
    _frame(s),
    geometry: s.presetGeometry ?? s.geometry.name,
    fillArgb: s.fill?.colorArgb,
    lineArgb: s.line?.colorArgb,
    lineWidthEmu: s.line?.widthEmu,
    paragraphs: [for (final p in s.paragraphs) _paragraph(p)],
    verticalAlign: switch (s.verticalAnchor) {
      pkg.PptxAnchor.top => eng.PptxVAlign.top,
      pkg.PptxAnchor.middle => eng.PptxVAlign.middle,
      pkg.PptxAnchor.bottom => eng.PptxVAlign.bottom,
    },
  ),
  pkg.PptxPictureShape() => eng.PptxPicture(
    _frame(s),
    s.bytes,
    contentType: 'image/${s.extension}',
  ),
  pkg.PptxTableShape() => eng.PptxTable(
    _frame(s),
    [
      for (final r in s.rows)
        [
          for (final c in r.cells)
            c.paragraphs.map((p) => p.text).join('\n'),
        ],
    ],
    columnWidthsEmu: s.columnWidthsEmu,
  ),
  pkg.PptxGroupShape() => eng.PptxGroup(_frame(s), [
    for (final c in s.children) _shape(c),
  ]),
};

eng.PptxParagraph _paragraph(pkg.PptxParagraph p) => eng.PptxParagraph(
  [
    for (final r in p.runs)
      eng.PptxTextRun(
        r.text,
        bold: r.bold,
        italic: r.italic,
        underline: r.underline,
        fontSize: r.fontSizePt,
        colorArgb: r.colorArgb,
      ),
  ],
  align: switch (p.align) {
    pkg.PptxAlign.left => eng.PptxAlign.left,
    pkg.PptxAlign.center => eng.PptxAlign.center,
    pkg.PptxAlign.right => eng.PptxAlign.right,
    pkg.PptxAlign.justify => eng.PptxAlign.justify,
  },
  level: p.level,
  bullet: p.bulletChar,
);
