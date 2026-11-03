import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf_layout/pdf_layout.dart' show LayoutLine, LayoutPage, LayoutRect;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/pdf/pdf_render_engine.dart';
import 'package:pdf_office/features/ppt_convert/engine/pdf_to_ppt.dart';
import 'package:pdf_office/features/ppt_convert/engine/text_eraser.dart';
import 'package:pptx_reader/pptx_reader.dart';

import 'pdf_to_ppt_test_fakes.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('pdf_to_ppt'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('mỗi trang thành 1 slide ảnh, cỡ slide theo trang 1, ghi trong isolate', () async {
    final render = FakePptRender(
      sizes: const [
        PdfPageSize(595, 842),
        PdfPageSize(842, 595),
        PdfPageSize(595, 842),
      ],
    );
    final out = p.join(tmp.path, 'report.pptx');
    final progress = <double>[];
    // Bộ ghi mặc định: Isolate.run thật.
    final converter = PdfToPptConverter(render: render);
    final saved = await converter.convert(
      inputPath: '/x/report.pdf',
      outputPath: out,
      password: 'pw',
      dpi: 200,
      onProgress: progress.add,
    );

    expect(saved, out);
    expect(render.openedPasswords, ['pw']);
    expect(render.closed, 1);
    expect(render.renders.map((r) => r.page), [0, 1, 2]);
    expect(render.renders.every((r) => r.dpi == 200), isTrue);
    expect(render.renders.every((r) => r.format == RenderFormat.jpg), isTrue);
    expect(progress.first, 0);
    expect(progress.last, 1);
    for (var i = 1; i < progress.length; i++) {
      expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
    }

    final deck = readPptx(File(out).readAsBytesSync());
    expect(deck.slides, hasLength(3));
    expect(deck.slideWidthEmu, 595 * 12700);
    expect(deck.slideHeightEmu, 842 * 12700);
    for (var i = 0; i < 3; i++) {
      final pic = deck.slides[i].shapes.whereType<PptxPictureShape>().single;
      expect(pic.bytes, fakeJpeg(i + 1));
    }
    // Trang 2 nằm ngang → vừa khít chiều rộng, nằm giữa theo chiều dọc.
    final landscape = deck.slides[1].shapes.whereType<PptxPictureShape>().single;
    expect(landscape.frame.cx, 595 * 12700);
    expect(landscape.frame.y, greaterThan(0));
    expect(File('$out.tmp').existsSync(), isFalse);
  });

  test('huỷ giữa chừng → Cancelled, không để lại file, vẫn đóng tài liệu', () async {
    final token = CancelToken();
    final render = FakePptRender(
      onRender: (page) {
        if (page == 0) token.cancel();
      },
    );
    final out = p.join(tmp.path, 'a.pptx');
    final converter = PdfToPptConverter(
      render: render,
      encode: syncPptxEncoder,
    );
    await expectLater(
      converter.convert(
        inputPath: '/x/a.pdf',
        outputPath: out,
        cancelToken: token,
      ),
      throwsA(isA<Cancelled>()),
    );
    expect(render.closed, 1);
    expect(render.renders, hasLength(1));
    expect(File(out).existsSync(), isFalse);
  });

  test('PDF không có trang → CorruptFile', () async {
    final render = FakePptRender(sizes: const []);
    final converter = PdfToPptConverter(
      render: render,
      encode: syncPptxEncoder,
    );
    await expectLater(
      converter.convert(
        inputPath: '/x/a.pdf',
        outputPath: p.join(tmp.path, 'a.pptx'),
      ),
      throwsA(isA<CorruptFile>()),
    );
    expect(render.closed, 1);
  });

  test('chữ của PDF thành hộp chữ trong suốt đúng chỗ trên slide (đọc lại bằng readPptx)', () async {
    // PDF thật có chữ Latin + Việt (dạng dựng sẵn) ở vị trí biết trước.
    final doc = sf.PdfDocument();
    doc.pageSettings.size = const Size(595, 842);
    doc.pageSettings.margins.all = 0;
    final page = doc.pages.add();
    final font = sf.PdfTrueTypeFont(
      File('assets/fonts/NotoSans-Regular.ttf').readAsBytesSync(),
      20,
    );
    page.graphics.drawString('Hello PowerPoint', font, bounds: const Rect.fromLTWH(60, 100, 0, 0));
    page.graphics.drawString('Tiếng Việt ặ ỗ', font, bounds: const Rect.fromLTWH(60, 300, 0, 0));
    final pdfPath = p.join(tmp.path, 'text.pdf');
    File(pdfPath).writeAsBytesSync(doc.saveSync());
    doc.dispose();

    final render = FakePptRender(sizes: const [PdfPageSize(595, 842)]);
    final out = p.join(tmp.path, 'text.pptx');
    await PdfToPptConverter(render: render).convert(inputPath: pdfPath, outputPath: out);

    final slide = readPptx(File(out).readAsBytesSync()).slides.single;
    expect(slide.shapes.whereType<PptxPictureShape>(), hasLength(1)); // ảnh vẫn là nền
    final boxes = slide.shapes.whereType<PptxTextShape>().toList();
    final texts = boxes.map((b) => b.paragraphs.single.text).toList();
    expect(texts, containsAll(['Hello PowerPoint', 'Tiếng Việt ặ ỗ']));
    final hello = boxes.firstWhere((b) => b.paragraphs.single.text == 'Hello PowerPoint');
    expect(hello.frame.x / 12700, closeTo(60, 3));
    expect(hello.frame.y / 12700, closeTo(100, 8));
    expect(hello.fill, isNull);
    // Chữ ẩn: alpha 0 (không còn noFill).
    expect(hello.paragraphs.single.runs.single.colorArgb! >>> 24, 0);
    expect(hello.paragraphs.single.runs.single.fontSizePt, closeTo(20, 2));
  });

  test('trang xoay / lệch tỉ lệ cỡ → không đặt chữ; trích chữ lỗi → vẫn ra PPTX ảnh', () async {
    const line = LayoutLine(
      pageIndex: 0,
      text: 'x',
      bounds: LayoutRect(left: 10, top: 10, width: 50, height: 12),
      fontSize: 12,
    );
    // Cỡ trích được là trang ngang nhưng ảnh render là trang dọc.
    expect(
      pptxTextBoxesFromPage(
        const LayoutPage(index: 0, width: 842, height: 595, lines: [line]),
        595,
        842,
      ),
      isEmpty,
    );
    // Cùng tỉ lệ nhưng render ở cỡ khác → toạ độ nhân theo tỉ lệ.
    final scaled = pptxTextBoxesFromPage(
      const LayoutPage(index: 0, width: 300, height: 400, lines: [line]),
      600,
      800,
    );
    expect(scaled.single.left, 20);
    expect(scaled.single.fontSizePt, 24);

    final render = FakePptRender(sizes: const [PdfPageSize(595, 842)]);
    final out = p.join(tmp.path, 'err.pptx');
    await PdfToPptConverter(
      render: render,
      extractText: (_, _) async => throw StateError('boom'),
    ).convert(inputPath: '/x/a.pdf', outputPath: out);
    final slide = readPptx(File(out).readAsBytesSync()).slides.single;
    expect(slide.shapes.whereType<PptxTextShape>(), isEmpty);
    expect(slide.shapes.whereType<PptxPictureShape>(), hasLength(1));
  });

  test('chế độ "Chữ sửa được": hộp chữ hiển thị đúng chỗ, ảnh nền đã xoá chữ', () async {
    final doc = sf.PdfDocument();
    doc.pageSettings.size = const Size(595, 842);
    doc.pageSettings.margins.all = 0;
    final page = doc.pages.add();
    final font = sf.PdfTrueTypeFont(
      File('assets/fonts/NotoSans-Regular.ttf').readAsBytesSync(),
      20,
    );
    page.graphics.drawString('Hello PowerPoint', font, bounds: const Rect.fromLTWH(60, 100, 0, 0));
    final pdfPath = p.join(tmp.path, 'edit.pdf');
    File(pdfPath).writeAsBytesSync(doc.saveSync());
    doc.dispose();

    // Trang "render" giả: nền trắng 595x842 px (1 px = 1 pt), chữ = khối đen đúng chỗ chữ.
    final fake = img.Image(width: 595, height: 842);
    img.fill(fake, color: img.ColorRgb8(255, 255, 255));
    img.fillRect(fake, x1: 62, y1: 104, x2: 190, y2: 120, color: img.ColorRgb8(0, 0, 0));
    final jpg = Uint8List.fromList(img.encodeJpg(fake, quality: 95));
    final render = FakePptRender(
      sizes: const [PdfPageSize(595, 842)],
      jpegFor: (_) => jpg,
    );
    final out = p.join(tmp.path, 'edit.pptx');
    final progress = <double>[];
    await PdfToPptConverter(render: render).convert(
      inputPath: pdfPath,
      outputPath: out,
      mode: PdfToPptMode.editableText,
      onProgress: progress.add,
    );
    expect(progress.last, 1);
    for (var i = 1; i < progress.length; i++) {
      expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
    }

    final slide = readPptx(File(out).readAsBytesSync()).slides.single;
    final box = slide.shapes
        .whereType<PptxTextShape>()
        .singleWhere((b) => b.paragraphs.single.text == 'Hello PowerPoint');
    final run = box.paragraphs.single.runs.single;
    expect(box.frame.x / 12700, closeTo(60, 3));
    expect(box.frame.y / 12700, closeTo(100, 8));
    expect(run.fontSizePt, closeTo(20, 2));
    expect(run.fontFamily, 'Noto Sans');
    expect(run.colorArgb! >>> 24, 0xFF, reason: 'chữ hiển thị, không trong suốt');
    expect((run.colorArgb! & 0xFFFFFF), lessThan(0x303030), reason: 'màu chữ đo được ~ đen');

    final bg = img.decodeJpg(slide.shapes.whereType<PptxPictureShape>().single.bytes)!;
    // Vùng chữ cũ giờ gần màu nền (trắng); chỗ khác không đổi.
    for (final (x, y) in [(70, 110), (120, 112), (185, 118)]) {
      expect(bg.getPixel(x, y).r.toInt(), greaterThan(235), reason: 'pixel ($x,$y)');
    }
    expect(bg.getPixel(400, 400).r.toInt(), greaterThan(235));
  });

  test('chế độ "Chữ sửa được": ảnh không giải mã được / trang lệch tỉ lệ → giữ nguyên hình', () async {
    final render = FakePptRender(sizes: const [PdfPageSize(595, 842)]);
    final out = p.join(tmp.path, 'fb.pptx');
    const line = LayoutLine(
      pageIndex: 0,
      text: 'abc',
      bounds: LayoutRect(left: 10, top: 10, width: 50, height: 12),
      fontSize: 12,
    );
    // JPEG giả không giải mã được → hộp ẩn như chế độ cũ, ảnh giữ nguyên.
    await PdfToPptConverter(
      render: render,
      encode: syncPptxEncoder,
      extractText: (_, _) async => const [
        LayoutPage(index: 0, width: 595, height: 842, lines: [line]),
      ],
    ).convert(inputPath: '/x/a.pdf', outputPath: out, mode: PdfToPptMode.editableText);
    var slide = readPptx(File(out).readAsBytesSync()).slides.single;
    expect(slide.shapes.whereType<PptxPictureShape>().single.bytes, fakeJpeg(1));
    final hidden = slide.shapes.whereType<PptxTextShape>().single;
    expect(hidden.paragraphs.single.runs.single.colorArgb! >>> 24, 0);

    // Trang xoay (cỡ trích lệch tỉ lệ) → không hộp chữ nào.
    await PdfToPptConverter(
      render: render,
      encode: syncPptxEncoder,
      extractText: (_, _) async => const [
        LayoutPage(index: 0, width: 842, height: 595, lines: [line]),
      ],
    ).convert(inputPath: '/x/a.pdf', outputPath: out, mode: PdfToPptMode.editableText);
    slide = readPptx(File(out).readAsBytesSync()).slides.single;
    expect(slide.shapes.whereType<PptxTextShape>(), isEmpty);
  });

  test('eraseTextFromJpeg: tô bằng màu nền lấy mẫu (nền xám), màu chữ đỏ đo được', () {
    final im = img.Image(width: 200, height: 100);
    img.fill(im, color: img.ColorRgb8(200, 200, 200));
    img.fillRect(im, x1: 50, y1: 40, x2: 120, y2: 55, color: img.ColorRgb8(220, 20, 20));
    final r = eraseTextFromJpeg(
      Uint8List.fromList(img.encodeJpg(im, quality: 98)),
      const [PixelBox(48, 38, 76, 20)],
      widthUnits: 200,
      heightUnits: 100,
    )!;
    expect(r.textColors.single >> 16, greaterThan(180));
    expect(r.textColors.single & 0xFF, lessThan(80));
    final out = img.decodeJpg(r.bytes)!;
    final c = out.getPixel(85, 47);
    expect((c.r.toInt() - 200).abs(), lessThan(12));
    expect((c.g.toInt() - 200).abs(), lessThan(12));
    expect(eraseTextFromJpeg(Uint8List.fromList([1, 2, 3]), const [], widthUnits: 1, heightUnits: 1), isNull);
  });
}
