import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_ops/image_ops.dart' as ops;
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/pdf/image_to_pdf_engine.dart';
import 'package:pdf_office/engines/pdf/syncfusion_image_to_pdf_engine.dart';
import 'package:pdf_office/features/image_to_pdf/models/image_item.dart';
import 'package:pdf_office/features/image_to_pdf/services/export_service.dart';
import 'package:pdf_office/features/image_to_pdf/services/image_processor.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

Uint8List _jpeg(int w, int h) {
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8(30, 120, 200));
  return Uint8List.fromList(img.encodeJpg(im, quality: 90));
}

void main() {
  late Directory tmp;
  late Directory out;
  late Directory work;
  late ImageToPdfExporter exporter;
  var nextId = 0;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('img2pdf_export');
    out = Directory(p.join(tmp.path, 'out'))..createSync();
    work = Directory(p.join(tmp.path, 'work'))..createSync();
    exporter = ImageToPdfExporter(
      engine: const SyncfusionImageToPdfEngine(),
      processor: const IsolateImageProcessor(),
      workDir: work,
    );
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  ImageItem item(
    String name,
    int w,
    int h, {
    ops.ImageEdit edit = const ops.ImageEdit(),
    List<int>? bytes,
  }) {
    final path = p.join(tmp.path, name);
    File(path).writeAsBytesSync(bytes ?? _jpeg(w, h));
    return ImageItem(
      id: nextId++,
      originalPath: path,
      originalWidth: w,
      originalHeight: h,
      edit: edit,
    );
  }

  sf.PdfDocument open(String path) =>
      sf.PdfDocument(inputBytes: File(path).readAsBytesSync());

  test('ảnh chưa sửa + ảnh đã xoay: đúng số trang, xoay làm đổi hướng trang', () async {
    final a = item('a.jpg', 300, 200); // ngang
    final b = item(
      'b.jpg',
      300,
      200,
      edit: const ops.ImageEdit(rotationQuarterTurns: 1), // thành dọc
    );
    final progress = <double>[];
    final r = await exporter.export(
      items: [a, b],
      options: const ImageToPdfOptions(),
      outputDir: out.path,
      fileName: 'result',
      onProgress: progress.add,
    );
    expect(r.pageCount, 2);
    expect(r.skippedCount, 0);
    expect(p.basename(r.outputPath), 'result.pdf');
    expect(r.sizeBytes, File(r.outputPath).lengthSync());
    expect(progress, isNotEmpty);
    expect(progress.last, closeTo(1, 1e-9));
    expect(
      [for (var i = 1; i < progress.length; i++) progress[i] >= progress[i - 1]],
      everyElement(isTrue),
      reason: 'tiến độ không lùi',
    );
    final doc = open(r.outputPath);
    expect(doc.pages.count, 2);
    expect(doc.pages[0].size.width, greaterThan(doc.pages[0].size.height));
    expect(doc.pages[1].size.height, greaterThan(doc.pages[1].size.width));
    doc.dispose();
    expect(work.listSync(), isEmpty, reason: 'file tạm đã được dọn');
  });

  test('đặt tên trùng thì thêm (1), không ghi đè file cũ', () async {
    final a = item('a.jpg', 100, 100);
    final r1 = await exporter.export(
      items: [a],
      options: const ImageToPdfOptions(),
      outputDir: out.path,
      fileName: 'same',
    );
    final first = File(r1.outputPath).readAsBytesSync();
    final r2 = await exporter.export(
      items: [a],
      options: const ImageToPdfOptions(),
      outputDir: out.path,
      fileName: 'same',
    );
    expect(p.basename(r1.outputPath), 'same.pdf');
    expect(p.basename(r2.outputPath), 'same (1).pdf');
    expect(File(r1.outputPath).readAsBytesSync(), first);
  });

  test('ảnh hỏng bị bỏ qua và đếm vào skippedCount', () async {
    final good = item('g.jpg', 100, 100);
    final bad = item('bad.jpg', 10, 10, bytes: [1, 2, 3, 4]);
    final badEdited = item(
      'bad2.jpg',
      10,
      10,
      bytes: [9, 9, 9],
      edit: const ops.ImageEdit(rotationQuarterTurns: 1),
    );
    final r = await exporter.export(
      items: [bad, good, badEdited],
      options: const ImageToPdfOptions(),
      outputDir: out.path,
      fileName: 'x',
    );
    expect(r.pageCount, 1);
    expect(r.skippedCount, 2);
  });

  test('toàn bộ ảnh hỏng → CorruptFile, không để file dở', () async {
    final bad = item(
      'bad.jpg',
      10,
      10,
      bytes: [1, 2],
      edit: const ops.ImageEdit(rotationQuarterTurns: 1),
    );
    await expectLater(
      exporter.export(
        items: [bad],
        options: const ImageToPdfOptions(),
        outputDir: out.path,
        fileName: 'x',
      ),
      throwsA(isA<CorruptFile>()),
    );
    expect(out.listSync(), isEmpty);
    expect(work.listSync(), isEmpty);
  });

  test('danh sách rỗng → CorruptFile', () async {
    await expectLater(
      exporter.export(
        items: const [],
        options: const ImageToPdfOptions(),
        outputDir: out.path,
        fileName: 'x',
      ),
      throwsA(isA<CorruptFile>()),
    );
  });

  test('huỷ giữa chừng → Cancelled, không file PDF, không file tạm', () async {
    final items = [
      for (var i = 0; i < 4; i++)
        item(
          'c$i.jpg',
          200,
          150,
          edit: const ops.ImageEdit(rotationQuarterTurns: 1),
        ),
    ];
    final token = CancelToken();
    await expectLater(
      exporter.export(
        items: items,
        options: const ImageToPdfOptions(),
        outputDir: out.path,
        fileName: 'x',
        cancelToken: token,
        onProgress: (v) {
          if (v > 0) token.cancel();
        },
      ),
      throwsA(isA<Cancelled>()),
    );
    expect(out.listSync(), isEmpty);
    expect(work.listSync(), isEmpty);
  });

  test('chất lượng/khổ giấy truyền xuống engine: Letter', () async {
    final a = item('a.jpg', 100, 200);
    final r = await exporter.export(
      items: [a],
      options: const ImageToPdfOptions(pageSize: PageSizeOption.letter),
      outputDir: out.path,
      fileName: 'letter',
    );
    final doc = open(r.outputPath);
    expect(doc.pages[0].size.width, closeTo(612, 0.5));
    expect(doc.pages[0].size.height, closeTo(792, 0.5));
    doc.dispose();
  });

  group('normalizePdfName', () {
    test('bỏ đuôi .pdf và khoảng trắng', () {
      expect(normalizePdfName('  Báo cáo.PDF ', fallback: 'f'), 'Báo cáo');
      expect(normalizePdfName('a.pdf.pdf', fallback: 'f'), 'a.pdf');
    });

    test('rỗng thì dùng tên dự phòng', () {
      expect(normalizePdfName('   ', fallback: 'fb'), 'fb');
      expect(normalizePdfName('.pdf', fallback: 'fb'), 'fb');
    });
  });
}
