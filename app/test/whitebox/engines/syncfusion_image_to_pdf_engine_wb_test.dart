// Kiểm thử hộp trắng A11 — lib/engines/pdf/syncfusion_image_to_pdf_engine.dart.
// Mã bộ = mã ở test-output/whitebox/engines/syncfusion_image_to_pdf_engine/buoc-5-du-lieu-thu.md.
import 'dart:async';
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

Uint8List _jpeg(int w, int h) {
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8(200, 80, 40));
  return Uint8List.fromList(img.encodeJpg(im, quality: 90));
}

Future<Object?> _capture(Future<Object?> f) =>
    f.then((v) => v, onError: (Object e) => e);

void main() {
  late Directory tmp;
  const engine = SyncfusionImageToPdfEngine();

  setUp(() => tmp = Directory.systemTemp.createTempSync('wb_a11_img2pdf_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  String write(String name, List<int> bytes) =>
      (File(p.join(tmp.path, name))..writeAsBytesSync(bytes)).path;

  sf.PdfDocument open(String path) =>
      sf.PdfDocument(inputBytes: File(path).readAsBytesSync());

  void expectNoOutput(String out) {
    expect(File(out).existsSync(), isFalse, reason: 'không để file kết quả');
    expect(File('$out.tmp').existsSync(), isFalse, reason: 'không để file dở');
  }

  // ---------------- U1 planImagePage ----------------
  group('U1 planImagePage', () {
    test('PI-1 A4 / tự động / không lề, ảnh dọc ⇒ A4 dọc, ảnh lấp đầy, căn giữa (P1 Đ, O1 Đ, M1 Đ, F S)', () {
      final pl = planImagePage(
        imageWidth: 200,
        imageHeight: 300,
        options: const ImageToPdfOptions(),
      );
      expect(pl.pageWidth, closeTo(595.28, 0.01));
      expect(pl.pageHeight, closeTo(841.89, 0.01));
      expect(pl.imageHeight, closeTo(841.89, 0.01));
      expect(pl.imageWidth / pl.imageHeight, closeTo(2 / 3, 0.001));
      expect(pl.imageLeft, closeTo((pl.pageWidth - pl.imageWidth) / 2, 0.01));
      expect(pl.imageTop, closeTo(0, 0.01));
    });
    test('PI-2 Letter ⇒ trang 612×792 (P2 Đ)', () {
      final pl = planImagePage(
        imageWidth: 100,
        imageHeight: 200,
        options: const ImageToPdfOptions(pageSize: PageSizeOption.letter),
      );
      expect((pl.pageWidth, pl.pageHeight), (612.0, 792.0));
    });
    test('PI-3 Vừa ảnh, không lề ⇒ trang = ảnh ở 150 dpi (P2 S, F Đ)', () {
      final pl = planImagePage(
        imageWidth: 300,
        imageHeight: 150,
        options: const ImageToPdfOptions(pageSize: PageSizeOption.fit),
      );
      expect(pl.pageWidth, closeTo(144, 0.01));
      expect(pl.pageHeight, closeTo(72, 0.01));
      expect(pl.imageLeft, closeTo(0, 0.01));
    });
    test('PI-4 hướng dọc cố định, ảnh ngang ⇒ trang dọc (O1 S, O2 Đ)', () {
      final pl = planImagePage(
        imageWidth: 400,
        imageHeight: 200,
        options: const ImageToPdfOptions(orientation: PageOrientation.portrait),
      );
      expect(pl.pageWidth, closeTo(595.28, 0.01));
      expect(pl.pageHeight, closeTo(841.89, 0.01));
    });
    test('PI-5 hướng ngang cố định, ảnh dọc ⇒ trang ngang (O2 S)', () {
      final pl = planImagePage(
        imageWidth: 200,
        imageHeight: 400,
        options: const ImageToPdfOptions(orientation: PageOrientation.landscape),
      );
      expect(pl.pageWidth, closeTo(841.89, 0.01));
      expect(pl.pageHeight, closeTo(595.28, 0.01));
    });
    test('PI-6 lề nhỏ 18pt ⇒ ảnh nằm trong vùng trừ lề (M1 S, M2 Đ)', () {
      final pl = planImagePage(
        imageWidth: 400,
        imageHeight: 200,
        options: const ImageToPdfOptions(margin: PageMargin.small),
      );
      expect(pl.pageWidth, closeTo(841.89, 0.01));
      expect(pl.imageLeft, closeTo(18, 0.01));
      expect(pl.imageWidth, closeTo(841.89 - 36, 0.01));
    });
    test('PI-7 lề lớn 36pt ⇒ ảnh nằm trong vùng trừ lề (M2 S)', () {
      final pl = planImagePage(
        imageWidth: 400,
        imageHeight: 200,
        options: const ImageToPdfOptions(margin: PageMargin.large),
      );
      expect(pl.imageLeft, closeTo(36, 0.01));
      expect(pl.imageWidth, closeTo(841.89 - 72, 0.01));
    });
  });

  // ---------------- U2 _prepare (qua createPdfFromInputs, khổ Vừa ảnh, không lề) ----------------
  group('U2 _prepare', () {
    const fit = ImageToPdfOptions(pageSize: PageSizeOption.fit);

    /// Chiều rộng trang (point) = cạnh dài ảnh đã nhúng × 72 / 150.
    Future<double> pageWidthFor(ops.ImageEdit edit) async {
      final a = write('wide.jpg', _jpeg(3200, 200));
      final out = p.join(tmp.path, 'o_${edit.maxLongSide}.pdf');
      await engine.createPdfFromInputs(
        inputs: [ImageToPdfInput(a, edit)],
        outputPath: out,
        options: fit,
      );
      final d = open(out);
      final w = d.pages[0].size.width;
      d.dispose();
      return w;
    }

    test('PR-1 không đặt maxLongSide ⇒ thu về 3000px (Q1 S)', () async {
      expect(await pageWidthFor(const ops.ImageEdit()), closeTo(1440, 1));
    });
    test('PR-2 maxLongSide 1000 < 3000 ⇒ giữ 1000px (Q1 Đ, Q2 Đ)', () async {
      expect(
        await pageWidthFor(const ops.ImageEdit(maxLongSide: 1000)),
        closeTo(480, 1),
      );
    });
    test('PR-2b biên: maxLongSide 0 ⇒ vẫn không vượt 3000px (Q2 Đ)', () async {
      expect(
        await pageWidthFor(const ops.ImageEdit(maxLongSide: 0)),
        lessThanOrEqualTo(1440 + 1),
      );
    });
    test('PR-3 maxLongSide 5000 ≥ 3000 ⇒ thu về 3000px (Q2 S)', () async {
      expect(
        await pageWidthFor(const ops.ImageEdit(maxLongSide: 5000)),
        closeTo(1440, 1),
      );
    });
    test('PR-4 file ảnh không tồn tại ⇒ bị bỏ qua và báo (Q0 Đ)', () async {
      final good = write('g.jpg', _jpeg(100, 100));
      final missing = p.join(tmp.path, 'missing.jpg');
      final out = p.join(tmp.path, 'o.pdf');
      final r = await engine.createPdf(imagePaths: [missing, good], outputPath: out);
      expect(r.skippedImages, [missing]);
      expect(r.pageCount, 1);
    });
    test('PR-5 bytes ảnh hỏng ⇒ bị bỏ qua và báo (Q3 Đ)', () async {
      final good = write('g.jpg', _jpeg(100, 100));
      final bad = write('bad.jpg', [1, 2, 3, 4]);
      final out = p.join(tmp.path, 'o.pdf');
      final r = await engine.createPdf(imagePaths: [bad, good], outputPath: out);
      expect(r.skippedImages, [bad]);
      expect(r.pageCount, 1);
    });
  });

  // ---------------- U3 createPdfFromInputs ----------------
  group('U3 createPdfFromInputs', () {
    List<ImageToPdfInput> inputs(List<String> paths) =>
        [for (final x in paths) ImageToPdfInput(x)];

    test('CP-1 1 ảnh dọc, không token/tiến độ ⇒ 1 trang A4 dọc (đường gốc)', () async {
      final a = write('a.jpg', _jpeg(200, 300));
      final out = p.join(tmp.path, 'out.pdf');
      final r = await engine.createPdfFromInputs(inputs: inputs([a]), outputPath: out);
      expect(r.pageCount, 1);
      expect(r.outputPath, out);
      expect(r.skippedImages, isEmpty);
      final d = open(out);
      expect(d.pages.count, 1);
      expect(d.pages[0].size.width, closeTo(595.28, 0.5));
      expect(d.pages[0].size.height, closeTo(841.89, 0.5));
      d.dispose();
    });
    test('CP-2 danh sách rỗng ⇒ CorruptFile (C1 Đ)', () async {
      final out = p.join(tmp.path, 'out.pdf');
      final r = await _capture(engine.createPdfFromInputs(inputs: const [], outputPath: out));
      expect(r, isA<CorruptFile>());
      expectNoOutput(out);
    });
    test('CP-3 ảnh ngang ⇒ trang ngang (C11 Đ)', () async {
      final a = write('a.jpg', _jpeg(300, 200));
      final out = p.join(tmp.path, 'out.pdf');
      await engine.createPdfFromInputs(inputs: inputs([a]), outputPath: out);
      final d = open(out);
      expect(d.pages[0].size.width, closeTo(841.89, 0.5));
      expect(d.pages[0].size.height, closeTo(595.28, 0.5));
      d.dispose();
    });
    test('CP-4 2 ảnh + onProgress ⇒ báo 0.5 rồi 1.0 (C12 S)', () async {
      final a = write('a.jpg', _jpeg(200, 300));
      final b = write('b.jpg', _jpeg(200, 300));
      final out = p.join(tmp.path, 'out.pdf');
      final prog = <double>[];
      final r = await engine.createPdfFromInputs(
        inputs: inputs([a, b]),
        outputPath: out,
        onProgress: prog.add,
      );
      expect(prog, [0.5, 1.0]);
      expect(r.pageCount, 2);
    });
    test('CP-5 ảnh duy nhất hỏng ⇒ CorruptFile, không tạo file (C7 Đ, C8 Đ, C13 Đ, C19 Đ)', () async {
      final bad = write('bad.jpg', [1, 2, 3, 4]);
      final out = p.join(tmp.path, 'out.pdf');
      final r = await _capture(engine.createPdfFromInputs(inputs: inputs([bad]), outputPath: out));
      expect(r, isA<CorruptFile>());
      expectNoOutput(out);
    });
    test('CP-6 ảnh duy nhất hỏng + onProgress ⇒ vẫn báo 1.0 rồi CorruptFile (C8 S)', () async {
      final bad = write('bad.jpg', [1, 2, 3, 4]);
      final out = p.join(tmp.path, 'out.pdf');
      final prog = <double>[];
      final r = await _capture(engine.createPdfFromInputs(
        inputs: inputs([bad]),
        outputPath: out,
        onProgress: prog.add,
      ));
      expect(prog, [1.0]);
      expect(r, isA<CorruptFile>());
    });
    test('CP-7 token chưa huỷ + onProgress ⇒ xong bình thường (C2 S, C3/C6/C10/C15/C17 S)', () async {
      final a = write('a.jpg', _jpeg(200, 300));
      final b = write('b.jpg', _jpeg(200, 300));
      final out = p.join(tmp.path, 'out.pdf');
      final prog = <double>[];
      final r = await engine.createPdfFromInputs(
        inputs: inputs([a, b]),
        outputPath: out,
        onProgress: prog.add,
        cancelToken: CancelToken(),
      );
      expect(prog, [0.5, 1.0]);
      expect(r.pageCount, 2);
      expect(File(out).existsSync(), isTrue);
    });
    test('CP-8 token đã huỷ trước ⇒ Cancelled ngay, không báo tiến độ (C3 Đ)', () async {
      final a = write('a.jpg', _jpeg(200, 300));
      final out = p.join(tmp.path, 'out.pdf');
      final prog = <double>[];
      final r = await _capture(engine.createPdfFromInputs(
        inputs: inputs([a]),
        outputPath: out,
        onProgress: prog.add,
        cancelToken: CancelToken()..cancel(),
      ));
      expect(prog, isEmpty);
      expect(r, isA<Cancelled>());
      expectNoOutput(out);
    });
    test('CP-9 huỷ sau ảnh 1 (trong onProgress) ⇒ Cancelled ở đầu vòng 2 (C6 Đ)', () async {
      final a = write('a.jpg', _jpeg(200, 300));
      final b = write('b.jpg', _jpeg(200, 300));
      final out = p.join(tmp.path, 'out.pdf');
      final token = CancelToken();
      final prog = <double>[];
      final r = await _capture(engine.createPdfFromInputs(
        inputs: inputs([a, b]),
        outputPath: out,
        cancelToken: token,
        onProgress: (v) {
          prog.add(v);
          token.cancel();
        },
      ));
      expect(prog, [0.5]);
      expect(r, isA<Cancelled>());
      expectNoOutput(out);
    });
    test('CP-10 huỷ trong lúc xử lý ảnh ⇒ Cancelled trước khi thêm trang (C10 Đ)', () async {
      final a = write('a.jpg', _jpeg(200, 300));
      final b = write('b.jpg', _jpeg(200, 300));
      final out = p.join(tmp.path, 'out.pdf');
      final token = CancelToken();
      final prog = <double>[];
      final f = _capture(engine.createPdfFromInputs(
        inputs: inputs([a, b]),
        outputPath: out,
        cancelToken: token,
        onProgress: prog.add,
      ));
      token.cancel(); // dòng 116 và 123 đã qua đồng bộ; đang chờ Isolate.run
      final r = await f;
      expect(prog, isEmpty);
      expect(r, isA<Cancelled>());
      expectNoOutput(out);
    });
    test('CP-11 huỷ khi báo 1.0 ⇒ Cancelled trước khi lưu (C15 Đ)', () async {
      final a = write('a.jpg', _jpeg(200, 300));
      final b = write('b.jpg', _jpeg(200, 300));
      final out = p.join(tmp.path, 'out.pdf');
      final token = CancelToken();
      final prog = <double>[];
      final r = await _capture(engine.createPdfFromInputs(
        inputs: inputs([a, b]),
        outputPath: out,
        cancelToken: token,
        onProgress: (v) {
          prog.add(v);
          if (v >= 1) token.cancel();
        },
      ));
      expect(prog, [0.5, 1.0]);
      expect(r, isA<Cancelled>());
      expectNoOutput(out);
    });
    test('CP-12 huỷ trong lúc doc.save() ⇒ Cancelled trước khi ghi file (C17 Đ)', () async {
      final a = write('a.jpg', _jpeg(200, 300));
      final b = write('b.jpg', _jpeg(200, 300));
      final out = p.join(tmp.path, 'out.pdf');
      final token = CancelToken();
      var cancelledAtLastProgress = true;
      final r = await _capture(engine.createPdfFromInputs(
        inputs: inputs([a, b]),
        outputPath: out,
        cancelToken: token,
        onProgress: (v) {
          if (v >= 1) {
            scheduleMicrotask(token.cancel); // chạy sau dòng 161, trước dòng 163
            cancelledAtLastProgress = token.isCancelled;
          }
        },
      ));
      expect(cancelledAtLastProgress, isFalse);
      expect(r, isA<Cancelled>());
      expectNoOutput(out);
    });
    test('CP-13 không ghi được file đích ⇒ lỗi được đổi thành AppError (C18 Đ, C19 S)', () async {
      final a = write('a.jpg', _jpeg(200, 300));
      final blocker = write('blocker', [0]); // file thường đứng chỗ thư mục cha
      final out = p.join(blocker, 'out.pdf');
      final r = await _capture(engine.createPdfFromInputs(inputs: inputs([a]), outputPath: out));
      expect(r, isNot(isA<FileSystemException>()));
      expect(r, isA<AppError>());
    });
    test('CP-14 [hỏng, tốt] ⇒ 1 trang, báo ảnh bị bỏ (C4 Đ lần 2, C13 S)', () async {
      final bad = write('bad.jpg', [9, 9, 9]);
      final good = write('g.jpg', _jpeg(200, 300));
      final out = p.join(tmp.path, 'out.pdf');
      final r = await engine.createPdfFromInputs(inputs: inputs([bad, good]), outputPath: out);
      expect(r.skippedImages, [bad]);
      expect(r.pageCount, 1);
      final d = open(out);
      expect(d.pages.count, 1);
      d.dispose();
    });
  });
}
