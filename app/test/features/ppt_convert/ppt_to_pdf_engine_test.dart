import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/core/utils/cancel_token.dart';
import 'package:pdf_office/features/ppt_convert/engine/ppt_to_pdf.dart';
import 'package:pptx_reader/pptx_reader.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

PptxSlide _slide(int i, {bool hidden = false}) => PptxSlide(
  index: i,
  background: null,
  shapes: const [],
  notesText: null,
  hidden: hidden,
);

/// 16:9 kiểu cũ (10 × 5.625 inch = 720 × 405 pt); slide 1 ẩn.
PptxDeck _deck({int w = 9144000, int h = 5143500}) => PptxDeck(
  slideWidthEmu: w,
  slideHeightEmu: h,
  slides: [_slide(0), _slide(1, hidden: true), _slide(2), _slide(3)],
);

/// Bộ chụp giả: trả PNG nhỏ, ghi lại slide + dpi đã yêu cầu.
class _FakeRasterizer implements SlideRasterizer {
  _FakeRasterizer({this.onRender});

  final void Function(int callIndex)? onRender;
  final List<int> slides = [];
  final List<int> dpis = [];

  static final Uint8List _png = Uint8List.fromList(
    img.encodePng(
      img.Image(width: 16, height: 9)..clear(img.ColorRgb8(200, 30, 30)),
    ),
  );

  @override
  Future<Uint8List> renderSlide(
    PptxDeck deck,
    PptxSlide slide, {
    required int dpi,
  }) async {
    onRender?.call(slides.length);
    slides.add(slide.index);
    dpis.add(dpi);
    return _png;
  }
}

