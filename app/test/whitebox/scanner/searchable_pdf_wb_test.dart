// Kiểm thử hộp trắng A07 — scanner/searchable_pdf.dart (Bước 6).
// Mã bộ theo test-output/whitebox/scanner/searchable_pdf/buoc-5-du-lieu-thu.md.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/engines/ocr/ocr_engine.dart';
import 'package:pdf_office/features/convert/engine/font_set.dart';
import 'package:pdf_office/features/convert/text/line_wrap.dart' show StyledSpan;
import 'package:pdf_office/features/convert/text/script_runs.dart';
import 'package:pdf_office/features/scanner/export/searchable_pdf.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

const _fontFiles = {
  FontSlot.regular: 'assets/fonts/NotoSans-Regular.ttf',
};

Map<FontSlot, Uint8List> _fonts() =>
    {for (final e in _fontFiles.entries) e.key: File(e.value).readAsBytesSync()};

OcrResult _r(List<(String, Rect)> lines, {int? w = 1000, int? h = 1400}) => OcrResult(
      text: lines.map((e) => e.$1).join('\n'),
      blocks: [
        OcrBlock(lines.map((e) => e.$1).join('\n'), Rect.zero, [
          for (final l in lines) OcrLine(l.$1, l.$2),
        ]),
      ],
      imageWidth: w,
      imageHeight: h,
    );

Uint8List _pdf(int pages) {
  final doc = sf.PdfDocument();
  for (var i = 0; i < pages; i++) {
    doc.pages.add().graphics.drawRectangle(
        brush: sf.PdfBrushes.lightGray, bounds: const Rect.fromLTWH(0, 0, 50, 50));
  }
  final b = Uint8List.fromList(doc.saveSync());
  doc.dispose();
  return b;
}

String _text(Uint8List pdf) {
  final doc = sf.PdfDocument(inputBytes: pdf);
  try {
    return sf.PdfTextExtractor(doc).extractText();
  } finally {
    doc.dispose();
  }
}

class _CountFonts implements FontSource {
  var n = 0;
  @override
  Future<Uint8List?> load(FontSlot slot) async {
    n++;
    return null;
  }
}

class _ThrowFonts implements FontSource {
  @override
  Future<Uint8List?> load(FontSlot slot) async => throw StateError('font hỏng');
}

