// Kiểm thử hộp trắng A14 — ppt_to_pdf.dart.
// Mã bộ = mã đường ở test-output/whitebox/ppt-convert/ppt_to_pdf/buoc-5-du-lieu-thu.md.
import 'dart:async';
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

/// 16:9 (720 × 405 pt), slide 1 ẩn.
PptxDeck _deck({int w = 9144000, int h = 5143500, List<PptxSlide>? slides}) =>
    PptxDeck(
      slideWidthEmu: w,
      slideHeightEmu: h,
      slides:
          slides ?? [_slide(0), _slide(1, hidden: true), _slide(2), _slide(3)],
    );

final Uint8List _png = Uint8List.fromList(
  img.encodePng(img.Image(width: 16, height: 9)..clear(img.ColorRgb8(9, 9, 9))),
);

class _Raster implements SlideRasterizer {
  _Raster({this.onRender, this.error, this.bytes});
  final void Function(int call)? onRender;
  final Object? error;
  final Uint8List? bytes;
  final List<int> slides = [];

  @override
  Future<Uint8List> renderSlide(
    PptxDeck deck,
    PptxSlide slide, {
    required int dpi,
  }) async {
    final call = slides.length;
    slides.add(slide.index);
    onRender?.call(call);
    if (error != null) throw error!;
    return bytes ?? _png;
  }
}