void main() {
  group('hàm thuần', () {
    test('slidesToExport bỏ slide ẩn mặc định, giữ thứ tự', () {
      final deck = _deck();
      expect(slidesToExport(deck), [0, 2, 3]);
      expect(slidesToExport(deck, includeHidden: true), [0, 1, 2, 3]);
      expect(hiddenSlideCount(deck), 1);
    });

    test('slidesToExport: tất cả ẩn → rỗng', () {
      final deck = PptxDeck(
        slideWidthEmu: 9144000,
        slideHeightEmu: 5143500,
        slides: [_slide(0, hidden: true)],
      );
      expect(slidesToExport(deck), isEmpty);
      expect(slidesToExport(deck, includeHidden: true), [0]);
    });

    test('pdfPageSizeOf: EMU → pt, đúng tỉ lệ slide', () {
      expect(pdfPageSizeOf(_deck()), const Size(720, 405));
      expect(
        pdfPageSizeOf(_deck(w: 12192000, h: 6858000)),
        const Size(960, 540),
      );
      // Slide dọc (A4 portrait 210 × 297 mm).
      final a4 = pdfPageSizeOf(_deck(w: 7560000, h: 10692000));
      expect(a4.width, closeTo(595.28, 0.01));
      expect(a4.height, closeTo(841.89, 0.01));
    });

    test('pdfPageSizeOf: kích thước hỏng → 16:9 mặc định', () {
      expect(pdfPageSizeOf(_deck(w: 0, h: 0)), kFallbackSlidePageSize);
      expect(pdfPageSizeOf(_deck(w: 9144000, h: -5)), kFallbackSlidePageSize);
    });

    test('slidePixelRatio + chất lượng', () {
      expect(PptPdfQuality.standard.dpi, 150);
      expect(PptPdfQuality.high.dpi, 200);
      expect(slidePixelRatio(72), 1);
      // 720 pt ở 150 dpi = 1500 px.
      expect(720 * slidePixelRatio(150), closeTo(1500, 1e-9));
    });

    test('ensurePptxPath: chỉ nhận .pptx', () {
      expect(() => ensurePptxPath('/a/b.pptx'), returnsNormally);
      expect(() => ensurePptxPath('/a/B.PPTX'), returnsNormally);
      expect(
        () => ensurePptxPath('/a/cu.ppt'),
        throwsA(
          isA<UnsupportedFormat>().having((e) => e.extension, 'ext', 'ppt'),
        ),
      );
      expect(
        () => ensurePptxPath('/a/x.key'),
        throwsA(
          isA<UnsupportedFormat>().having((e) => e.extension, 'ext', 'key'),
        ),
      );
    });

    test('pptToPdfBaseName', () {
      expect(pptToPdfBaseName('/x/Bao cao Q3.pptx'), 'Bao cao Q3');
    });
  });

  group('DefaultPptToPdfEngine', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('pptpdf_t'));
    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('openDeck: .ppt → UnsupportedFormat, không gọi loader', () async {
      var called = 0;
      final engine = DefaultPptToPdfEngine(
        loader: (_) async {
          called++;
          return _deck();
        },
      );
      await expectLater(
        engine.openDeck('/a/old.ppt'),
        throwsA(isA<UnsupportedFormat>()),
      );
      expect(called, 0);
      await engine.openDeck('/a/new.pptx');
      expect(called, 1);
    });

    test('mỗi slide hiển thị một trang, khổ trang = khổ slide', () async {
      final out = p.join(dir.path, 'deck.pdf');
      final r = _FakeRasterizer();
      final progress = <double>[];
      final path = await const DefaultPptToPdfEngine().convert(
        _deck(),
        out,
        rasterizer: r,
        options: const PptToPdfOptions(quality: PptPdfQuality.high),
        onProgress: progress.add,
      );
      expect(path, out);
      expect(r.slides, [0, 2, 3]);
      expect(r.dpis, everyElement(200));
      expect(progress, isNotEmpty);
      expect(progress.last, closeTo(1, 1e-9));
      for (var i = 1; i < progress.length; i++) {
        expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
      }
      expect(File('$out.tmp').existsSync(), isFalse);

      final doc = sf.PdfDocument(inputBytes: File(out).readAsBytesSync());
      try {
        expect(doc.pages.count, 3);
        final size = doc.pages[0].size;
        expect(size.width, closeTo(720, 0.5));
        expect(size.height, closeTo(405, 0.5));
      } finally {
        doc.dispose();
      }
    });

    test('includeHidden → cả slide ẩn', () async {
      final out = p.join(dir.path, 'all.pdf');
      final r = _FakeRasterizer();
      await const DefaultPptToPdfEngine().convert(
        _deck(),
        out,
        rasterizer: r,
        options: const PptToPdfOptions(includeHidden: true),
      );
      expect(r.slides, [0, 1, 2, 3]);
      expect(r.dpis, everyElement(150));
      final doc = sf.PdfDocument(inputBytes: File(out).readAsBytesSync());
      expect(doc.pages.count, 4);
      doc.dispose();
    });

    test('không còn slide nào → CorruptFile, không ghi file', () async {
      final out = p.join(dir.path, 'none.pdf');
      final deck = PptxDeck(
        slideWidthEmu: 9144000,
        slideHeightEmu: 5143500,
        slides: [_slide(0, hidden: true)],
      );
      await expectLater(
        const DefaultPptToPdfEngine().convert(
          deck,
          out,
          rasterizer: _FakeRasterizer(),
        ),
        throwsA(isA<CorruptFile>()),
      );
      expect(File(out).existsSync(), isFalse);
    });

    test('huỷ giữa chừng → Cancelled, không để lại file', () async {
      final out = p.join(dir.path, 'cancel.pdf');
      final token = CancelToken();
      final r = _FakeRasterizer(
        onRender: (i) {
          if (i == 1) token.cancel();
        },
      );
      await expectLater(
        const DefaultPptToPdfEngine().convert(
          _deck(),
          out,
          rasterizer: r,
          cancelToken: token,
        ),
        throwsA(isA<Cancelled>()),
      );
      expect(r.slides.length, 2);
      expect(File(out).existsSync(), isFalse);
      expect(File('$out.tmp').existsSync(), isFalse);
    });
  });
}