void main() {
  const line = Rect.fromLTWH(0, 0, 1000, 100);

  group('U1 placeOcrLines', () {
    test('U1-B1 ảnh ngang trong trang dọc ⇒ co theo sx, đặt giữa theo chiều dọc', () {
      final l = placeOcrLines(_r([('abc', line)], w: 1000, h: 500), 500, 700).single;
      expect(l.left, closeTo(0, 1e-9));
      expect(l.top, closeTo(225, 1e-9));
      expect(l.width, closeTo(500, 1e-9));
      expect(l.height, closeTo(50, 1e-9));
    });
    test('U1-B2 imageWidth null ⇒ rỗng', () {
      expect(placeOcrLines(_r([('abc', line)], w: null), 500, 700), isEmpty);
    });
    test('U1-B3 imageHeight null ⇒ rỗng', () {
      expect(placeOcrLines(_r([('abc', line)], h: null), 500, 700), isEmpty);
    });
    test('U1-B6 imageWidth = 0 ⇒ rỗng', () {
      expect(placeOcrLines(_r([('abc', line)], w: 0), 500, 700), isEmpty);
    });
    test('U1-B7 imageHeight = 0 ⇒ rỗng', () {
      expect(placeOcrLines(_r([('abc', line)], h: 0), 500, 700), isEmpty);
    });
    test('U1-B8 pageW = 0 ⇒ rỗng', () {
      expect(placeOcrLines(_r([('abc', line)]), 0, 700), isEmpty);
    });
    test('U1-B9 pageH = 0 ⇒ rỗng', () {
      expect(placeOcrLines(_r([('abc', line)]), 500, 0), isEmpty);
    });
    test('U1-B10 ảnh dọc trong trang vuông ⇒ co theo sy, đặt giữa theo chiều ngang', () {
      final l = placeOcrLines(
              _r([('abc', const Rect.fromLTWH(0, 0, 100, 40))], w: 1000, h: 2000), 500, 500)
          .single;
      expect(l.left, closeTo(125, 1e-9));
      expect(l.top, closeTo(0, 1e-9));
      expect(l.width, closeTo(25, 1e-9));
      expect(l.height, closeTo(10, 1e-9));
    });
    test('U1-B11 không có block ⇒ rỗng', () {
      expect(
          placeOcrLines(const OcrResult(text: '', blocks: [], imageWidth: 10, imageHeight: 10), 100, 100),
          isEmpty);
    });
    test('U1-B12 block không có dòng ⇒ dùng chữ + khung của block', () {
      final r = const OcrResult(
        text: 'Tiêu đề',
        blocks: [OcrBlock('Tiêu đề', Rect.fromLTWH(10, 20, 100, 30), [])],
        imageWidth: 100,
        imageHeight: 100,
      );
      final l = placeOcrLines(r, 100, 100).single;
      expect(l.text, 'Tiêu đề');
      expect(l.left, closeTo(10, 1e-9));
      expect(l.top, closeTo(20, 1e-9));
    });
  });

  group('U2 add (hàm cục bộ)', () {
    test('U2-B1 dòng hợp lệ ⇒ được đặt (NFC, bỏ xuống dòng)', () {
      final l = placeOcrLines(_r([('Việt\nNam', line)]), 1000, 1400).single;
      expect(l.text, 'Việt Nam');
    });
    test('U2-B2 chữ rỗng sau trim ⇒ bỏ', () {
      expect(placeOcrLines(_r([('   ', line)]), 1000, 1400), isEmpty);
    });
    test('U2-B3 bề rộng 0 ⇒ bỏ', () {
      expect(placeOcrLines(_r([('abc', const Rect.fromLTWH(0, 0, 0, 10))]), 1000, 1400), isEmpty);
    });
    test('U2-B4 chiều cao 0 ⇒ bỏ', () {
      expect(placeOcrLines(_r([('abc', const Rect.fromLTWH(0, 0, 10, 0))]), 1000, 1400), isEmpty);
    });
  });

  group('U3 scriptsInResults', () {
    test('U3-B1 có chữ Latin ⇒ {latin}', () {
      expect(scriptsInResults([_r([('abc', line)])]), {ScriptFace.latin});
    });
    test('U3-B2 không có kết quả ⇒ rỗng', () {
      expect(scriptsInResults([]), isEmpty);
    });
    test('U3-B3 kết quả không có block ⇒ rỗng', () {
      expect(scriptsInResults([OcrResult.empty]), isEmpty);
    });
    test('U3-B4 block chữ rỗng ⇒ rỗng', () {
      expect(
          scriptsInResults([const OcrResult(text: '', blocks: [OcrBlock('', Rect.zero, [])])]), isEmpty);
    });
  });

  group('U4 drawInvisibleTextLayer', () {
    test('U4-B1 đủ font, khớp trang ⇒ PDF mới có chữ', () {
      final out = drawInvisibleTextLayer(
          _pdf(1), [_r([('Hello Việt', const Rect.fromLTWH(10, 10, 400, 40))])], _fonts());
      expect(out, isNotNull);
      expect(_text(out!), contains('Hello Việt'));
    });
    test('U4-B2 không có chữ ⇒ null', () {
      expect(drawInvisibleTextLayer(_pdf(1), [OcrResult.empty], _fonts()), isNull);
    });
    test('U4-B4 thiếu font regular (đổi: trước bỏ font Hàn) ⇒ null', () {
      final f = _fonts()..remove(FontSlot.regular);
      expect(
          drawInvisibleTextLayer(_pdf(1), [_r([('하노이', const Rect.fromLTWH(10, 10, 400, 40))])], f),
          isNull);
    });
    test('U4-B5 số trang khác số kết quả ⇒ null', () {
      expect(
          drawInvisibleTextLayer(_pdf(2), [_r([('Hello', const Rect.fromLTWH(10, 10, 400, 40))])], _fonts()),
          isNull);
    });
    test('U4-B7 có chữ nhưng không đặt được dòng nào ⇒ null', () {
      expect(
          drawInvisibleTextLayer(
              _pdf(1), [_r([('Hello', const Rect.fromLTWH(10, 10, 400, 40))], w: null)], _fonts()),
          isNull);
    });
  });

  group('U5 _drawLine / U6 measure / U7 _trailingSpaces', () {
    test('U5-B2 dòng chỉ gồm ký tự bề rộng 0 ⇒ không vẽ gì, hàm trả null', () {
      // Bằng chứng nhánh: bề rộng đo của U+200B bằng font Noto = 0 ⇒ _drawLine đi D1 Đ (w0 <= 0).
      final w0 = PdfFontSet(_fonts()).width(ScriptFace.latin, StyledSpan('', size: 26.4), '​');
      expect(w0, lessThanOrEqualTo(0), reason: 'dữ liệu phải đi nhánh w0 <= 0');
      final out = drawInvisibleTextLayer(
          _pdf(1), [_r([('​', const Rect.fromLTWH(10, 10, 400, 40))])], _fonts());
      final drawnText = out == null ? '' : _text(out);
      expect(drawnText.contains('​'), isFalse, reason: 'w0 <= 0 ⇒ không drawString');
      expect(out, isNull);
    });
    test('U7-B2 đoạn có dấu cách cuối (Latin + Hán) ⇒ cả hai đoạn đều vẽ; Hán thành dấu hỏi', () {
      final out = drawInvisibleTextLayer(
          _pdf(1), [_r([('Hà Nội 河内', const Rect.fromLTWH(10, 10, 600, 40))])], _fonts());
      expect(out, isNotNull);
      final t = _text(out!);
      expect(t, contains('Hà Nội'));
      // Đổi (bỏ font CJK): trước expect contains('河内'); nay đoạn Hán thành '??', đoạn Việt vẫn đúng.
      expect(t, isNot(contains('河')));
      expect(t, contains('?'));
    });
  });

  group('U8 addInvisibleTextLayer', () {
    test('U8-B1 có chữ, có font ⇒ PDF mới', () async {
      final out = await addInvisibleTextLayer(
          _pdf(1), [_r([('Tổng cộng', const Rect.fromLTWH(10, 10, 400, 40))])], const FileFontSource(_fontFiles));
      expect(out, isNotNull);
      expect(_text(out!), contains('Tổng cộng'));
    });
    test('U8-B2 không có chữ ⇒ null, không nạp font', () async {
      final fs = _CountFonts();
      final out = await addInvisibleTextLayer(_pdf(1), [OcrResult.empty], fs);
      expect(fs.n, 0);
      expect(out, isNull);
    });
    test('U8-B3 nạp font ném ⇒ null, không ném', () async {
      final r = await addInvisibleTextLayer(
              _pdf(1), [_r([('Hello', const Rect.fromLTWH(10, 10, 400, 40))])], _ThrowFonts())
          .then<Object?>((v) => v, onError: (Object e) => e);
      expect(r, isNull);
    });
  });
}
