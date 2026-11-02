// Kiểm thử hộp trắng (A04, chủ đề convert) — lib/features/convert/engine/ocr_pdf_convert_engine.dart.
// Mã bộ = mã đường Bước 4/5: test-output/whitebox/convert/ocr_pdf_convert_engine/buoc-5-du-lieu-thu.md.
// Expected chép từ Bước 5 (nguồn yêu cầu), KHÔNG chỉnh theo code.
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
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

OcrResult _ocr(String text) => OcrResult(
      text: text,
      blocks: [
        OcrBlock(text, Rect.zero, [OcrLine(text, const Rect.fromLTWH(100, 100, 600, 60))]),
      ],
      imageWidth: 1000,
      imageHeight: 1400,
    );

class _FakeOcr implements OcrEngine {
  _FakeOcr(this.result, {this.error});
  final OcrResult result;
  final Object? error;
  final calls = <String>[];
  final scripts = <OcrScript>[];

  @override
  Future<OcrResult> recognize(String imagePath, OcrScript script) async {
    calls.add(imagePath);
    scripts.add(script);
    if (error != null) throw error!;
    return result;
  }

  @override
  Future<void> dispose() async {}
}

class _FakeDoc implements PdfRenderDocument {
  _FakeDoc(this.count, {this.renderError, this.onRender});
  final int count;
  final Object? renderError;
  final void Function()? onRender;
  final rendered = <(int, double)>[];
  bool closed = false;

  @override
  int get pageCount => count;
  @override
  Future<PdfPageSize> pageSize(int i) async => const PdfPageSize(595, 842);
  @override
  Future<Uint8List> renderPage(int i,
      {double dpi = 150,
      RenderFormat format = RenderFormat.png,
      int jpgQuality = 90,
      CancelToken? cancelToken}) async {
    rendered.add((i, dpi));
    onRender?.call();
    if (renderError != null) throw renderError!;
    return Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
  }

  @override
  Future<Uint8List> renderThumbnail(int i, {int maxSide = 300}) async => Uint8List(0);
  @override
  Future<void> close() async => closed = true;
}

class _FakeRender implements PdfRenderEngine {
  _FakeRender(this.doc, {this.openError});
  final _FakeDoc doc;
  final Object? openError;
  int opens = 0;
  String? password;

  @override
  Future<PdfRenderDocument> openFile(String path, {String? password}) async {
    opens++;
    this.password = password;
    if (openError != null) throw openError!;
    return doc;
  }

  @override
  Future<PdfRenderDocument> openBytes(Uint8List bytes) async => doc;
}

/// PDF 2 trang: trang 0 có chữ thật (hoặc chỉ hình), trang 1 chỉ có hình (không chữ).
String _pdf(String path, {bool textPage = true, bool blankPage = true}) {
  final doc = sf.PdfDocument();
  doc.pageSettings.size = const Size(595, 842);
  final first = doc.pages.add();
  if (textPage) {
    first.graphics.drawString('Real text page', sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 14),
        bounds: const Rect.fromLTWH(40, 40, 300, 30));
  } else {
    first.graphics.drawRectangle(brush: sf.PdfBrushes.gray, bounds: const Rect.fromLTWH(40, 40, 100, 100));
  }
  if (blankPage) {
    doc.pages.add().graphics.drawRectangle(
        brush: sf.PdfBrushes.lightGray, bounds: const Rect.fromLTWH(10, 10, 200, 200));
  }
  File(path).writeAsBytesSync(doc.saveSync());
  doc.dispose();
  return path;
}

