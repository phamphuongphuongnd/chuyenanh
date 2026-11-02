// Kiểm thử hộp trắng A14 — pdf_to_ppt.dart (PdfToPptConverter.convert).
// Mã bộ = mã đường ở test-output/whitebox/ppt-convert/pdf_to_ppt/buoc-5-du-lieu-thu.md.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_layout/pdf_layout.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/pdf/pdf_render_engine.dart';
import 'package:pdf_office/features/ppt_convert/engine/pdf_to_ppt.dart';

Uint8List _jpg(int n) => Uint8List.fromList([0xFF, 0xD8, n, 0xFF, 0xD9]);

class _Render implements PdfRenderEngine {
  _Render({
    this.sizes = const [PdfPageSize(595, 842), PdfPageSize(842, 595)],
    this.openError,
    this.onPageSize,
    this.onRender,
  });

  final List<PdfPageSize> sizes;
  final Object? openError;
  final void Function(int page)? onPageSize;
  final void Function(int page)? onRender;

  int opened = 0;
  int closed = 0;
  final List<int> pageSizeCalls = [];
  final List<int> renders = [];

  @override
  Future<PdfRenderDocument> openFile(String path, {String? password}) async {
    opened++;
    if (openError != null) throw openError!;
    return _Doc(this);
  }

  @override
  Future<PdfRenderDocument> openBytes(Uint8List bytes) => openFile('');
}

class _Doc implements PdfRenderDocument {
  _Doc(this.o);
  final _Render o;

  @override
  int get pageCount => o.sizes.length;

  @override
  Future<PdfPageSize> pageSize(int pageIndex) async {
    o.pageSizeCalls.add(pageIndex);
    o.onPageSize?.call(pageIndex);
    return o.sizes[pageIndex];
  }

  @override
  Future<Uint8List> renderPage(
    int pageIndex, {
    double dpi = 150,
    RenderFormat format = RenderFormat.png,
    int jpgQuality = 90,
    CancelToken? cancelToken,
  }) async {
    // Engine thật tôn trọng cancelToken: đã huỷ thì ném Cancelled.
    cancelToken?.throwIfCancelled();
    o.renders.add(pageIndex);
    o.onRender?.call(pageIndex);
    return _jpg(pageIndex + 1);
  }

  @override
  Future<Uint8List> renderThumbnail(int pageIndex, {int maxSide = 300}) async =>
      _jpg(0);

  @override
  Future<void> close() async => o.closed++;
}

class _Enc {
  _Enc({this.onEncode});
  final void Function()? onEncode;
  int calls = 0;
  double? w;
  double? h;
  String? title;
  int? slides;

