import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_ops/image_ops.dart' as ops;
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/pdf/image_to_pdf_engine.dart';
import 'package:pdf_office/engines/pdf/syncfusion_image_to_pdf_engine.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

Uint8List _jpeg(int w, int h, {int r = 200, int g = 80, int b = 40}) {
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8(r, g, b));
  return Uint8List.fromList(img.encodeJpg(im, quality: 90));
}

void main() {
  late Directory tmp;
  const engine = SyncfusionImageToPdfEngine();

  setUp(() => tmp = Directory.systemTemp.createTempSync('img2pdf_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  String write(String name, List<int> bytes) {
    final f = File(p.join(tmp.path, name))..writeAsBytesSync(bytes);
    return f.path;
  }

  sf.PdfDocument open(String path) =>
      sf.PdfDocument(inputBytes: File(path).readAsBytesSync());

  group('planImagePage', () {
    test('A4 ảnh ngang tự xoay trang ngang và lấp đầy vùng trừ lề', () {
      final pl = planImagePage(
        imageWidth: 400,
        imageHeight: 200,
        options: const ImageToPdfOptions(margin: PageMargin.small),
      );
      expect(pl.pageWidth, closeTo(841.89, 0.01));
      expect(pl.pageHeight, closeTo(595.28, 0.01));
      expect(pl.imageWidth, closeTo(841.89 - 36, 0.01));
      expect(pl.imageLeft, closeTo(18, 0.01));
    });

    test('hướng cố định dọc dù ảnh ngang', () {
      final pl = planImagePage(
        imageWidth: 400,
        imageHeight: 200,
        options: const ImageToPdfOptions(orientation: PageOrientation.portrait),
      );
      expect(pl.pageWidth, closeTo(595.28, 0.01));
    });

    test('Letter', () {
      final pl = planImagePage(
        imageWidth: 100,
        imageHeight: 200,
        options: const ImageToPdfOptions(pageSize: PageSizeOption.letter),
      );
      expect(pl.pageWidth, 612);
      expect(pl.pageHeight, 792);
    });

    test('Vừa ảnh: trang ôm sát ảnh + lề', () {
      final pl = planImagePage(
        imageWidth: 300,
        imageHeight: 150,
        options: const ImageToPdfOptions(
          pageSize: PageSizeOption.fit,
          margin: PageMargin.large,
        ),
      );
      expect(pl.pageWidth, closeTo(pl.imageWidth + 72, 0.01));
      expect(pl.pageHeight, closeTo(pl.imageHeight + 72, 0.01));
      expect(pl.imageWidth / pl.imageHeight, closeTo(2, 0.001));
    });
  });

  group('createPdf', () {
    test('mỗi ảnh một trang, đúng khổ A4 dọc/ngang theo ảnh', () async {
      final a = write('a.jpg', _jpeg(200, 300));
      final b = write('b.jpg', _jpeg(300, 200));
      final out = p.join(tmp.path, 'out.pdf');
      final progress = <double>[];
      final r = await engine.createPdf(
        imagePaths: [a, b],
        outputPath: out,
        onProgress: progress.add,
      );
      expect(r.pageCount, 2);
      expect(r.outputPath, out);
      expect(r.skippedImages, isEmpty);
      expect(progress.last, closeTo(1, 1e-9));
      final doc = open(out);
      expect(doc.pages.count, 2);
      expect(doc.pages[0].size.width, closeTo(595.28, 0.5));
      expect(doc.pages[0].size.height, closeTo(841.89, 0.5));
      expect(doc.pages[1].size.width, closeTo(841.89, 0.5));
      expect(doc.pages[1].size.height, closeTo(595.28, 0.5));
      doc.dispose();
    });

    test('nhận PNG (có alpha) và WebP', () async {
      final png = img.Image(width: 50, height: 50, numChannels: 4);
      img.fill(png, color: img.ColorRgba8(0, 0, 255, 128));
      final webp = img.Image(width: 60, height: 40);
      img.fill(webp, color: img.ColorRgb8(10, 200, 10));
      final a = write('a.png', img.encodePng(png));
      final b = write('b.webp', img.encodeWebP(webp));
      final out = p.join(tmp.path, 'out.pdf');
      final r = await engine.createPdf(imagePaths: [a, b], outputPath: out);
      expect(r.pageCount, 2);
      final doc = open(out);
      expect(doc.pages.count, 2);
      doc.dispose();
    });

    test('Vừa ảnh: kích thước trang theo ảnh', () async {
      final a = write('a.jpg', _jpeg(300, 150));
      final out = p.join(tmp.path, 'out.pdf');
      await engine.createPdf(
        imagePaths: [a],
        outputPath: out,
        options: const ImageToPdfOptions(pageSize: PageSizeOption.fit),
      );
      final doc = open(out);
      final s = doc.pages[0].size;
      expect(s.width / s.height, closeTo(2, 0.01));
      doc.dispose();
    });

    test('ảnh hỏng bị bỏ qua và được báo', () async {
      final a = write('a.jpg', _jpeg(100, 100));
      final bad = write('bad.jpg', [1, 2, 3, 4]);
      final out = p.join(tmp.path, 'out.pdf');
      final r = await engine.createPdf(imagePaths: [bad, a], outputPath: out);
      expect(r.pageCount, 1);
      expect(r.skippedImages, [bad]);
    });

    test('mọi ảnh hỏng → CorruptFile, không tạo file', () async {
      final bad = write('bad.jpg', [1, 2, 3, 4]);
      final out = p.join(tmp.path, 'out.pdf');
      await expectLater(
        engine.createPdf(imagePaths: [bad], outputPath: out),
        throwsA(isA<CorruptFile>()),
      );
      expect(File(out).existsSync(), isFalse);
      expect(File('$out.tmp').existsSync(), isFalse);
    });

    test('danh sách rỗng → CorruptFile', () async {
      await expectLater(
        engine.createPdf(
          imagePaths: const [],
          outputPath: p.join(tmp.path, 'x.pdf'),
        ),
        throwsA(isA<CorruptFile>()),
      );
    });

    test('huỷ giữa chừng → Cancelled, không để file dở', () async {
      final paths = [
        for (var i = 0; i < 4; i++) write('i$i.jpg', _jpeg(120, 160)),
      ];
      final out = p.join(tmp.path, 'out.pdf');
      final token = CancelToken();
      await expectLater(
        engine.createPdf(
          imagePaths: paths,
          outputPath: out,
          cancelToken: token,
          onProgress: (v) {
            if (v >= 0.5) token.cancel();
          },
        ),
        throwsA(isA<Cancelled>()),
      );
      expect(File(out).existsSync(), isFalse);
      expect(File('$out.tmp').existsSync(), isFalse);
    });

    test('đã huỷ từ trước → Cancelled ngay', () async {
      final a = write('a.jpg', _jpeg(50, 50));
      final token = CancelToken()..cancel();
      await expectLater(
        engine.createPdf(
          imagePaths: [a],
          outputPath: p.join(tmp.path, 'o.pdf'),
          cancelToken: token,
        ),
        throwsA(isA<Cancelled>()),
      );
    });

    test('chất lượng thấp cho PDF nhỏ hơn', () async {
      // Ảnh nhiễu để nén có ý nghĩa.
      final im = img.Image(width: 600, height: 600);
      var s = 7;
      for (final px in im) {
        s = (s * 1103515245 + 12345) & 0x7fffffff;
        px
          ..r = s & 255
          ..g = (s >> 8) & 255
          ..b = (s >> 16) & 255;
      }
      final a = write('n.jpg', img.encodeJpg(im, quality: 100));
      final hi = p.join(tmp.path, 'hi.pdf');
      final lo = p.join(tmp.path, 'lo.pdf');
      await engine.createPdf(
        imagePaths: [a],
        outputPath: hi,
        options: const ImageToPdfOptions(jpegQuality: 95),
      );
      await engine.createPdf(
        imagePaths: [a],
        outputPath: lo,
        options: const ImageToPdfOptions(jpegQuality: 30),
      );
      expect(File(lo).lengthSync(), lessThan(File(hi).lengthSync()));
    });
  });

  group('createPdfFromInputs', () {
    test('áp xoay 90° → trang chuyển từ ngang sang dọc', () async {
      final a = write('a.jpg', _jpeg(300, 200));
      final out = p.join(tmp.path, 'out.pdf');
      await engine.createPdfFromInputs(
        inputs: [
          ImageToPdfInput(a, const ops.ImageEdit(rotationQuarterTurns: 1)),
        ],
        outputPath: out,
      );
      final doc = open(out);
      expect(doc.pages[0].size.height, greaterThan(doc.pages[0].size.width));
      doc.dispose();
    });
  });
}
