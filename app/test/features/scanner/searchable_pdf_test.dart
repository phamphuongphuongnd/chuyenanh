import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/ocr/ocr_engine.dart';
import 'package:pdf_office/engines/pdf/image_to_pdf_engine.dart';
import 'package:pdf_office/features/convert/engine/font_set.dart';
import 'package:pdf_office/features/scanner/export/scan_exporter.dart';
import 'package:pdf_office/features/scanner/export/searchable_pdf.dart';
import 'package:pdf_office/features/scanner/model/scan_page.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

const _fontFiles = {
  FontSlot.regular: 'assets/fonts/NotoSans-Regular.ttf',
  FontSlot.chinese: 'assets/fonts/NotoSansSC-Regular.ttf',
  FontSlot.japanese: 'assets/fonts/NotoSansJP-Regular.ttf',
  FontSlot.korean: 'assets/fonts/NotoSansKR-Regular.ttf',
};
final _hasFonts = _fontFiles.values.every((f) => File(f).existsSync());
final _skipNoFonts = _hasFonts ? null : 'cần chạy tool/fetch_fonts.sh (thiếu app/assets/fonts/*.ttf)';

Map<FontSlot, Uint8List> _fonts() =>
    {for (final e in _fontFiles.entries) e.key: File(e.value).readAsBytesSync()};

OcrResult _ocr(List<(String, Rect)> lines, {int w = 1000, int h = 1400}) => OcrResult(
      text: lines.map((e) => e.$1).join('\n'),
      blocks: [
        OcrBlock(lines.map((e) => e.$1).join('\n'), Rect.zero, [
          for (final l in lines) OcrLine(l.$1, l.$2),
        ]),
      ],
      imageWidth: w,
      imageHeight: h,
    );

/// PDF "ảnh quét": mỗi trang chỉ có một hình chữ nhật (không có chữ).
Uint8List _imageOnlyPdf(int pages, {Size size = const Size(595, 842)}) {
  final doc = sf.PdfDocument();
  doc.pageSettings.size = size;
  for (var i = 0; i < pages; i++) {
    doc.pages.add().graphics.drawRectangle(
        brush: sf.PdfBrushes.lightGray, bounds: Rect.fromLTWH(0, 0, size.width, size.height));
  }
  final bytes = Uint8List.fromList(doc.saveSync());
  doc.dispose();
  return bytes;
}

String _text(Uint8List pdf, {int? page}) {
  final doc = sf.PdfDocument(inputBytes: pdf);
  try {
    final ex = sf.PdfTextExtractor(doc);
    return page == null
        ? ex.extractText()
        : ex.extractText(startPageIndex: page, endPageIndex: page);
  } finally {
    doc.dispose();
  }
}

