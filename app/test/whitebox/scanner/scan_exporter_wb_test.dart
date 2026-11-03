// Kiểm thử hộp trắng A07 — scanner/scan_exporter.dart (Bước 6).
// Mã bộ = <đơn vị>-<đường> theo test-output/whitebox/scanner/scan_exporter/buoc-5-du-lieu-thu.md.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_ops/image_ops.dart' as ops;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/ocr/ocr_engine.dart';
import 'package:pdf_office/engines/pdf/image_to_pdf_engine.dart';
import 'package:pdf_office/features/convert/engine/font_set.dart';
import 'package:pdf_office/features/scanner/export/scan_exporter.dart';
import 'package:pdf_office/features/scanner/model/scan_page.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

const _fontFiles = {
  FontSlot.regular: 'assets/fonts/NotoSans-Regular.ttf',
};

Uint8List _imageOnlyPdf(int pages) {
  final doc = sf.PdfDocument();
  for (var i = 0; i < pages; i++) {
    doc.pages.add().graphics.drawRectangle(
        brush: sf.PdfBrushes.lightGray, bounds: const Rect.fromLTWH(0, 0, 100, 100));
  }
  final b = Uint8List.fromList(doc.saveSync());
  doc.dispose();
  return b;
}

String _pdfText(String path) {
  final doc = sf.PdfDocument(inputBytes: File(path).readAsBytesSync());
  try {
    return sf.PdfTextExtractor(doc).extractText();
  } finally {
    doc.dispose();
  }
}

/// Engine PDF giả: ghi PDF ảnh thật (mỗi ảnh 1 trang) và ghi lại lời gọi.
class _Pdf implements ImageToPdfEngine {
  _Pdf({this.onCreate, this.throwError, this.writeFile = true, this.cancelAfter = false});
  final void Function(List<String> paths)? onCreate;
  final Object? throwError;
  final bool writeFile;
  final bool cancelAfter;
  List<String>? paths;
  String? outputPath;
  int calls = 0;

  @override
  Future<ImageToPdfResult> createPdf({
    required List<String> imagePaths,
    required String outputPath,
    ImageToPdfOptions options = const ImageToPdfOptions(),
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    calls++;
    paths = List.of(imagePaths);
    this.outputPath = outputPath;
    onCreate?.call(imagePaths);
    if (throwError != null) throw throwError!;
    if (writeFile) File(outputPath).writeAsBytesSync(_imageOnlyPdf(imagePaths.length));
    onProgress?.call(1);
    if (cancelAfter) cancelToken?.cancel();
    return ImageToPdfResult(outputPath: outputPath, pageCount: imagePaths.length);
  }
}

class _Ocr implements OcrEngine {
  _Ocr({this.error, this.onRecognize});
  final Object? error;
  final void Function(int n)? onRecognize;
  final seen = <String>[];

  @override
  Future<OcrResult> recognize(String imagePath, OcrScript script) async {
    seen.add(imagePath);
    onRecognize?.call(seen.length);
    if (error != null) throw error!;
    const t = 'Hóa đơn bán hàng';
    return const OcrResult(
      text: t,
      blocks: [
        OcrBlock(t, Rect.fromLTWH(100, 100, 600, 60), [OcrLine(t, Rect.fromLTWH(100, 100, 600, 60))]),
      ],
      imageWidth: 1000,
      imageHeight: 1400,
    );
  }

  @override
  Future<void> dispose() async {}
}

final _png = Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 4)));
final _jpg = Uint8List.fromList(img.encodeJpg(img.Image(width: 4, height: 4)));

