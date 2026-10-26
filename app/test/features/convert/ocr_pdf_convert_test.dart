import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/ocr/ocr_engine.dart';
import 'package:pdf_office/engines/pdf/pdf_render_engine.dart';
import 'package:pdf_office/features/convert/engine/font_set.dart';
import 'package:pdf_office/features/convert/engine/ocr_pdf_convert_engine.dart';
import 'package:pdf_office/features/convert/engine/pdf_convert_engine.dart';
import 'package:pdf_office/features/convert/ocr/ocr_to_layout.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

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

class _FakeOcr implements OcrEngine {
  _FakeOcr(this.results);
  final List<OcrResult> results;
  final calls = <String>[];
  final scripts = <OcrScript>[];
  bool existedWhenCalled = true;

  @override
  Future<OcrResult> recognize(String imagePath, OcrScript script) async {
    existedWhenCalled = existedWhenCalled && File(imagePath).existsSync();
    calls.add(imagePath);
    scripts.add(script);
    return results[(calls.length - 1) % results.length];
  }

  @override
  Future<void> dispose() async {}
}

class _FakeDoc implements PdfRenderDocument {
  _FakeDoc(this.sizes);
  final List<PdfPageSize> sizes;
  final rendered = <(int, double)>[];
  bool closed = false;

  @override
  int get pageCount => sizes.length;
  @override
  Future<PdfPageSize> pageSize(int i) async => sizes[i];
  @override
  Future<Uint8List> renderPage(int i,
      {double dpi = 150,
      RenderFormat format = RenderFormat.png,
      int jpgQuality = 90,
      CancelToken? cancelToken}) async {
    rendered.add((i, dpi));
    return Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
  }

  @override
  Future<Uint8List> renderThumbnail(int i, {int maxSide = 300}) async => Uint8List(0);
  @override
  Future<void> close() async => closed = true;
}

class _FakeRender implements PdfRenderEngine {
  _FakeRender(this.doc);
  final _FakeDoc doc;
  String? password;
  @override
  Future<PdfRenderDocument> openFile(String path, {String? password}) async {
    this.password = password;
    return doc;
  }

  @override
  Future<PdfRenderDocument> openBytes(Uint8List bytes) async => doc;
}

/// PDF 2 trang: trang 1 có chữ thật (font chuẩn), trang 2 chỉ có hình (không chữ).
String _mixedPdf(String path, {bool textPage = true}) {
  final doc = sf.PdfDocument();
  doc.pageSettings.size = const Size(595, 842);
  final first = doc.pages.add();
  if (textPage) {
    first.graphics.drawString(
      'Real text page',
      sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 14),
      bounds: Rect.fromLTWH(40, 40, 300, 30),
    );
  } else {
    first.graphics.drawRectangle(
        brush: sf.PdfBrushes.gray, bounds: Rect.fromLTWH(40, 40, 100, 100));
  }
  final second = doc.pages.add();
  second.graphics.drawRectangle(
      brush: sf.PdfBrushes.lightGray, bounds: Rect.fromLTWH(10, 10, 200, 200));
  File(path).writeAsBytesSync(doc.saveSync());
  doc.dispose();
  return path;
}