class _FakePdfEngine implements ImageToPdfEngine {
  _FakePdfEngine(this.pages);
  final int pages;
  @override
  Future<ImageToPdfResult> createPdf({
    required List<String> imagePaths,
    required String outputPath,
    ImageToPdfOptions options = const ImageToPdfOptions(),
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    File(outputPath).writeAsBytesSync(_imageOnlyPdf(pages));
    return ImageToPdfResult(outputPath: outputPath, pageCount: pages);
  }
}

class _FakeOcr implements OcrEngine {
  _FakeOcr(this.results, {this.fail = false});
  final List<OcrResult> results;
  final bool fail;
  var n = 0;
  @override
  Future<OcrResult> recognize(String imagePath, OcrScript script) async {
    if (fail) throw const CorruptFile('boom');
    return results[n++ % results.length];
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  group('placeOcrLines (hàm thuần)', () {
    test('ảnh khớp tỉ lệ trang: chỉ co giãn', () {
      final r = _ocr([('abc', const Rect.fromLTWH(100, 140, 500, 70))]);
      final l = placeOcrLines(r, 500, 700).single;
      expect(l.left, closeTo(50, 1e-9));
      expect(l.top, closeTo(70, 1e-9));
      expect(l.width, closeTo(250, 1e-9));
      expect(l.height, closeTo(35, 1e-9));
    });

    test('ảnh ngang đặt giữa trang dọc (có viền trên dưới)', () {
      // ảnh 1000x500 trong trang 500x700 → s = 0.5, ảnh cao 250, lệch (700-250)/2 = 225
      final r = _ocr([('abc', const Rect.fromLTWH(0, 0, 1000, 100))], w: 1000, h: 500);
      final l = placeOcrLines(r, 500, 700).single;
      expect(l.left, closeTo(0, 1e-9));
      expect(l.top, closeTo(225, 1e-9));
      expect(l.width, closeTo(500, 1e-9));
    });

    test('NFD -> NFC, bỏ dòng rỗng, thiếu kích thước ảnh -> rỗng', () {
      final r = _ocr([
        ('Việt', const Rect.fromLTWH(0, 0, 100, 20)),
        (' ', const Rect.fromLTWH(0, 30, 100, 20)),
      ]);
      expect(placeOcrLines(r, 100, 100).map((e) => e.text), ['Việt']);
      expect(
        placeOcrLines(const OcrResult(text: 'x', blocks: [OcrBlock('x', Rect.fromLTWH(0, 0, 5, 5), [])]), 100, 100),
        isEmpty,
      );
    });
  });

  group('drawInvisibleTextLayer', () {
    test('thiếu font -> null (không làm hỏng)', () {
      final pdf = _imageOnlyPdf(1);
      final r = _ocr([('Hello', const Rect.fromLTWH(10, 10, 200, 40))]);
      expect(drawInvisibleTextLayer(pdf, [r], const {}), isNull);
    });

    test('số trang không khớp -> null', skip: _skipNoFonts, () {
      final r = _ocr([('Hello', const Rect.fromLTWH(10, 10, 200, 40))]);
      expect(drawInvisibleTextLayer(_imageOnlyPdf(2), [r], _fonts()), isNull);
    });

    test('trích lại đúng chữ Việt NFC theo từng trang; PDF mở được', skip: _skipNoFonts, () {
      final pdf = _imageOnlyPdf(2);
      final p1 = _ocr([
        // NFD cố ý: lớp chữ phải chuẩn hoá NFC.
        ('Nguyễn Thị Phượng', const Rect.fromLTWH(100, 100, 600, 60)),
        ('Tiếng Việt ặ ỗ ữ ẫ ậ ề ở', const Rect.fromLTWH(100, 200, 700, 60)),
      ]);
      final p2 = _ocr([('Second page 2026', const Rect.fromLTWH(100, 100, 500, 60))]);
      final out = drawInvisibleTextLayer(pdf, [p1, p2], _fonts());
      expect(out, isNotNull);
      final t1 = _text(out!, page: 0);
      expect(t1, contains('Nguyễn Thị Phượng'));
      expect(t1, contains('Tiếng Việt ặ ỗ ữ ẫ ậ ề ở'));
      expect(_text(out, page: 1), contains('Second page 2026'));
      expect(_text(out, page: 1), isNot(contains('Nguyễn')));
      // vẫn là PDF 2 trang mở lại được; font được subset nên không phình to
      final doc = sf.PdfDocument(inputBytes: out);
      expect(doc.pages.count, 2);
      doc.dispose();
      expect(out.length, lessThan(600000));
    });

    test('dòng trộn Latin + Hán + Hangul + kana', skip: _skipNoFonts, () {
      final r = _ocr([('Hà Nội 河内 하노이 ハノイ', const Rect.fromLTWH(100, 100, 700, 60))]);
      final out = drawInvisibleTextLayer(_imageOnlyPdf(1), [r], _fonts());
      expect(out, isNotNull);
      final t = _text(out!);
      expect(t, contains('Hà Nội'));
      expect(t, contains('河内'));
      expect(t, contains('하노이'));
      expect(t, contains('ハノイ'));
    });
  });

  group('ScanExporter.exportPdf searchable', () {
    late Directory dir;
    late String src;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('scan_srch_');
      src = '${dir.path}/src.jpg';
      File(src).writeAsBytesSync(img.encodeJpg(img.Image(width: 20, height: 10)));
    });
    tearDown(() => dir.deleteSync(recursive: true));

    ScanExporter make(OcrEngine ocr, FontSource fonts) => ScanExporter(
          pdfEngine: _FakePdfEngine(2),
          ocrEngine: ocr,
          outputDir: '${dir.path}/out',
          tempDir: '${dir.path}/tmp',
          fontSource: fonts,
          renderer: (path, edit) async => img.encodeJpg(img.Image(width: 4, height: 4)),
        );

    final pages = [
      ScanPage(id: 'a', path: ''),
      ScanPage(id: 'b', path: ''),
    ];
    List<ScanPage> withSrc() => [for (final p in pages) ScanPage(id: p.id, path: src)];

    test('bật: PDF có lớp chữ tìm được', skip: _skipNoFonts, () async {
      final ocr = _FakeOcr([
        _ocr([('Hóa đơn bán hàng', const Rect.fromLTWH(100, 100, 600, 60))]),
        _ocr([('Tổng cộng 1.000đ', const Rect.fromLTWH(100, 100, 600, 60))]),
      ]);
      final progress = <double>[];
      final r = await make(ocr, const FileFontSource(_fontFiles))
          .exportPdf(withSrc(), searchable: true, onProgress: progress.add);
      expect(r.textLayer, isTrue);
      final bytes = File(r.outputPath).readAsBytesSync();
      expect(_text(bytes, page: 0), contains('Hóa đơn bán hàng'));
      expect(_text(bytes, page: 1), contains('Tổng cộng 1.000đ'));
      expect(progress.last, 1);
      expect(progress, orderedEquals([...progress]..sort()));
    });

    test('tắt: không OCR, PDF không có chữ', () async {
      final ocr = _FakeOcr([_ocr([('x', const Rect.fromLTWH(0, 0, 10, 10))])]);
      final r = await make(ocr, const NoFontSource()).exportPdf(withSrc());
      expect(r.textLayer, isFalse);
      expect(ocr.n, 0);
      expect(_text(File(r.outputPath).readAsBytesSync()).trim(), isEmpty);
    });

    test('thiếu font: vẫn xuất PDF ảnh, không có lớp chữ', () async {
      final ocr = _FakeOcr([_ocr([('Hello', const Rect.fromLTWH(100, 100, 600, 60))])]);
      final r = await make(ocr, const NoFontSource()).exportPdf(withSrc(), searchable: true);
      expect(r.textLayer, isFalse);
      final doc = sf.PdfDocument(inputBytes: File(r.outputPath).readAsBytesSync());
      expect(doc.pages.count, 2);
      doc.dispose();
    });

    test('OCR lỗi: vẫn xuất PDF ảnh', () async {
      final r = await make(_FakeOcr(const [], fail: true), const NoFontSource())
          .exportPdf(withSrc(), searchable: true);
      expect(r.textLayer, isFalse);
      expect(File(r.outputPath).existsSync(), isTrue);
    });

    test('huỷ khi đang OCR -> Cancelled', () async {
      final token = CancelToken();
      final ocr = _FakeOcr([_ocr([('x', const Rect.fromLTWH(0, 0, 10, 10))])]);
      final f = make(ocr, const NoFontSource()).exportPdf(
        withSrc(),
        searchable: true,
        cancelToken: token,
        onProgress: (v) {
          if (v > 0.3) token.cancel();
        },
      );
      await expectLater(f, throwsA(isA<Cancelled>()));
    });
  });
}
