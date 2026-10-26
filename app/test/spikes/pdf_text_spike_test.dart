// Spike S1: Syncfusion PDF ve chu Viet (NFC/NFD) + CJK voi font TrueType nhung.
// Font doc tu C:\Windows\Fonts (khong commit). Ket qua ghi vao spikes/pdf_text/out/.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

const _fontDir = r'C:\Windows\Fonts\';
final _outDir = Directory('../spikes/pdf_text/out');

// NFC: ky tu da dung san.
const viNfc = <String>[
  'Tiếng Việt: ặ ỗ ữ ẫ ậ ề ở ự ợ ỡ ằ ẳ ẵ',
  'Nguyễn Thị Phượng — Trường Đại học Bách khoa Hà Nội',
  'Hoa quả thuỷ tạ, quyến luyến, nghiêng, khuỷu tay, đường',
  'ĂÂÊÔƠƯĐ ăâêôơưđ  ẶẬỆỘỢỰ ẠẢÃẤẦẨẪẬ',
];
// NFD: chu cai goc + dau roi (escape ro rang, ghi ra duoi dang ky tu to hop).
const viNfd = <String>[
  'Tie\u0302\u0301ng Vie\u0323\u0302t: a\u0306\u0323 o\u0302\u0303 u\u031b\u0303 a\u0302\u0303 a\u0323\u0302 e\u0302\u0300 o\u031b\u0309',
  'Nguye\u0302\u0303n Thi\u0323 Phu\u031bo\u031b\u0323ng \u2014 Tru\u031bo\u031b\u0300ng \u0110a\u0323i ho\u0323c',
  'Thuy\u0309 ta\u0323, quye\u0302\u0301n luye\u0302\u0301n, khuy\u0309u tay',
];
const cjk = <String>[
  '中文：你好，世界！汉字测试 简体 繁體 學習',
  '日本語：こんにちは世界 カタカナ ひらがな 漢字',
  '한국어: 안녕하세요 세계 한글 테스트',
];

String _tag(String path) => path.toLowerCase().replaceAll('.', '_');

Uint8List _read(String name) => File('$_fontDir$name').readAsBytesSync();

/// Trang 1: drawString tung dong. Trang 2: PdfTextElement + paginate.
Uint8List _makePdf(Uint8List fontBytes, List<String> lines) {
  final doc = PdfDocument();
  final font = PdfTrueTypeFont(fontBytes, 18);
  final page = doc.pages.add();
  var y = 10.0;
  for (final l in lines) {
    page.graphics.drawString(l, font,
        brush: PdfBrushes.black, bounds: Rect.fromLTWH(10, y, 500, 28));
    y += 30;
  }
  final elem = PdfTextElement(
      text: lines.join('\n'), font: font, brush: PdfBrushes.black);
  final p2 = doc.pages.add();
  elem.draw(
    page: p2,
    bounds: Rect.fromLTWH(10, 10, 500, 0),
    format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
  );
  final bytes = Uint8List.fromList(doc.saveSync());
  doc.dispose();
  return bytes;
}

void main() {
  setUpAll(() => _outDir.createSync(recursive: true));
  final report = StringBuffer();
  tearDownAll(() =>
      File('${_outDir.path}/report.txt').writeAsStringSync(report.toString()));

  test('Viet NFC+NFD bang Arial', () {
    final arial = _read('arial.ttf');
    final bytes = _makePdf(arial, [
      '--- NFC ---',
      ...viNfc,
      '--- NFD ---',
      ...viNfd,
    ]);
    File('${_outDir.path}/vi_arial.pdf').writeAsBytesSync(bytes);
    report.writeln('vi_arial.pdf: ${bytes.length} bytes (arial.ttf '
        '${arial.length} bytes) subset=${bytes.length < arial.length}');
    expect(bytes.length, greaterThan(1000));
  });

  for (final name in [
    'msyh.ttc',
    'simsun.ttc',
    'YuGothR.ttc',
    'msgothic.ttc',
    'malgun.ttf',
    'SimsunExtG.ttf',
    'segoeui.ttf',
  ]) {
    test('CJK/Viet voi $name', () {
      final fb = _read(name);
      try {
        final bytes = _makePdf(fb, [
          '--- CJK ---',
          ...cjk,
          '--- VI NFC ---',
          viNfc[0],
          viNfc[1],
          '--- VI NFD ---',
          viNfd[0],
        ]);
        File('${_outDir.path}/font_${_tag(name)}.pdf').writeAsBytesSync(bytes);
        report.writeln('$name: OK pdf=${bytes.length} font=${fb.length} '
            'subset=${bytes.length < fb.length}');
      } catch (e) {
        report.writeln(
            '$name: LOI ${e.runtimeType}: ${e.toString().split("\n").first}');
      }
    });
  }
}