/// Thư mục tạm giả: `createTemp` ném lỗi đầy đĩa (ENOSPC = 28).
class _FullDiskDir implements Directory {
  @override
  Future<Directory> createTemp([String? prefix]) async => throw const FileSystemException(
    'No space left on device',
    '/tmp',
    OSError('No space left on device', 28),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('U1 copyWith', () {
    const base = PptToPdfOptions(quality: PptPdfQuality.high, includeHidden: true);
    test('U1.P1 đổi cả hai ⇒ lấy giá trị mới', () {
      final o = base.copyWith(quality: PptPdfQuality.standard, includeHidden: false);
      expect(o.quality, PptPdfQuality.standard);
      expect(o.includeHidden, isFalse);
    });
    test('U1.P2 quality null ⇒ giữ quality cũ', () {
      final o = base.copyWith(includeHidden: false);
      expect(o.quality, PptPdfQuality.high);
      expect(o.includeHidden, isFalse);
    });
    test('U1.P3 includeHidden null ⇒ giữ includeHidden cũ', () {
      final o = base.copyWith(quality: PptPdfQuality.standard);
      expect(o.quality, PptPdfQuality.standard);
      expect(o.includeHidden, isTrue);
    });
  });

  group('U2 pdfPageSizeOf', () {
    test('U2.P1 kích thước hợp lệ ⇒ EMU/12700', () {
      expect(pdfPageSizeOf(_deck()), const Size(720, 405));
    });
    test('U2.P2 rộng 0 ⇒ 960×540', () {
      expect(pdfPageSizeOf(_deck(w: 0)), const Size(960, 540));
    });
    test('U2.P3 rộng hợp lệ, cao âm ⇒ 960×540', () {
      expect(pdfPageSizeOf(_deck(h: -5)), const Size(960, 540));
    });
  });

  group('U3 ensurePptxPath', () {
    test('U3.P1 .PPTX (hoa) ⇒ nhận', () {
      expect(() => ensurePptxPath('/a/B.PPTX'), returnsNormally);
    });
    test('U3.P2 .ppt ⇒ UnsupportedFormat("ppt")', () {
      expect(
        () => ensurePptxPath('/a/cu.ppt'),
        throwsA(isA<UnsupportedFormat>().having((e) => e.extension, 'ext', 'ppt')),
      );
    });
    test('U3.P3 không có đuôi ⇒ UnsupportedFormat("")', () {
      expect(
        () => ensurePptxPath('/a/README'),
        throwsA(isA<UnsupportedFormat>().having((e) => e.extension, 'ext', '')),
      );
    });
  });

  group('U4 openDeck', () {
    test('U4.P1 .pptx + loader ổn ⇒ trả deck', () async {
      var calls = 0;
      final d = _deck();
      final e = DefaultPptToPdfEngine(loader: (_) async {
        calls++;
        return d;
      });
      expect(await e.openDeck('/a/x.pptx'), same(d));
      expect(calls, 1);
    });
    test('U4.P2 .ppt ⇒ UnsupportedFormat, không gọi loader', () async {
      var calls = 0;
      final e = DefaultPptToPdfEngine(loader: (_) async {
        calls++;
        return _deck();
      });
      final r = await e.openDeck('/a/x.ppt').then<Object>((v) => v, onError: (Object x) => x);
      expect(calls, 0);
      expect(r, isA<UnsupportedFormat>());
    });
    test('U4.P3 loader ném CorruptFile ⇒ ném lại CorruptFile', () async {
      var calls = 0;
      final e = DefaultPptToPdfEngine(loader: (_) async {
        calls++;
        throw const CorruptFile('bad');
      });
      final r = await e.openDeck('/a/x.pptx').then<Object>((v) => v, onError: (Object x) => x);
      expect(calls, 1);
      expect(r, isA<CorruptFile>());
    });
  });

  group('U5–U12 convert', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('wb_ppt2pdf'));
    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    Future<Object> conv(
      PptxDeck deck,
      String out,
      SlideRasterizer r, {
      CancelToken? token,
      ProgressCallback? onProgress,
      PptToPdfOptions options = const PptToPdfOptions(),
    }) => const DefaultPptToPdfEngine()
        .convert(deck, out, rasterizer: r, options: options, onProgress: onProgress, cancelToken: token)
        .then<Object>((v) => v, onError: (Object e) => e);

    int pdfPages(String path) {
      final d = sf.PdfDocument(inputBytes: File(path).readAsBytesSync());
      try {
        return d.pages.count;
      } finally {
        d.dispose();
      }
    }

    test('U5.P1 3 slide hiện, có token + onProgress ⇒ PDF 3 trang 720×405, tiến độ tăng tới 1', () async {
      final out = p.join(dir.path, 'a.pdf');
      final r = _Raster();
      final prog = <double>[];
      final res = await conv(_deck(), out, r, token: CancelToken(), onProgress: prog.add);
      expect(r.slides, [0, 2, 3]);
      expect(prog.where((v) => v <= 0.8 + 1e-9).length, greaterThanOrEqualTo(3));
      expect(prog.any((v) => v > 0.8), isTrue); // U6 onPage chạy
      expect(prog.last, closeTo(1, 1e-9));
      expect(res, out);
      expect(pdfPages(out), 3);
      final d = sf.PdfDocument(inputBytes: File(out).readAsBytesSync());
      expect(d.pages[0].size.width, closeTo(720, 0.5));
      expect(d.pages[0].size.height, closeTo(405, 0.5));
      d.dispose();
      expect(File('$out.tmp').existsSync(), isFalse);
    });

    test('U5.P2 mọi slide ẩn ⇒ CorruptFile, không gọi rasterizer, không ghi', () async {
      final out = p.join(dir.path, 'b.pdf');
      final r = _Raster();
      final res = await conv(_deck(slides: [_slide(0, hidden: true)]), out, r);
      expect(r.slides, isEmpty);
      expect(res, isA<CorruptFile>());
      expect(File(out).existsSync(), isFalse);
    });

    test('U5.P3* không token (D2, D6, D9 Đ; U7 D1, D3 Đ) ⇒ PDF đủ trang', () async {
      final out = p.join(dir.path, 'c.pdf');
      final r = _Raster();
      final res = await conv(_deck(), out, r, options: const PptToPdfOptions(includeHidden: true));
      expect(r.slides, [0, 1, 2, 3]);
      expect(res, out);
      expect(pdfPages(out), 4);
    });

    test('U5.P4 token đã huỷ trước ⇒ Cancelled, không gọi rasterizer', () async {
      final out = p.join(dir.path, 'd.pdf');
      final r = _Raster();
      final res = await conv(_deck(), out, r, token: CancelToken()..cancel());
      expect(r.slides, isEmpty);
      expect(res, isA<Cancelled>());
      expect(File(out).existsSync(), isFalse);
    });

    test('U5.P5 createTemp ném (đầy đĩa) ⇒ AppError NoSpace, không gọi rasterizer', () async {
      final out = p.join(dir.path, 'e.pdf');
      final r = _Raster();
      final res = await IOOverrides.runZoned(
        () => conv(_deck(), out, r),
        getSystemTempDirectory: _FullDiskDir.new,
      );
      expect(r.slides, isEmpty);
      expect(res, isA<NoSpace>());
    });

    test('U5.P8 huỷ trong onProgress sau slide đầu ⇒ D7 ném (L153), Cancelled', () async {
      final out = p.join(dir.path, 'f.pdf');
      final token = CancelToken();
      final r = _Raster();
      var first = true;
      final res = await conv(_deck(), out, r, token: token, onProgress: (_) {
        if (first) token.cancel();
        first = false;
      });
      expect(r.slides, [0]);
      expect(res, isA<Cancelled>());
      expect(File(out).existsSync(), isFalse);
    });

    test('U5.P9 rasterizer ném AppError (Cancelled) ⇒ ném lại nguyên lỗi', () async {
      final out = p.join(dir.path, 'g.pdf');
      final r = _Raster(error: const Cancelled());
      final res = await conv(_deck(), out, r, token: CancelToken());
      expect(r.slides, [0]);
      expect(res, isA<Cancelled>());
      expect(File(out).existsSync(), isFalse);
    });

    test('U5.P11 huỷ trong lúc chụp slide 2 ⇒ D10 ném (L159), Cancelled', () async {
      final out = p.join(dir.path, 'h.pdf');
      final token = CancelToken();
      final r = _Raster(onRender: (i) {
        if (i == 1) token.cancel();
      });
      final res = await conv(_deck(), out, r, token: token);
      expect(r.slides, [0, 2]);
      expect(res, isA<Cancelled>());
      expect(File(out).existsSync(), isFalse);
      expect(File('$out.tmp').existsSync(), isFalse);
    });

    test('U5.P12 onProgress null ⇒ chuyển xong', () async {
      final out = p.join(dir.path, 'i.pdf');
      final res = await conv(_deck(), out, _Raster(), token: CancelToken());
      expect(res, out);
      expect(pdfPages(out), 3);
    });

    test('U5.P13 PNG hỏng ⇒ isolate lỗi (U8 List) ⇒ CorruptFile, không để file dở', () async {
      final out = p.join(dir.path, 'j.pdf');
      final r = _Raster(bytes: Uint8List.fromList([1, 2, 3, 4]));
      final res = await conv(_deck(), out, r, token: CancelToken());
      expect(r.slides, [0, 2, 3]);
      expect(res, isA<CorruptFile>());
      expect(File(out).existsSync(), isFalse);
      expect(File('$out.tmp').existsSync(), isFalse);
    });

    test('U5.P14 rasterizer ném lỗi lạ (StateError) ⇒ AppError.from ⇒ Unknown', () async {
      final out = p.join(dir.path, 'k.pdf');
      final r = _Raster(error: StateError('boom'));
      final res = await conv(_deck(), out, r);
      expect(r.slides, [0]);
      expect(res, isA<Unknown>());
    });

    test('U7.P3 huỷ ngay khi chụp xong slide cuối ⇒ _buildPdfInIsolate ném Cancelled (D2)', () async {
      final out = p.join(dir.path, 'l.pdf');
      final token = CancelToken();
      final r = _Raster();
      final res = await conv(_deck(), out, r, token: token, onProgress: (v) {
        if ((v - 0.8).abs() < 1e-9) token.cancel();
      });
      expect(r.slides, [0, 2, 3]);
      expect(res, isA<Cancelled>());
      expect(File(out).existsSync(), isFalse);
    });

    test('U7.P5 huỷ trong lúc spawn isolate (U10 isolate == null) ⇒ Cancelled, xoá file đích', () async {
      final out = p.join(dir.path, 'm.pdf');
      final token = CancelToken();
      final res = await conv(_deck(), out, _Raster(), token: token, onProgress: (v) {
        if ((v - 0.8).abs() < 1e-9) Timer.run(token.cancel);
      });
      expect(res, isA<Cancelled>());
      // Chờ isolate bị kill hẳn rồi mới kiểm file.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(File(out).existsSync(), isFalse);
      expect(File('$out.tmp').existsSync(), isFalse);
    });

    test('U7.P7 huỷ khi isolate đã báo trang đầu (U10 kill) ⇒ Cancelled, xoá đích + .tmp', () async {
      final out = p.join(dir.path, 'n.pdf');
      final token = CancelToken();
      final res = await conv(_deck(), out, _Raster(), token: token, onProgress: (v) {
        if (v > 0.8 + 1e-9) token.cancel();
      });
      expect(res, isA<Cancelled>());
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(File(out).existsSync(), isFalse);
      expect(File('$out.tmp').existsSync(), isFalse);
    });

    test('U12.P2 slide dọc (A4) ⇒ trang PDF dọc 595×842', () async {
      final out = p.join(dir.path, 'o.pdf');
      final res = await conv(_deck(w: 7560000, h: 10692000), out, _Raster());
      expect(res, out);
      final d = sf.PdfDocument(inputBytes: File(out).readAsBytesSync());
      expect(d.pages[0].size.width, closeTo(595.28, 0.5));
      expect(d.pages[0].size.height, closeTo(841.89, 0.5));
      d.dispose();
    });
  });
}
