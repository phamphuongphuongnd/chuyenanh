import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_ops/image_ops.dart' as ops;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/ocr/ocr_engine.dart';
import 'package:pdf_office/engines/pdf/image_to_pdf_engine.dart';
import 'package:pdf_office/features/scanner/export/scan_exporter.dart';
import 'package:pdf_office/features/scanner/model/scan_page.dart';

class FakePdf implements ImageToPdfEngine {
  List<String>? paths;
  @override
  Future<ImageToPdfResult> createPdf({
    required List<String> imagePaths,
    required String outputPath,
    ImageToPdfOptions options = const ImageToPdfOptions(),
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    // Ảnh phải còn tồn tại lúc engine chạy.
    for (final p in imagePaths) {
      expect(File(p).existsSync(), isTrue, reason: p);
    }
    paths = imagePaths;
    File(outputPath).writeAsStringSync('%PDF-fake');
    onProgress?.call(1);
    return ImageToPdfResult(
      outputPath: outputPath,
      pageCount: imagePaths.length,
    );
  }
}

class FakeOcr implements OcrEngine {
  final seen = <String>[];
  @override
  Future<OcrResult> recognize(String imagePath, OcrScript script) async {
    seen.add(imagePath);
    final t = 'Trang ${seen.length} Nguyễn Ngữ';
    return OcrResult(
      text: t,
      blocks: [
        OcrBlock(t, const Rect.fromLTWH(0, 0, 10, 10), [
          OcrLine(t, const Rect.fromLTWH(0, 0, 10, 10)),
        ]),
      ],
    );
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  late Directory dir;
  late String out, tmp, src;
  late FakePdf pdf;
  late FakeOcr ocr;
  late List<ops.ImageEdit> renderedEdits;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('scan_exp_');
    out = '${dir.path}/out';
    tmp = '${dir.path}/tmp';
    src = '${dir.path}/src.jpg';
    File(src).writeAsBytesSync(img.encodeJpg(img.Image(width: 20, height: 10)));
    pdf = FakePdf();
    ocr = FakeOcr();
    renderedEdits = [];
  });
  tearDown(() => dir.deleteSync(recursive: true));

  ScanExporter make() => ScanExporter(
    pdfEngine: pdf,
    ocrEngine: ocr,
    outputDir: out,
    tempDir: tmp,
    now: () => DateTime(2026, 10, 26, 9, 5, 7),
    renderer: (path, edit) async {
      renderedEdits.add(edit);
      return img.encodeJpg(img.Image(width: 4, height: 4));
    },
  );

  List<ScanPage> pages() => [
    ScanPage(id: 'a', path: src),
    ScanPage(id: 'b', path: src, quarterTurns: 1),
    ScanPage(id: 'c', path: src, filter: ops.ImageFilter.grayscale),
  ];

  test('tên mặc định theo thời gian', () {
    expect(make().defaultBaseName(), 'Scan_20261026_090507');
  });

  test(
    'PDF: trang chưa sửa dùng file gốc, trang đã sửa render; xoá tạm',
    () async {
      final r = await make().exportPdf(pages());
      expect(r.pageCount, 3);
      expect(r.outputPath, endsWith('Scan_20261026_090507.pdf'));
      expect(pdf.paths![0], src);
      expect(pdf.paths![1], isNot(src));
      expect(renderedEdits, hasLength(2));
      expect(renderedEdits[0].rotationQuarterTurns, 1);
      expect(renderedEdits[1].filter, ops.ImageFilter.grayscale);
      // thư mục tạm con đã dọn
      expect(Directory(tmp).listSync(), isEmpty);
    },
  );

  test('không ghi đè: lần hai thành "(1)"', () async {
    final e = make();
    await e.exportPdf(pages());
    final r2 = await e.exportPdf(pages());
    expect(r2.outputPath, endsWith('Scan_20261026_090507 (1).pdf'));
  });

  test('PDF không có trang → CorruptFile', () {
    expect(make().exportPdf([]), throwsA(isA<CorruptFile>()));
  });

  test('huỷ trước khi xong → Cancelled, chưa tạo PDF', () async {
    final t = CancelToken()..cancel();
    await expectLater(
      make().exportPdf(pages(), cancelToken: t),
      throwsA(isA<Cancelled>()),
    );
    expect(pdf.paths, isNull);
  });

  test('TXT: OCR từng trang, ghi UTF-8 giữ dấu', () async {
    final r = await make().exportTxt(pages(), OcrScript.latin);
    expect(r.outputPath, endsWith('.txt'));
    final text = File(r.outputPath).readAsStringSync();
    expect(
      text,
      'Trang 1 Nguyễn Ngữ\n\nTrang 2 Nguyễn Ngữ\n\nTrang 3 Nguyễn Ngữ',
    );
    expect(ocr.seen, hasLength(3));
    // OCR luôn qua ảnh đã xoay, không áp lọc màu
    expect(
      renderedEdits.every((e) => e.filter == ops.ImageFilter.original),
      isTrue,
    );
    expect(renderedEdits[1].rotationQuarterTurns, 1);
    expect(renderedEdits.first.maxLongSide, ScanExporter.ocrLongSide);
  });

  test('DOCX: file zip hợp lệ chứa chữ OCR và ngắt trang', () async {
    final r = await make().exportDocx(pages(), OcrScript.latin);
    expect(r.outputPath, endsWith('.docx'));
    final zip = ZipDecoder().decodeBytes(File(r.outputPath).readAsBytesSync());
    final doc = zip.files.firstWhere((f) => f.name == 'word/document.xml');
    final xml = String.fromCharCodes(doc.content as List<int>);
    final decoded = const Utf8Decoder().convert(doc.content as List<int>);
    expect(xml.isNotEmpty, isTrue);
    expect(decoded, contains('Nguyễn Ngữ'));
    expect(RegExp('w:br w:type="page"').allMatches(decoded).length, 2);
  });

  test('OCR không ra chữ → hasText=false nhưng vẫn ghi file', () async {
    final e = ScanExporter(
      pdfEngine: pdf,
      ocrEngine: _EmptyOcr(),
      outputDir: out,
      tempDir: tmp,
      renderer: (p, e) async => img.encodeJpg(img.Image(width: 4, height: 4)),
    );
    final r = await e.exportTxt(pages(), OcrScript.latin);
    expect(r.hasText, isFalse);
    expect(File(r.outputPath).existsSync(), isTrue);
  });
}

class _EmptyOcr implements OcrEngine {
  @override
  Future<OcrResult> recognize(String imagePath, OcrScript script) async =>
      OcrResult.empty;
  @override
  Future<void> dispose() async {}
}