  Future<Uint8List> call(
    List<PptxImageSlide> s,
    double wPt,
    double hPt,
    String t,
  ) async {
    calls++;
    w = wPt;
    h = hPt;
    title = t;
    slides = s.length;
    onEncode?.call();
    return writeImagePptx(s, slideWidthPt: wPt, slideHeightPt: hPt, title: t);
  }
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('wb_pdf2ppt'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<Object> run(
    PdfToPptConverter c,
    String out, {
    CancelToken? token,
    ProgressCallback? onProgress,
  }) => c
      .convert(
        inputPath: '/x/Bao cao.pdf',
        outputPath: out,
        cancelToken: token,
        onProgress: onProgress,
      )
      .then<Object>((v) => v, onError: (Object e) => e);

  test('U1.P1 2 trang, có token + onProgress ⇒ ghi .pptx, tiến độ 0→0.9→0.95→1', () async {
    final r = _Render();
    final enc = _Enc();
    final out = p.join(tmp.path, 'a.pptx');
    final prog = <double>[];
    final res = await run(
      PdfToPptConverter(render: r, encode: enc.call),
      out,
      token: CancelToken(),
      onProgress: prog.add,
    );
    // nhánh: D7 Đ (trang 0 dùng first) rồi S (trang 1 gọi pageSize(1))
    expect(r.pageSizeCalls, [0, 1]);
    expect(r.renders, [0, 1]);
    expect(r.closed, 1);
    expect(enc.calls, 1);
    expect((enc.w, enc.h), (595.0, 842.0)); // cỡ slide = cỡ trang 1
    expect(enc.title, 'Bao cao');
    expect(prog.first, 0);
    expect(prog[1], closeTo(0.45, 1e-9));
    expect(prog[2], closeTo(0.9, 1e-9));
    expect(prog[3], closeTo(0.95, 1e-9));
    expect(prog.last, 1);
    expect(res, out);
    expect(File(out).existsSync(), isTrue);
    expect(File('$out.tmp').existsSync(), isFalse);
  });

  test('U1.P2 không truyền cancelToken ⇒ vẫn chuyển xong', () async {
    final r = _Render();
    final enc = _Enc();
    final out = p.join(tmp.path, 'b.pptx');
    final res = await run(PdfToPptConverter(render: r, encode: enc.call), out);
    expect(r.renders, [0, 1]);
    expect(enc.calls, 1);
    expect(res, out);
  });

  test('U1.P3 openFile ném WrongPassword ⇒ ném lại, không render, không đóng gì', () async {
    final r = _Render(openError: const WrongPassword());
    final enc = _Enc();
    final res = await run(
      PdfToPptConverter(render: r, encode: enc.call),
      p.join(tmp.path, 'c.pptx'),
    );
    expect(r.opened, 1);
    expect(r.renders, isEmpty);
    expect(r.closed, 0);
    expect(enc.calls, 0);
    expect(res, isA<WrongPassword>());
  });

  test('U1.P4 PDF 0 trang ⇒ CorruptFile, vẫn đóng tài liệu, không ghi', () async {
    final r = _Render(sizes: const []);
    final enc = _Enc();
    final out = p.join(tmp.path, 'd.pptx');
    final res = await run(PdfToPptConverter(render: r, encode: enc.call), out);
    expect(r.closed, 1);
    expect(r.pageSizeCalls, isEmpty);
    expect(enc.calls, 0);
    expect(res, isA<CorruptFile>());
    expect(File(out).existsSync(), isFalse);
  });

  test('U1.P5* onProgress null (D4, D9, D12, D13 cùng Đ) ⇒ chuyển xong không lỗi', () async {
    final r = _Render();
    final enc = _Enc();
    final out = p.join(tmp.path, 'e.pptx');
    final res = await run(
      PdfToPptConverter(render: r, encode: enc.call),
      out,
      token: CancelToken(),
    );
    expect(r.renders, [0, 1]);
    expect(res, out);
    expect(File(out).existsSync(), isTrue);
  });

  test('U1.P10 huỷ trong lúc render trang 0 ⇒ D6 ném ở vòng 2, Cancelled, đóng doc', () async {
    final token = CancelToken();
    final r = _Render(onRender: (i) {
      if (i == 0) token.cancel();
    });
    final enc = _Enc();
    final out = p.join(tmp.path, 'f.pptx');
    final res = await run(
      PdfToPptConverter(render: r, encode: enc.call),
      out,
      token: token,
    );
    expect(r.renders, [0]);
    expect(r.pageSizeCalls, [0]); // chưa tới pageSize(1)
    expect(r.closed, 1);
    expect(enc.calls, 0);
    expect(res, isA<Cancelled>());
    expect(File(out).existsSync(), isFalse);
  });

  test('U1.P11 PDF 1 trang ⇒ D7 chỉ Đ, không gọi pageSize lần 2', () async {
    final r = _Render(sizes: const [PdfPageSize(842, 595)]);
    final enc = _Enc();
    final out = p.join(tmp.path, 'g.pptx');
    final res = await run(PdfToPptConverter(render: r, encode: enc.call), out);
    expect(r.pageSizeCalls, [0]);
    expect((enc.w, enc.h), (842.0, 595.0));
    expect(enc.slides, 1);
    expect(res, out);
  });

  test('U1.P12 huỷ trong lúc lấy cỡ trang 1 ⇒ renderPage ném Cancelled (D8), đóng doc', () async {
    final token = CancelToken();
    final r = _Render(onPageSize: (i) {
      if (i == 1) token.cancel();
    });
    final enc = _Enc();
    final res = await run(
      PdfToPptConverter(render: r, encode: enc.call),
      p.join(tmp.path, 'h.pptx'),
      token: token,
    );
    expect(r.pageSizeCalls, [0, 1]);
    expect(r.renders, [0]); // trang 1 không render xong
    expect(r.closed, 1);
    expect(enc.calls, 0);
    expect(res, isA<Cancelled>());
  });

  test('U1.P13 huỷ trong lúc render trang cuối ⇒ D10 ném sau finally, không encode', () async {
    final token = CancelToken();
    final r = _Render(onRender: (i) {
      if (i == 1) token.cancel();
    });
    final enc = _Enc();
    final out = p.join(tmp.path, 'i.pptx');
    final res = await run(
      PdfToPptConverter(render: r, encode: enc.call),
      out,
      token: token,
    );
    expect(r.renders, [0, 1]);
    expect(r.closed, 1);
    expect(enc.calls, 0);
    expect(res, isA<Cancelled>());
    expect(File(out).existsSync(), isFalse);
  });

  test('U1.P14 huỷ trong lúc ghi PPTX (encode) ⇒ D11 ném, không để lại file', () async {
    final token = CancelToken();
    final r = _Render();
    final enc = _Enc(onEncode: token.cancel);
    final out = p.join(tmp.path, 'j.pptx');
    final prog = <double>[];
    final res = await run(
      PdfToPptConverter(render: r, encode: enc.call),
      out,
      token: token,
      onProgress: prog.add,
    );
    expect(enc.calls, 1);
    expect(prog, isNot(contains(0.95)));
    expect(res, isA<Cancelled>());
    expect(File(out).existsSync(), isFalse);
    expect(File('$out.tmp').existsSync(), isFalse);
  });
}