void main() {
  late Directory dir;
  late String out, tmp, src;
  late _Pdf pdf;
  late _Ocr ocr;
  late List<ops.ImageEdit> renders;
  late Uint8List renderBytes;
  Object? renderError;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('wb_scan_exp_');
    out = '${dir.path}${Platform.pathSeparator}out';
    tmp = '${dir.path}${Platform.pathSeparator}tmp';
    src = '${dir.path}${Platform.pathSeparator}src.jpg';
    File(src).writeAsBytesSync(img.encodeJpg(img.Image(width: 20, height: 10)));
    pdf = _Pdf();
    ocr = _Ocr();
    renders = [];
    renderBytes = _jpg;
    renderError = null;
  });
  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  ScanExporter make({FontSource fonts = const FileFontSource(_fontFiles), bool withRenderer = true, bool withNow = true}) =>
      ScanExporter(
        pdfEngine: pdf,
        ocrEngine: ocr,
        outputDir: out,
        tempDir: tmp,
        fontSource: fonts,
        now: withNow ? () => DateTime(2026, 10, 30, 8, 1, 2) : null,
        renderer: withRenderer
            ? (path, edit) async {
                renders.add(edit);
                if (renderError != null) throw renderError!;
                return renderBytes;
              }
            : null,
      );

  ScanPage plain() => ScanPage(id: 'a', path: src);
  ScanPage edited() => ScanPage(id: 'b', path: src, filter: ops.ImageFilter.grayscale);
  List<FileSystemEntity> workDirs() =>
      Directory(tmp).existsSync() ? Directory(tmp).listSync() : <FileSystemEntity>[];

  group('U1 renderPageInIsolate', () {
    test('U1-B1 bộ lọc đen trắng ⇒ PNG', () async {
      final b = await renderPageInIsolate(src, const ops.ImageEdit(filter: ops.ImageFilter.blackWhite));
      expect(b.sublist(0, 2), [0x89, 0x50]);
    });
    test('U1-B2 bộ lọc khác ⇒ định dạng tự động (JPEG, không PNG)', () async {
      final b = await renderPageInIsolate(src, const ops.ImageEdit(filter: ops.ImageFilter.grayscale));
      expect(b.sublist(0, 2), isNot([0x89, 0x50]));
      expect(b.sublist(0, 2), [0xFF, 0xD8]);
    });
  });

  group('U2 hàm dựng', () {
    test('U2-B1 có renderer + now ⇒ dùng cả hai', () async {
      final e = make();
      expect(e.defaultBaseName(), 'Scan_20261030_080102');
      await e.exportPdf([edited()]);
      expect(renders, hasLength(1));
    });
    test('U2-B2 renderer null ⇒ render thật trong isolate', () async {
      final r = await make(withRenderer: false).exportPdf([edited()]);
      expect(renders, isEmpty);
      expect(pdf.paths!.single, isNot(src));
      expect(pdf.paths!.single, endsWith('.jpg'));
      expect(File(r.outputPath).existsSync(), isTrue);
    });
    test('U2-B3 now null ⇒ tên theo giờ hiện tại', () {
      final name = make(withNow: false).defaultBaseName();
      final t = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      expect(name, startsWith('Scan_${t.year}${two(t.month)}${two(t.day)}_'));
      expect(name, matches(RegExp(r'^Scan_\d{8}_\d{6}$')));
    });
  });

  group('U3 exportPdf', () {
    test('U3-B1 searchable, OCR ok, có font ⇒ PDF có lớp chữ, tiến độ tới 1', () async {
      final token = CancelToken();
      final prog = <double>[];
      final r = await make().exportPdf([plain()], searchable: true, cancelToken: token, onProgress: prog.add);
      // Ảnh cho PDF: trang chưa sửa dùng file gốc; render duy nhất là ảnh OCR (force, không lọc màu).
      expect(pdf.paths, [src]);
      expect(renders, hasLength(1));
      expect(renders.single.filter, ops.ImageFilter.original);
      expect(renders.single.maxLongSide, ScanExporter.ocrLongSide);
      expect(ocr.seen, hasLength(1));
      expect(r.outputPath, endsWith('Scan_20261030_080102.pdf'));
      expect(r.textLayer, isTrue);
      expect(r.skippedCount, 0);
      expect(_pdfText(r.outputPath), contains('Hóa đơn bán hàng'));
      expect(prog.last, 1);
      expect(prog, orderedEquals([...prog]..sort()));
      expect(workDirs(), isEmpty);
    });
    test('U3-B2 không có trang ⇒ CorruptFile, chưa tạo thư mục tạm', () async {
      final r = await make().exportPdf([]).then<Object?>((v) => v, onError: (Object e) => e);
      expect(pdf.calls, 0);
      expect(Directory(tmp).existsSync(), isFalse);
      expect(r, isA<CorruptFile>());
    });
    test('U3-B3 không searchable ⇒ không OCR, không lớp chữ', () async {
      final r = await make().exportPdf([plain()], cancelToken: CancelToken(), onProgress: (_) {});
      expect(ocr.seen, isEmpty);
      expect(pdf.calls, 1);
      expect(r.textLayer, isFalse);
      expect(File(r.outputPath).existsSync(), isTrue);
    });
    test('U3-B8 cancelToken null ⇒ vẫn xuất có lớp chữ', () async {
      final r = await make().exportPdf([plain()], searchable: true, onProgress: (_) {});
      expect(ocr.seen, hasLength(1));
      expect(r.textLayer, isTrue);
    });
    test('U3-B9 huỷ trước vòng ảnh ⇒ Cancelled, chưa tạo PDF, dọn tạm', () async {
      final t = CancelToken()..cancel();
      final r = await make().exportPdf([plain()], searchable: true, cancelToken: t).then<Object?>((v) => v, onError: (Object e) => e);
      expect(pdf.calls, 0);
      expect(ocr.seen, isEmpty);
      expect(workDirs(), isEmpty);
      expect(r, isA<Cancelled>());
    });
    test('U3-B10 ảnh trang sửa không đọc được ⇒ CorruptFile', () async {
      renderError = const FormatException('bad');
      final r = await make().exportPdf([edited()], searchable: true, cancelToken: CancelToken()).then<Object?>((v) => v, onError: (Object e) => e);
      expect(renders, hasLength(1));
      expect(pdf.calls, 0);
      expect(workDirs(), isEmpty);
      expect(r, isA<CorruptFile>());
    });
    test('U3-B11 onProgress null ⇒ xuất bình thường', () async {
      final r = await make().exportPdf([plain()], searchable: true, cancelToken: CancelToken());
      expect(ocr.seen, hasLength(1));
      expect(r.textLayer, isTrue);
    });
    test('U3-B15 huỷ khi đang OCR ⇒ Cancelled, không tạo PDF', () async {
      final t = CancelToken();
      ocr = _Ocr(onRecognize: (n) => t.cancel());
      final r = await make()
          .exportPdf([plain(), plain()], searchable: true, cancelToken: t, onProgress: (_) {})
          .then<Object?>((v) => v, onError: (Object e) => e);
      expect(ocr.seen, hasLength(1));
      expect(pdf.calls, 0);
      expect(r, isA<Cancelled>());
    });
    test('U3-B16 OCR lỗi (không phải huỷ) ⇒ vẫn xuất PDF ảnh, textLayer=false', () async {
      ocr = _Ocr(error: const UnsupportedFormat('heic'));
      final r = await make().exportPdf([plain()], searchable: true, cancelToken: CancelToken(), onProgress: (_) {});
      expect(ocr.seen, hasLength(1));
      expect(pdf.calls, 1);
      expect(r.textLayer, isFalse);
      expect(File(r.outputPath).existsSync(), isTrue);
    });
    test('U3-B17 có baseName ⇒ dùng tên đó', () async {
      final r = await make().exportPdf([plain()], baseName: 'Hoa don', searchable: true, cancelToken: CancelToken(), onProgress: (_) {});
      expect(r.outputPath, endsWith('${Platform.pathSeparator}Hoa don.pdf'));
    });
    test('U3-B18 engine PDF ném ⇒ lỗi lan ra, dọn tạm', () async {
      pdf = _Pdf(throwError: const CorruptFile('all images bad'));
      final r = await make().exportPdf([edited()], searchable: true, cancelToken: CancelToken(), onProgress: (_) {}).then<Object?>((v) => v, onError: (Object e) => e);
      expect(pdf.calls, 1);
      expect(workDirs(), isEmpty);
      expect(r, isA<CorruptFile>());
    });
    test('U3-B21 huỷ sau khi PDF đã ghi ⇒ Cancelled, xoá PDF dở', () async {
      pdf = _Pdf(cancelAfter: true);
      final t = CancelToken();
      final r = await make().exportPdf([plain()], searchable: true, cancelToken: t, onProgress: (_) {}).then<Object?>((v) => v, onError: (Object e) => e);
      expect(pdf.calls, 1);
      expect(File(pdf.outputPath!).existsSync(), isFalse);
      expect(r, isA<Cancelled>());
    });
    test('U3-B22 thiếu font ⇒ PDF ảnh, textLayer=false', () async {
      final r = await make(fonts: const NoFontSource()).exportPdf([plain()], searchable: true, cancelToken: CancelToken(), onProgress: (_) {});
      expect(ocr.seen, hasLength(1));
      expect(r.textLayer, isFalse);
      expect(File(r.outputPath).existsSync(), isTrue);
    });
    test('U3-B23 huỷ sau createPdf mà file đã mất ⇒ vẫn Cancelled (không FileSystemException)', () async {
      pdf = _Pdf(cancelAfter: true, writeFile: false);
      final r = await make().exportPdf([plain()], searchable: true, cancelToken: CancelToken(), onProgress: (_) {}).then<Object?>((v) => v, onError: (Object e) => e);
      expect(pdf.calls, 1);
      expect(File(pdf.outputPath!).existsSync(), isFalse);
      expect(r, isA<Cancelled>());
    });
  });

  group('U4 exportTxt', () {
    test('U4-B1 OCR ok, baseName null ⇒ TXT tên mặc định, có chữ', () async {
      final r = await make().exportTxt([plain()], OcrScript.latin);
      expect(ocr.seen, hasLength(1));
      expect(r.outputPath, endsWith('Scan_20261030_080102.txt'));
      expect(File(r.outputPath).readAsStringSync(), 'Hóa đơn bán hàng');
      expect(r.hasText, isTrue);
    });
    test('U4-B2 _ocrAll ném (không trang) ⇒ CorruptFile, không ghi file', () async {
      final r = await make().exportTxt([], OcrScript.latin).then<Object?>((v) => v, onError: (Object e) => e);
      expect(Directory(out).existsSync() ? Directory(out).listSync() : [], isEmpty);
      expect(r, isA<CorruptFile>());
    });
    test('U4-B3 có baseName ⇒ dùng tên đó', () async {
      final r = await make().exportTxt([plain()], OcrScript.latin, baseName: 'Ghi chu');
      expect(r.outputPath, endsWith('${Platform.pathSeparator}Ghi chu.txt'));
    });
  });

  group('U5 exportDocx', () {
    test('U5-B1 OCR ok, baseName null ⇒ DOCX tên mặc định', () async {
      final r = await make().exportDocx([plain()], OcrScript.latin);
      expect(ocr.seen, hasLength(1));
      expect(r.outputPath, endsWith('Scan_20261030_080102.docx'));
      expect(File(r.outputPath).readAsBytesSync().sublist(0, 2), [0x50, 0x4b]);
      expect(r.hasText, isTrue);
    });
    test('U5-B2 _ocrAll ném (không trang) ⇒ CorruptFile', () async {
      final r = await make().exportDocx([], OcrScript.latin).then<Object?>((v) => v, onError: (Object e) => e);
      expect(ocr.seen, isEmpty);
      expect(r, isA<CorruptFile>());
    });
    test('U5-B3 có baseName ⇒ dùng tên đó', () async {
      final r = await make().exportDocx([plain()], OcrScript.latin, baseName: 'Hop dong');
      expect(r.outputPath, endsWith('${Platform.pathSeparator}Hop dong.docx'));
    });
  });

  group('U6 _ocrAll (qua exportTxt)', () {
    test('U6-B1 token + tiến độ ⇒ OCR mọi trang, tiến độ tới 1, dọn tạm', () async {
      final prog = <double>[];
      await make().exportTxt([plain(), edited()], OcrScript.latin, cancelToken: CancelToken(), onProgress: prog.add);
      expect(ocr.seen, hasLength(2));
      expect(prog, [0.5, 1.0]);
      expect(workDirs(), isEmpty);
    });
    test('U6-B4 token null ⇒ OCR bình thường', () async {
      await make().exportTxt([plain()], OcrScript.latin, onProgress: (_) {});
      expect(ocr.seen, hasLength(1));
    });
    test('U6-B5 đã huỷ ⇒ Cancelled, không OCR', () async {
      final r = await make().exportTxt([plain()], OcrScript.latin, cancelToken: CancelToken()..cancel()).then<Object?>((v) => v, onError: (Object e) => e);
      expect(ocr.seen, isEmpty);
      expect(workDirs(), isEmpty);
      expect(r, isA<Cancelled>());
    });
    test('U6-B6 ảnh không đọc được ⇒ CorruptFile, không OCR', () async {
      renderError = const FormatException('bad');
      final r = await make().exportTxt([plain()], OcrScript.latin, cancelToken: CancelToken()).then<Object?>((v) => v, onError: (Object e) => e);
      expect(renders, hasLength(1), reason: 'OCR luôn render (force)');
      expect(ocr.seen, isEmpty);
      expect(r, isA<CorruptFile>());
    });
    test('U6-B7 engine OCR ném ⇒ lỗi lan ra, dọn tạm', () async {
      ocr = _Ocr(error: const UnsupportedFormat('x'));
      final r = await make().exportTxt([plain()], OcrScript.latin, cancelToken: CancelToken()).then<Object?>((v) => v, onError: (Object e) => e);
      expect(ocr.seen, hasLength(1));
      expect(workDirs(), isEmpty);
      expect(r, isA<UnsupportedFormat>());
    });
    test('U6-B8 onProgress null ⇒ OCR bình thường', () async {
      final r = await make().exportTxt([plain()], OcrScript.latin, cancelToken: CancelToken());
      expect(ocr.seen, hasLength(1));
      expect(r.hasText, isTrue);
    });
  });

  group('U7 _pathFor', () {
    test('U7-B1 trang đã sửa, bytes PNG ⇒ file .png trong thư mục tạm', () async {
      renderBytes = _png;
      await make().exportPdf([edited()]);
      expect(renders, hasLength(1));
      expect(pdf.paths!.single, endsWith('.png'));
      expect(pdf.paths!.single, isNot(src));
    });
    test('U7-B2 force (OCR), trang chưa sửa ⇒ vẫn render, .png', () async {
      renderBytes = _png;
      await make().exportTxt([plain()], OcrScript.latin);
      expect(renders, hasLength(1));
      expect(renders.single.filter, ops.ImageFilter.original);
      expect(ocr.seen.single, endsWith('.png'));
    });
    test('U7-B3 trang chưa sửa, không force ⇒ dùng file gốc', () async {
      await make().exportPdf([plain()]);
      expect(renders, isEmpty);
      expect(pdf.paths!.single, src);
    });
    test('U7-B4 render ném FormatException ⇒ CorruptFile', () async {
      renderError = const FormatException('bad');
      final r = await make().exportPdf([edited()]).then<Object?>((v) => v, onError: (Object e) => e);
      expect(renders, hasLength(1));
      expect(r, isA<CorruptFile>());
    });
    test('U7-B5 bytes ≤ 3 ⇒ .jpg', () async {
      renderBytes = Uint8List.fromList([0x89, 0x50, 0x4E]);
      await make().exportPdf([edited()]);
      expect(pdf.paths!.single, endsWith('.jpg'));
    });
    test('U7-B6 bytes JPEG ⇒ .jpg', () async {
      renderBytes = _jpg;
      await make().exportPdf([edited()]);
      expect(pdf.paths!.single, endsWith('.jpg'));
    });
    test('U7-B7 byte đầu 0x89, byte hai khác 0x50 ⇒ .jpg', () async {
      renderBytes = Uint8List.fromList([0x89, 0x00, 0x00, 0x00]);
      await make().exportPdf([edited()]);
      expect(pdf.paths!.single, endsWith('.jpg'));
    });
  });

  group('U8 _requirePages', () {
    test('U8-B1 có trang ⇒ cho qua', () async {
      await make().exportPdf([plain()]);
      expect(pdf.calls, 1);
    });
    test('U8-B2 rỗng ⇒ CorruptFile', () async {
      final r = await make().exportTxt([], OcrScript.latin).then<Object?>((v) => v, onError: (Object e) => e);
      expect(r, isA<CorruptFile>());
    });
  });

  group('U9 _cleanup', () {
    test('U9-B1 thư mục tạm còn ⇒ xoá', () async {
      await make().exportPdf([edited()]);
      expect(Directory(tmp).existsSync(), isTrue);
      expect(workDirs(), isEmpty);
    });
    test('U9-B2 thư mục tạm đã mất ⇒ bỏ qua, không lỗi', () async {
      pdf = _Pdf(onCreate: (paths) => File(paths.single).parent.deleteSync(recursive: true));
      final r = await make().exportPdf([edited()]).then<Object?>((v) => v, onError: (Object e) => e);
      expect(workDirs(), isEmpty);
      expect(r, isA<ScanExportResult>());
    });
    test('U9-B3 xoá thư mục tạm lỗi (file đang mở) ⇒ nuốt lỗi, vẫn trả kết quả', () async {
      RandomAccessFile? held;
      pdf = _Pdf(onCreate: (paths) => held = File(paths.single).openSync());
      final r = await make().exportPdf([edited()]).then<Object?>((v) => v, onError: (Object e) => e);
      final left = workDirs().length;
      held?.closeSync();
      expect(held, isNotNull);
      expect(left, 1, reason: 'delete phải thất bại vì file đang mở (Windows)');
      expect(r, isA<ScanExportResult>());
    });
  });
}
