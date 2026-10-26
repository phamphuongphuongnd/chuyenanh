// Debug helper: dart run tool/dump.dart path/to/file.pptx
import 'dart:io';

import 'package:pptx_reader/pptx_reader.dart';

void main(List<String> args) {
  final deck = readPptx(File(args.first).readAsBytesSync());
  print('slide ${deck.slideWidthEmu} x ${deck.slideHeightEmu}, ${deck.slides.length} slides');
  for (final s in deck.slides) {
    print('--- slide ${s.index} hidden=${s.hidden} bg=${_fill(s.background)} notes=${s.notesText}');
    for (final sh in s.shapes) {
      _dump(sh, '  ');
    }
  }
}

String _fill(PptxFill? f) => f == null
    ? 'null'
    : f.isPicture
        ? 'pic(${f.imageBytes!.length})'
        : '0x${f.colorArgb!.toRadixString(16)}';

void _dump(PptxShape sh, String ind) {
  final head = '$ind${sh.runtimeType} "${sh.name}" ${sh.frame} rot=${sh.rotationDeg}'
      '${sh.flipH ? ' flipH' : ''}${sh.flipV ? ' flipV' : ''}';
  switch (sh) {
    case PptxTextShape t:
      print('$head geom=${t.geometry}/${t.presetGeometry} fill=${_fill(t.fill)} '
          'line=${t.line == null ? null : '0x${t.line!.colorArgb.toRadixString(16)}/${t.line!.widthEmu}'} '
          'anchor=${t.verticalAnchor} unsupported=${t.unsupportedKind}');
      for (final p in t.paragraphs) {
        print('$ind    P lvl=${p.level} bu=${p.bulletChar} num=${p.numbered} '
            'ml=${p.marginLeftEmu} ind=${p.indentEmu} al=${p.align}');
        for (final r in p.runs) {
          print('$ind      R "${r.text}" sz=${r.fontSizePt} '
              'col=${r.colorArgb?.toRadixString(16)} font=${r.fontFamily} b=${r.bold}');
        }
      }
    case PptxPictureShape p:
      print('$head ext=${p.extension} bytes=${p.bytes.length} crop='
          '${p.crop == null ? null : '${p.crop!.left},${p.crop!.top},${p.crop!.right},${p.crop!.bottom}'}');
    case PptxTableShape t:
      print('$head cols=${t.columnWidthsEmu} rows=${t.rows.length}');
      for (final r in t.rows) {
        print('$ind    row h=${r.heightEmu}: ${r.cells.map((c) => '[${c.paragraphs.map((p) => p.text).join('|')}'
            ' gs=${c.gridSpan} rs=${c.rowSpan} h=${c.hMerge} v=${c.vMerge} fill=${_fill(c.fill)}]').join(' ')}');
      }
    case PptxGroupShape g:
      print('$head children=${g.children.length}');
      for (final c in g.children) {
        _dump(c, '$ind    ');
      }
  }
}