Future<Object?> _capture<T>(Future<T> f) => f.then<Object?>((v) => v, onError: (Object e) => e);

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('wb_ocr_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  String path(String n) => p.join(tmp.path, n);
  String work() => path('work');
  bool workEmpty() => !Directory(work()).existsSync() || Directory(work()).listSync().isEmpty;

  OcrPdfConvertEngine make(_FakeOcr ocr, _FakeRender render, {OcrScript script = OcrScript.latin}) =>
      OcrPdfConvertEngine(
        inner: const PdfConvertEngine(fontSource: NoFontSource(), useIsolate: false),
        render: render,
        ocr: ocr,
        scriptProvider: () => script,
        tempDir: work(),
      );

  group('U1 _pagesWithOcr / U2 _pdfTo / U3-U4 closure tiến độ', () {
    test('U1-P1 trang ảnh được OCR, trang chữ giữ nguyên; tiến độ 0.1→0.9→1; dọn tạm', () async {
      final ocr = _FakeOcr(_ocr('Chữ quét được'));
      final render = _FakeRender(_FakeDoc(2));
      final progress = <double>[];
      final r = await _capture(make(ocr, render, script: OcrScript.japanese)
          .pdfToText(_pdf(path('in.pdf')), path('o.txt'), onProgress: progress.add));
      expect(ocr.calls, hasLength(1)); // nhánh: chỉ 1 trang ảnh được OCR
      expect(ocr.scripts.single, OcrScript.japanese);
      expect(render.doc.rendered.single.$1, 1);
      expect(render.doc.closed, isTrue);
      expect(workEmpty(), isTrue);
      expect(r, path('o.txt'));
      final text = File(path('o.txt')).readAsStringSync();
      expect(text, contains('Real text page'));
      expect(text, contains('Chữ quét được'));
      expect(progress, contains(closeTo(0.1, 1e-9)));
      expect(progress, contains(closeTo(0.9, 1e-9)));
      expect(progress.last, 1);
      expect(progress, orderedEquals([...progress]..sort()));
    });

    test('U1-P2 / U2-P2 file vào không tồn tại ⇒ CorruptFile, không mở bộ render', () async {
      final render = _FakeRender(_FakeDoc(2));
      final r = await _capture(make(_FakeOcr(_ocr('x')), render).pdfToText(path('none.pdf'), path('o.txt')));
      expect(render.opens, 0);
      expect(r, isA<CorruptFile>());
    });

    test('U1-P3 PDF toàn chữ thật ⇒ không mở bộ render, không OCR', () async {
      final ocr = _FakeOcr(_ocr('x'));
      final render = _FakeRender(_FakeDoc(1));
      final r = await _capture(make(ocr, render).pdfToText(_pdf(path('t.pdf'), blankPage: false), path('o.txt')));
      expect(render.opens, 0);
      expect(ocr.calls, isEmpty);
      expect(r, path('o.txt'));
      expect(File(path('o.txt')).readAsStringSync(), contains('Real text page'));
    });

    test('U1-P4 bộ render không mở được (mật khẩu sai) ⇒ WrongPassword, không đóng doc, dọn tạm', () async {
      final ocr = _FakeOcr(_ocr('x'));
      final render = _FakeRender(_FakeDoc(2), openError: const WrongPassword());
      final r = await _capture(make(ocr, render).pdfToText(_pdf(path('in.pdf')), path('o.txt'), password: 'pw'));
      expect(render.password, 'pw');
      expect(render.doc.closed, isFalse); // nhánh D13e Đ: doc == null
      expect(ocr.calls, isEmpty);
      expect(workEmpty(), isTrue);
      expect(r, isA<WrongPassword>());
      expect(File(path('o.txt')).existsSync(), isFalse);
    });

    test('U1-P6 có cancelToken chưa huỷ ⇒ chạy hết như U1-P1', () async {
      final ocr = _FakeOcr(_ocr('Quét'));
      final render = _FakeRender(_FakeDoc(2));
      final token = CancelToken();
      final r = await _capture(
          make(ocr, render).pdfToText(_pdf(path('in.pdf')), path('o.txt'), cancelToken: token));
      expect(ocr.calls, hasLength(1));
      expect(r, path('o.txt'));
    });

    test('U1-P7 huỷ ngay sau bước trích chữ ⇒ Cancelled trước khi render; đóng doc, dọn tạm', () async {
      final ocr = _FakeOcr(_ocr('x'));
      final render = _FakeRender(_FakeDoc(2));
      final token = CancelToken();
      final r = await _capture(make(ocr, render).pdfToText(_pdf(path('in.pdf')), path('o.txt'),
          cancelToken: token, onProgress: (v) {
        if (v >= 0.1 - 1e-9) token.cancel();
      }));
      expect(render.doc.rendered, isEmpty);
      expect(render.doc.closed, isTrue); // nhánh D13e S
      expect(workEmpty(), isTrue);
      expect(r, isA<Cancelled>());
    });

    test('U1-P8 bộ render thấy ít trang hơn ⇒ bỏ qua trang đó, không lỗi, giữ chữ thật', () async {
      final ocr = _FakeOcr(_ocr('x'));
      final render = _FakeRender(_FakeDoc(1)); // PDF 2 trang, renderer chỉ 1
      final r = await _capture(make(ocr, render).pdfToText(_pdf(path('in.pdf')), path('o.txt')));
      expect(render.doc.rendered, isEmpty); // nhánh D7 Đ (continue)
      expect(ocr.calls, isEmpty);
      expect(r, path('o.txt'));
      expect(File(path('o.txt')).readAsStringSync(), contains('Real text page'));
    });

    test('U1-P9 / U1-P15 render trang ném ⇒ lỗi lan ra, đóng doc, dọn tạm', () async {
      final ocr = _FakeOcr(_ocr('x'));
      final render = _FakeRender(_FakeDoc(2, renderError: const CorruptFile('render')));
      final r = await _capture(make(ocr, render).pdfToText(_pdf(path('in.pdf')), path('o.txt')));
      expect(render.doc.rendered, hasLength(1));
      expect(ocr.calls, isEmpty);
      expect(render.doc.closed, isTrue);
      expect(workEmpty(), isTrue);
      expect(r, isA<CorruptFile>());
    });

    test('U1-P11 huỷ trong lúc render ⇒ Cancelled, không gọi OCR', () async {
      final ocr = _FakeOcr(_ocr('x'));
      final token = CancelToken();
      final render = _FakeRender(_FakeDoc(2, onRender: token.cancel));
      final r = await _capture(
          make(ocr, render).pdfToText(_pdf(path('in.pdf')), path('o.txt'), cancelToken: token));
      expect(render.doc.rendered, hasLength(1));
      expect(ocr.calls, isEmpty); // nhánh D10 Đ
      expect(render.doc.closed, isTrue);
      expect(workEmpty(), isTrue);
      expect(r, isA<Cancelled>());
    });

    test('U1-P12 OCR ném ⇒ lỗi lan ra, đóng doc, dọn tạm', () async {
      final ocr = _FakeOcr(_ocr('x'), error: const Unknown('mlkit'));
      final render = _FakeRender(_FakeDoc(2));
      final r = await _capture(make(ocr, render).pdfToText(_pdf(path('in.pdf')), path('o.txt')));
      expect(ocr.calls, hasLength(1));
      expect(render.doc.closed, isTrue);
      expect(workEmpty(), isTrue);
      expect(r, isA<Unknown>());
      expect(File(path('o.txt')).existsSync(), isFalse);
    });

    test('U1-P13 / U3-P1 / U4-P1 không có onProgress ⇒ vẫn ra file', () async {
      final ocr = _FakeOcr(_ocr('Quét'));
      final r = await _capture(make(ocr, _FakeRender(_FakeDoc(2))).pdfToText(_pdf(path('in.pdf')), path('o.txt')));
      expect(ocr.calls, hasLength(1));
      expect(r, path('o.txt'));
    });

    test('U2-P3 trang ảnh OCR không ra chữ ⇒ lỗi NoTextFound (isNoTextError)', () async {
      final ocr = _FakeOcr(OcrResult.empty);
      final r = await _capture(make(ocr, _FakeRender(_FakeDoc(2)))
          .pdfToDocx(_pdf(path('scan.pdf'), textPage: false), path('o.docx')));
      expect(ocr.calls, hasLength(2)); // cả 2 trang đều được OCR
      expect(r, predicate(isNoTextError));
      expect(File(path('o.docx')).existsSync(), isFalse);
    });

    test('U2-P1 / U3-P2 / U4-P2 PDF → XLSX qua OCR có tiến độ', () async {
      final ocr = _FakeOcr(_ocr('Tổng cộng'));
      final progress = <double>[];
      final r = await _capture(make(ocr, _FakeRender(_FakeDoc(2)))
          .pdfToXlsx(_pdf(path('scan.pdf'), textPage: false), path('o.xlsx'), onProgress: progress.add));
      expect(ocr.calls, hasLength(2));
      expect(r, path('o.xlsx'));
      expect(File(path('o.xlsx')).lengthSync(), greaterThan(500));
      expect(progress.first, lessThanOrEqualTo(0.1 + 1e-9));
      expect(progress.last, 1);
    });
  });
}