void main() {
  group('ocrResultToLayoutPage / ocrRenderDpi (hàm thuần)', () {
    test('đổi pixel -> point theo tỉ lệ trang và cỡ ảnh', () {
      final r = _ocr([('Xin chào', const Rect.fromLTWH(100, 200, 500, 70))]);
      final page = ocrResultToLayoutPage(r, pageIndex: 3, pageWidth: 500, pageHeight: 700);
      expect(page.index, 3);
      final l = page.lines.single;
      expect(l.pageIndex, 3);
      expect(l.text, 'Xin chào');
      expect(l.bounds.left, closeTo(50, 1e-9)); // 100 * 500/1000
      expect(l.bounds.top, closeTo(100, 1e-9)); // 200 * 700/1400
      expect(l.bounds.width, closeTo(250, 1e-9));
      expect(l.bounds.height, closeTo(35, 1e-9));
      expect(l.fontSize, closeTo(35 * ocrFontSizeRatio, 1e-9));
    });

    test('NFD tiếng Việt được chuẩn hoá NFC, bỏ dòng rỗng', () {
      final r = _ocr([
        ('Tiếng Việt', const Rect.fromLTWH(0, 0, 400, 50)),
        ('   ', const Rect.fromLTWH(0, 60, 400, 50)),
      ]);
      final page = ocrResultToLayoutPage(r, pageIndex: 0, pageWidth: 1000, pageHeight: 1400);
      expect(page.lines.length, 1);
      expect(page.lines.single.text, 'Tiếng Việt');
    });

    test('sắp thứ tự đọc: trên xuống, cùng hàng trái sang phải', () {
      final r = _ocr([
        ('dòng ba', const Rect.fromLTWH(0, 300, 100, 40)),
        ('phải', const Rect.fromLTWH(500, 102, 100, 40)),
        ('trái', const Rect.fromLTWH(0, 100, 100, 40)),
      ]);
      final page = ocrResultToLayoutPage(r, pageIndex: 0, pageWidth: 1000, pageHeight: 1400);
      expect(page.lines.map((l) => l.text), ['trái', 'phải', 'dòng ba']);
    });

    test('block không có dòng dùng chữ của block; không có kích thước ảnh -> 200 dpi', () {
      final r = OcrResult(
        text: 'abc',
        blocks: const [OcrBlock('a\nb', Rect.fromLTWH(200, 200, 400, 100), [])],
      );
      final page = ocrResultToLayoutPage(r, pageIndex: 0, pageWidth: 595, pageHeight: 842);
      expect(page.lines.single.text, 'a b');
      expect(page.lines.single.bounds.left, closeTo(200 * 72 / 200, 1e-9));
    });

    test('ocrRenderDpi giới hạn cạnh dài 2560px', () {
      expect(ocrRenderDpi(595, 842), closeTo(200, 1e-9)); // 842pt@200dpi = 2339px
      final big = ocrRenderDpi(2000, 3000); // 3000pt = 41.67in
      expect(big, lessThan(200));
      expect(3000 / 72 * big, closeTo(2560, 1e-6));
    });
  });

  group('OcrPdfConvertEngine (OCR giả)', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('ocr_conv_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    OcrPdfConvertEngine make(_FakeOcr ocr, _FakeRender render,
            {OcrScript script = OcrScript.latin}) =>
        OcrPdfConvertEngine(
          inner: const PdfConvertEngine(fontSource: NoFontSource(), useIsolate: false),
          render: render,
          ocr: ocr,
          scriptProvider: () => script,
          tempDir: p.join(tmp.path, 'work'),
        );

    _FakeRender renderFor(int n) => _FakeRender(
        _FakeDoc(List.filled(n, const PdfPageSize(595, 842))));

    test('chỉ OCR trang không có chữ, giữ nguyên chữ thật; dọn file tạm', () async {
      final input = _mixedPdf(p.join(tmp.path, 'in.pdf'));
      final ocr = _FakeOcr([
        _ocr([('Tiếng Việt quét', const Rect.fromLTWH(100, 100, 600, 60))])
      ]);
      final render = renderFor(2);
      final progress = <double>[];
      final out = await make(ocr, render, script: OcrScript.korean)
          .pdfToText(input, p.join(tmp.path, 'o.txt'), onProgress: progress.add);
      final text = File(out).readAsStringSync();
      expect(text, contains('Real text page'));
      expect(text, contains('Tiếng Việt quét'));
      expect(ocr.calls.length, 1);
      expect(ocr.scripts.single, OcrScript.korean);
      expect(ocr.existedWhenCalled, isTrue);
      expect(render.doc.rendered.single.$1, 1);
      expect(render.doc.rendered.single.$2, closeTo(200, 1e-9));
      expect(render.doc.closed, isTrue);
      expect(Directory(p.join(tmp.path, 'work')).listSync(), isEmpty);
      expect(progress.last, 1);
      expect(progress, orderedEquals([...progress]..sort()));
    });

    test('PDF ảnh hoàn toàn -> DOCX và XLSX từ kết quả OCR', () async {
      final input = _mixedPdf(p.join(tmp.path, 'scan.pdf'), textPage: false);
      final ocr = _FakeOcr([
        _ocr([('Hoá đơn', const Rect.fromLTWH(100, 100, 600, 60))]),
        _ocr([('Tổng cộng', const Rect.fromLTWH(100, 100, 600, 60))]),
      ]);
      final engine = make(ocr, renderFor(2));
      final docx = await engine.pdfToDocx(input, p.join(tmp.path, 'o.docx'));
      expect(File(docx).lengthSync(), greaterThan(500));
      final xlsx = await engine.pdfToXlsx(input, p.join(tmp.path, 'o.xlsx'));
      expect(File(xlsx).lengthSync(), greaterThan(500));
      expect(ocr.calls.length, 4);
    });

    test('OCR không ra chữ -> NoTextFound', () async {
      final input = _mixedPdf(p.join(tmp.path, 'scan.pdf'), textPage: false);
      final ocr = _FakeOcr([OcrResult.empty]);
      expect(
        make(ocr, renderFor(2)).pdfToText(input, p.join(tmp.path, 'o.txt')),
        throwsA(predicate(isNoTextError)),
      );
    });

    test('truyền mật khẩu cho bộ render; huỷ giữa chừng -> Cancelled', () async {
      final input = _mixedPdf(p.join(tmp.path, 'scan.pdf'), textPage: false);
      final ocr = _FakeOcr([_ocr([('x', const Rect.fromLTWH(0, 0, 10, 10))])]);
      final render = renderFor(2);
      final token = CancelToken();
      final engine = make(ocr, render);
      final f = engine.pdfToText(input, p.join(tmp.path, 'o.txt'),
          cancelToken: token, onProgress: (v) {
        if (v >= 0.1 + 0.8 * 0.5) token.cancel();
      });
      await expectLater(f, throwsA(isA<Cancelled>()));
      expect(render.doc.closed, isTrue);
      expect(Directory(p.join(tmp.path, 'work')).listSync(), isEmpty);
    });

    test('PDF toàn chữ thật: không gọi OCR hay render', () async {
      final doc = sf.PdfDocument();
      doc.pages.add().graphics.drawString(
          'Only text', sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 14),
          bounds: Rect.fromLTWH(40, 40, 300, 30));
      final input = p.join(tmp.path, 't.pdf');
      File(input).writeAsBytesSync(doc.saveSync());
      doc.dispose();
      final ocr = _FakeOcr([OcrResult.empty]);
      final render = renderFor(1);
      final out = await make(ocr, render).pdfToText(input, p.join(tmp.path, 'o.txt'));
      expect(File(out).readAsStringSync(), contains('Only text'));
      expect(ocr.calls, isEmpty);
      expect(render.doc.rendered, isEmpty);
    });
  });
}
