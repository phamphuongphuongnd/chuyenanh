// Spike S1 (phan 2): chuan hoa NFC + font fallback theo script -> vi_cjk.pdf.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'vi_nfc.dart';

const _fontDir = r'C:\Windows\Fonts\';
final _outDir = Directory('../spikes/pdf_text/out');

enum _Face { latin, han, hangul }

_Face _faceOf(int c) {
  if ((c >= 0xAC00 && c <= 0xD7AF) ||
      (c >= 0x1100 && c <= 0x11FF) ||
      (c >= 0x3130 && c <= 0x318F)) {
    return _Face.hangul;
  }
  if ((c >= 0x4E00 && c <= 0x9FFF) ||
      (c >= 0x3400 && c <= 0x4DBF) ||
      (c >= 0x3000 && c <= 0x30FF) ||
      (c >= 0xFF00 && c <= 0xFFEF)) {
    return _Face.han;
  }
  return _Face.latin;
}

/// Cat chuoi thanh cac doan lien tiep cung font; dau cach theo doan truoc.
List<(_Face, String)> _runs(String s) {
  final runs = <(_Face, StringBuffer)>[];
  for (final c in s.runes) {
    var f = _faceOf(c);
    if (c == 0x20 && runs.isNotEmpty) f = runs.last.$1;
    if (runs.isEmpty || runs.last.$1 != f) runs.add((f, StringBuffer()));
    runs.last.$2.writeCharCode(c);
  }
  return [for (final r in runs) (r.$1, r.$2.toString())];
}

void main() {
  test('composeVietnamese NFD -> NFC', () {
    expect(composeVietnamese('a\u0306\u0323'), 'ặ');
    expect(composeVietnamese('a\u0323\u0306'), 'ặ');
    expect(composeVietnamese('o\u0302\u0303'), 'ỗ');
    expect(composeVietnamese('u\u031B\u0303'), 'ữ');
    expect(composeVietnamese('a\u0302\u0303'), 'ẫ');
    expect(composeVietnamese('a\u0323\u0302'), 'ậ');
    expect(composeVietnamese('e\u0302\u0300'), 'ề');
    expect(composeVietnamese('o\u031B\u0309'), 'ở');
    expect(composeVietnamese('Nguye\u0302\u0303n Thi\u0323'), 'Nguyễn Thị');
    expect(composeVietnamese('\u0110a\u0323i'), 'Đại');
    expect(composeVietnamese('Hello 中文 abc'), 'Hello 中文 abc');
  });

  test('vi_cjk.pdf: NFD->NFC + fallback font', () {
    _outDir.createSync(recursive: true);
    final fonts = {
      _Face.latin: PdfTrueTypeFont(
          File('${_fontDir}arial.ttf').readAsBytesSync(), 18),
      _Face.han: PdfTrueTypeFont(
          File('${_fontDir}msyh.ttc').readAsBytesSync(), 18),
      _Face.hangul: PdfTrueTypeFont(
          File('${_fontDir}malgun.ttf').readAsBytesSync(), 18),
    };
    final lines = <String>[
      'Tiếng Việt NFC: ặ ỗ ữ ẫ ậ ề ở',
      composeVietnamese(
          'Tie\u0302\u0301ng Vie\u0323\u0302t NFD->NFC: a\u0306\u0323 o\u0302\u0303 u\u031b\u0303 a\u0302\u0303 a\u0323\u0302 e\u0302\u0300 o\u031b\u0309'),
      composeVietnamese(
          'Nguye\u0302\u0303n Thi\u0323 Phu\u031bo\u031b\u0323ng - Tru\u031bo\u031b\u0300ng \u0110a\u0323i ho\u0323c'),
      '中文：你好，世界！汉字测试 简体 繁體 學習',
      '日本語：こんにちは世界 カタカナ ひらがな 漢字',
      '한국어: 안녕하세요 세계 한글 테스트',
      'Hỗn hợp: Hà Nội 河内 하노이 ハノイ (Việt Nam 越南 베트남)',
    ];
    final doc = PdfDocument();
    final page = doc.pages.add();
    var y = 10.0;
    for (final l in lines) {
      var x = 10.0;
      for (final (face, text) in _runs(l)) {
        final f = fonts[face]!;
        page.graphics.drawString(text, f,
            brush: PdfBrushes.black, bounds: Rect.fromLTWH(x, y, 0, 0));
        x += f.measureString(text).width;
      }
      y += 30;
    }
    // Ban PdfTextElement + paginate chi voi dong Latin/Viet da NFC (1 font).
    final elem = PdfTextElement(
        text: lines.sublist(0, 3).join('\n'),
        font: fonts[_Face.latin]!,
        brush: PdfBrushes.black);
    elem.draw(
      page: doc.pages.add(),
      bounds: const Rect.fromLTWH(10, 10, 500, 0),
      format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
    );
    final bytes = Uint8List.fromList(doc.saveSync());
    doc.dispose();
    File('${_outDir.path}/vi_cjk.pdf').writeAsBytesSync(bytes);
    File('${_outDir.path}/vi_cjk_size.txt').writeAsStringSync(
        'vi_cjk.pdf = ${bytes.length} bytes (3 font nhung: arial 1045720, '
        'msyh.ttc 19704352, malgun 13459196) -> subset\n');
    expect(bytes.length, lessThan(1000000));
  });
}
