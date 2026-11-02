// Kiểm thử hộp trắng (Bước 6) cho lib/features/pdf_tools/engine/compress_pdf.dart.
// Mã bộ = mã ở test-output/whitebox/pdf-tools/compress_pdf/buoc-5-du-lieu-thu.md.
// Expected chép từ Bước 5 — không chỉnh cho khớp code; FAIL thật giữ nguyên.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/pdf/pdf_render_engine.dart';
import 'package:pdf_office/features/pdf_tools/engine/compress_pdf.dart';
import 'package:pdf_office/features/pdf_tools/engine/isolate_job.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

Future<String> _makePdf(String dir, String name, int pages, {String? password}) async {
  final doc = sf.PdfDocument();
  for (var i = 0; i < pages; i++) {
    final section = doc.sections!.add();
    section.pageSettings.margins.all = 0;
    section.pageSettings.size = const Size(595, 842);
    section.pages.add().graphics.drawString(
      'Doc page ${i + 1}',
      sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 18),
      bounds: const Rect.fromLTWH(20, 20, 250, 30),
    );
  }
  if (password != null) {
    doc.security.algorithm = sf.PdfEncryptionAlgorithm.aesx256Bit;
    doc.security.userPassword = password;
    doc.security.ownerPassword = password;
  }
  final path = p.join(dir, name);
  await File(path).writeAsBytes(await doc.save());
  doc.dispose();
  return path;
}

Uint8List _jpeg(int w, int h) => Uint8List.fromList(
  img.encodeJpg(img.Image(width: w, height: h)..clear(img.ColorRgb8(200, 30, 30))),
);

/// Render giả, đếm số lần mở / đóng / render.
class _FakeRender implements PdfRenderEngine {
  _FakeRender(this.sizes, {this.openError, this.onRender, this.throwOnCancel = true});

  final List<PdfPageSize> sizes;
  final AppError? openError;
  final void Function(int pageIndex)? onRender;
  final bool throwOnCancel;

  int opened = 0;
  int closed = 0;
  String? openedPassword;
  final renders = <({double dpi, RenderFormat format, int quality})>[];

  @override
  Future<PdfRenderDocument> openFile(String path, {String? password}) async {
    opened++;
    openedPassword = password;
    if (openError != null) throw openError!;
    return _FakeDoc(this);
  }

  @override
  Future<PdfRenderDocument> openBytes(Uint8List bytes) => openFile('');
}

class _FakeDoc implements PdfRenderDocument {
  _FakeDoc(this.o);
  final _FakeRender o;

  @override
  int get pageCount => o.sizes.length;

  @override
  Future<PdfPageSize> pageSize(int pageIndex) async => o.sizes[pageIndex];

  @override
  Future<Uint8List> renderPage(
    int pageIndex, {
    double dpi = 150,
    RenderFormat format = RenderFormat.png,
    int jpgQuality = 90,
    CancelToken? cancelToken,
  }) async {
    o.onRender?.call(pageIndex);
    if (o.throwOnCancel) cancelToken?.throwIfCancelled();
    o.renders.add((dpi: dpi, format: format, quality: jpgQuality));
    final s = o.sizes[pageIndex];
    return _jpeg((s.width / 10).round(), (s.height / 10).round());
  }

  @override
  Future<Uint8List> renderThumbnail(int pageIndex, {int maxSide = 300}) =>
      renderPage(pageIndex);

  @override
  Future<void> close() async => o.closed++;
}

const _a4 = PdfPageSize(595, 842);

void main() {
  group('U1 rasterSettingsFor', () {
    test('U1-1 Nhẹ ⇒ null (không render lại)', () {
      expect(rasterSettingsFor(CompressLevel.light), isNull);
    });
    test('U1-2 Vừa ⇒ có thông số render, chất lượng 1–100', () {
      final m = rasterSettingsFor(CompressLevel.medium);
      expect(m, isNotNull);
      expect(m!.jpegQuality, inInclusiveRange(1, 100));
    });
    test('U1-3 Mạnh ⇒ có thông số, dpi và chất lượng không cao hơn Vừa', () {
      final s = rasterSettingsFor(CompressLevel.strong);
      final m = rasterSettingsFor(CompressLevel.medium)!;
      expect(s, isNotNull);
      expect(s!.dpi, lessThanOrEqualTo(m.dpi));
      expect(s.jpegQuality, lessThanOrEqualTo(m.jpegQuality));
    });
  });

  group('U2 RasterSettings ==', () {
    test('U2-1 khác kiểu ⇒ false', () {
      expect(const RasterSettings(150, 70) == ('x' as Object), isFalse);
    });
    test('U2-2 khác dpi ⇒ false', () {
      expect(const RasterSettings(150, 70) == const RasterSettings(100, 70), isFalse);
    });
    test('U2-3 khác chất lượng ⇒ false', () {
      expect(const RasterSettings(150, 70) == const RasterSettings(150, 50), isFalse);
    });
    test('U2-4 cùng dpi và chất lượng ⇒ true', () {
      // ignore: prefer_const_constructors
      expect(RasterSettings(150, 70) == RasterSettings(150, 70), isTrue);
    });
  });

  group('U3 reductionPercent', () {
    test('U3-1 originalBytes ≤ 0 ⇒ 0', () {
      expect(reductionPercent(0, 10), 0);
      expect(reductionPercent(-5, 0), 0);
    });
    test('U3-2 file mới không nhỏ hơn ⇒ 0', () {
      expect(reductionPercent(1000, 1000), 0);
      expect(reductionPercent(1000, 1500), 0);
    });
    test('U3-3 có giảm ⇒ làm tròn, dưới 0,5% vẫn 1, tối đa 100', () {
      expect(reductionPercent(1000, 400), 60);
      expect(reductionPercent(100000, 99999), 1);
      expect(reductionPercent(1000, 0), 100);
    });
  });

  group('U4/U5/U6 PdfCompressEngine', () {
    late Directory tmp;
    late String work;
    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('wb_compress');
      work = p.join(tmp.path, 'work');
    });
    tearDown(() async {
      try {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      } on FileSystemException {
        // Windows: isolate vừa kill có thể chưa nhả file.
      }
    });

    List<FileSystemEntity> workLeft() =>
        Directory(work).existsSync() ? Directory(work).listSync() : const [];

    test('U4-1 / U6-1 Vừa, không token, không mật khẩu ⇒ kết quả đúng dung lượng', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 1);
      final out = p.join(tmp.path, 'a_c.pdf');
      final render = _FakeRender(const [_a4]);
      final r = await PdfCompressEngine(render: render, tempRoot: work)
          .compress(src, out, CompressLevel.medium)
          .then<Object?>((v) => v, onError: (Object e) => e);
      expect(render.opened, 1);
      expect(render.openedPassword, isNull);
      expect(r, isA<CompressResult>());
      final res = r as CompressResult;
      expect(res.outputPath, out);
      expect(res.originalBytes, File(src).lengthSync());
      expect(res.outputBytes, File(out).lengthSync());
    });

    test('U4-2 token chưa huỷ ⇒ chạy bình thường', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 1);
      final out = p.join(tmp.path, 'a_c.pdf');
      final render = _FakeRender(const [_a4]);
      final r = await PdfCompressEngine(render: render, tempRoot: work)
          .compress(src, out, CompressLevel.medium, cancelToken: CancelToken())
          .then<Object?>((v) => v, onError: (Object e) => e);
      expect(render.renders, hasLength(1));
      expect(r, isA<CompressResult>());
      expect(File(out).existsSync(), isTrue);
    });

    test('U4-3 token đã huỷ trước ⇒ Cancelled, không mở file, không có file ra', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 1);
      final out = p.join(tmp.path, 'a_c.pdf');
      final render = _FakeRender(const [_a4]);
      final r = await PdfCompressEngine(render: render, tempRoot: work)
          .compress(src, out, CompressLevel.medium, cancelToken: CancelToken()..cancel())
          .then<Object?>((v) => v, onError: (Object e) => e);
      expect(render.opened, 0);
      expect(r, isA<Cancelled>());
      expect(File(out).existsSync(), isFalse);
    });

    test('U4-4 / U6-2 file nguồn không tồn tại ⇒ CorruptFile, không mở render', () async {
      final render = _FakeRender(const [_a4]);
      final r = await PdfCompressEngine(render: render, tempRoot: work)
          .compress(p.join(tmp.path, 'missing.pdf'), p.join(tmp.path, 'o.pdf'), CompressLevel.medium)
          .then<Object?>((v) => v, onError: (Object e) => e);
      expect(render.opened, 0);
      expect(r, isA<CorruptFile>());
    });

    test('U4-5 mật khẩu rỗng ⇒ coi như không mật khẩu', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 1);
      final render = _FakeRender(const [_a4]);
      final r = await PdfCompressEngine(render: render, tempRoot: work)
          .compress(src, p.join(tmp.path, 'o.pdf'), CompressLevel.medium, password: '')
          .then<Object?>((v) => v, onError: (Object e) => e);
      expect(render.opened, 1);
      expect(render.openedPassword, isNull);
      expect(r, isA<CompressResult>());
    });

    test('U4-6 có mật khẩu ⇒ truyền mật khẩu cho bộ render', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 1);
      final render = _FakeRender(const [_a4]);
      final r = await PdfCompressEngine(render: render, tempRoot: work)
          .compress(src, p.join(tmp.path, 'o.pdf'), CompressLevel.medium, password: 'pw')
          .then<Object?>((v) => v, onError: (Object e) => e);
      expect(render.openedPassword, 'pw');
      expect(r, isA<CompressResult>());
    });

    test('U4-7 / U7-1 Nhẹ, file có mật khẩu ⇒ file mới không mật khẩu, giữ chữ, gốc không đổi', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 3, password: 'pw');
      final before = File(src).readAsBytesSync();
      final out = p.join(tmp.path, 'a_c.pdf');
      final render = _FakeRender(const []);
      final r = await PdfCompressEngine(render: render, tempRoot: work)
          .compress(src, out, CompressLevel.light, password: 'pw')
          .then<Object?>((v) => v, onError: (Object e) => e);
      expect(render.opened, 0); // không đi nhánh render lại
      expect(r, isA<CompressResult>());
      expect(File(src).readAsBytesSync(), before);
      final d = sf.PdfDocument(inputBytes: File(out).readAsBytesSync());
      expect(d.pages.count, 3);
      expect(
        sf.PdfTextExtractor(d).extractText(startPageIndex: 1, endPageIndex: 1),
        contains('Doc page 2'),
      );
      d.dispose();
    });

    test('U4-8 / U7-2 Nhẹ, sai mật khẩu ⇒ WrongPassword, không để lại file', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 1, password: 'pw');
      final out = p.join(tmp.path, 'a_c.pdf');
      final render = _FakeRender(const []);
      final r = await PdfCompressEngine(render: render, tempRoot: work)
          .compress(src, out, CompressLevel.light, password: 'nope')
          .then<Object?>((v) => v, onError: (Object e) => e);
      expect(render.opened, 0);
      expect(r, isA<WrongPassword>());
      expect(File(out).existsSync(), isFalse);
      expect(File('$out.tmp').existsSync(), isFalse);
    });

    test('U4-9 / U5-3 render mở lỗi ⇒ ném lại lỗi đó, không đóng tài liệu, dọn tạm', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 1);
      final out = p.join(tmp.path, 'o.pdf');
      final render = _FakeRender(const [_a4], openError: const WrongPassword());
      final r = await PdfCompressEngine(render: render, tempRoot: work)
          .compress(src, out, CompressLevel.medium, password: 'x')
          .then<Object?>((v) => v, onError: (Object e) => e);
      expect(render.opened, 1);
      expect(render.closed, 0);
      expect(r, isA<WrongPassword>());
      expect(workLeft(), isEmpty);
      expect(File(out).existsSync(), isFalse);
    });

    test('U4-10 file kết quả biến mất trước khi đo ⇒ CorruptFile', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 1);
      final out = p.join(tmp.path, 'o.pdf');
      final render = _FakeRender(const [_a4]);
      var deleted = false;
      final r = await PdfCompressEngine(render: render, tempRoot: work)
          .compress(
            src,
            out,
            CompressLevel.medium,
            onProgress: (v) {
              if (v >= 1.0 && File(out).existsSync()) {
                File(out).deleteSync();
                deleted = true;
              }
            },
          )
          .then<Object?>((v) => v, onError: (Object e) => e);
      expect(deleted, isTrue);
      expect(r, isA<CorruptFile>());
    });

    test('U4-11 (phát hiện) output trùng input ⇒ không đụng file gốc', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 2);
      final before = File(src).readAsBytesSync();
      final render = _FakeRender(const []);
      final r = await PdfCompressEngine(render: render, tempRoot: work)
          .compress(src, src, CompressLevel.light)
          .then<Object?>((v) => v, onError: (Object e) => e);
      printOnFailure('kết quả: $r');
      expect(File(src).readAsBytesSync(), before);
    });

    // U6-3 (lỗi quyền khi đọc dung lượng ⇒ giữ PermissionDenied) không tái hiện được trên Windows:
    // đường dẫn thư mục cho FileSystemException mã khác 1/5/13 ⇒ ra CorruptFile (nhánh D2 Đ). Xem buoc-6.

    test('U5-1 tempRoot có, 2 trang dọc/ngang, không token/tiến độ ⇒ mỗi trang 1 ảnh đúng khổ, dọn tạm', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 2);
      final out = p.join(tmp.path, 'o.pdf');
      final render = _FakeRender(const [_a4, PdfPageSize(842, 595)]);
      final r = await PdfCompressEngine(render: render, tempRoot: work)
          .compress(src, out, CompressLevel.strong)
          .then<Object?>((v) => v, onError: (Object e) => e);
      expect(render.renders, hasLength(2));
      expect(render.renders.every((x) => x.format == RenderFormat.jpg), isTrue);
      expect(render.closed, 1);
      expect(workLeft(), isEmpty);
      expect(r, isA<CompressResult>());
      final d = sf.PdfDocument(inputBytes: File(out).readAsBytesSync());
      expect(d.pages.count, 2);
      expect(d.pages[0].size.width, closeTo(595, 1));
      expect(d.pages[0].size.height, closeTo(842, 1));
      expect(d.pages[1].size.width, closeTo(842, 1));
      expect(d.pages[1].size.height, closeTo(595, 1));
      d.dispose();
    });

    test('U5-2 không có tempRoot ⇒ dùng thư mục tạm hệ thống, vẫn ra kết quả', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 1);
      final out = p.join(tmp.path, 'o.pdf');
      final render = _FakeRender(const [_a4]);
      final r = await PdfCompressEngine(render: render)
          .compress(src, out, CompressLevel.medium)
          .then<Object?>((v) => v, onError: (Object e) => e);
      expect(render.renders, hasLength(1));
      expect(render.closed, 1);
      expect(r, isA<CompressResult>());
      expect(File(out).existsSync(), isTrue);
    });

    test('U5-4 tài liệu 0 trang ⇒ CorruptFile, đóng tài liệu, dọn tạm', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 1);
      final out = p.join(tmp.path, 'o.pdf');
      final render = _FakeRender(const []);
      final r = await PdfCompressEngine(render: render, tempRoot: work)
          .compress(src, out, CompressLevel.medium)
          .then<Object?>((v) => v, onError: (Object e) => e);
      expect(render.renders, isEmpty);
      expect(render.closed, 1);
      expect(r, isA<CorruptFile>());
      expect(workLeft(), isEmpty);
      expect(File(out).existsSync(), isFalse);
    });

    test('U5-6 token chưa huỷ, 2 trang ⇒ render đủ, đóng 1 lần', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 2);
      final out = p.join(tmp.path, 'o.pdf');
      final render = _FakeRender(const [_a4, _a4]);
      final r = await PdfCompressEngine(render: render, tempRoot: work)
          .compress(src, out, CompressLevel.medium, cancelToken: CancelToken())
          .then<Object?>((v) => v, onError: (Object e) => e);
      expect(render.renders, hasLength(2));
      expect(render.closed, 1);
      expect(r, isA<CompressResult>());
    });

    test('U5-7 huỷ sau trang 1 (qua tiến độ) ⇒ Cancelled trước khi render trang 2, đóng tài liệu, dọn tạm', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 3);
      final out = p.join(tmp.path, 'o.pdf');
      final token = CancelToken();
      final render = _FakeRender(const [_a4, _a4, _a4]);
      final r = await PdfCompressEngine(render: render, tempRoot: work)
          .compress(
            src,
            out,
            CompressLevel.medium,
            cancelToken: token,
            onProgress: (_) => token.cancel(),
          )
          .then<Object?>((v) => v, onError: (Object e) => e);
      expect(render.renders, hasLength(1));
      expect(render.closed, 1);
      expect(r, isA<Cancelled>());
      expect(workLeft(), isEmpty);
      expect(File(out).existsSync(), isFalse);
    });

    test('U5-8 có onProgress ⇒ tiến độ không giảm, kết thúc 1.0', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 2);
      final out = p.join(tmp.path, 'o.pdf');
      final render = _FakeRender(const [_a4, _a4]);
      final progress = <double>[];
      final r = await PdfCompressEngine(render: render, tempRoot: work)
          .compress(src, out, CompressLevel.medium, onProgress: progress.add)
          .then<Object?>((v) => v, onError: (Object e) => e);
      expect(r, isA<CompressResult>());
      expect(progress, isNotEmpty);
      for (var i = 1; i < progress.length; i++) {
        expect(progress[i], greaterThanOrEqualTo(progress[i - 1] - 1e-9));
      }
      expect(progress.last, closeTo(1.0, 1e-9));
    });

    test('U5-9 renderPage ném Cancelled ⇒ Cancelled, đóng tài liệu, dọn tạm', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 3);
      final out = p.join(tmp.path, 'o.pdf');
      final token = CancelToken();
      final render = _FakeRender(const [_a4, _a4, _a4], onRender: (i) {
        if (i == 1) token.cancel();
      });
      final r = await PdfCompressEngine(render: render, tempRoot: work)
          .compress(src, out, CompressLevel.medium, cancelToken: token)
          .then<Object?>((v) => v, onError: (Object e) => e);
      expect(render.renders, hasLength(1));
      expect(render.closed, 1);
      expect(r, isA<Cancelled>());
      expect(workLeft(), isEmpty);
    });

    test('U5-10 huỷ trong lúc render nhưng render không ném ⇒ kiểm sau render ném Cancelled', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 2);
      final out = p.join(tmp.path, 'o.pdf');
      final token = CancelToken();
      final render = _FakeRender(
        const [_a4, _a4],
        throwOnCancel: false,
        onRender: (i) => token.cancel(),
      );
      final r = await PdfCompressEngine(render: render, tempRoot: work)
          .compress(src, out, CompressLevel.medium, cancelToken: token)
          .then<Object?>((v) => v, onError: (Object e) => e);
      expect(render.renders, hasLength(1));
      expect(render.closed, 1);
      expect(r, isA<Cancelled>());
      expect(workLeft(), isEmpty);
    });

    test('U5-12 huỷ sau trang cuối ⇒ bước dựng PDF ném Cancelled, đã render đủ, không có file ra', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 2);
      final out = p.join(tmp.path, 'o.pdf');
      final token = CancelToken();
      final render = _FakeRender(const [_a4, _a4]);
      final r = await PdfCompressEngine(render: render, tempRoot: work)
          .compress(
            src,
            out,
            CompressLevel.medium,
            cancelToken: token,
            onProgress: (v) {
              if (v >= 0.8 - 1e-9) token.cancel();
            },
          )
          .then<Object?>((v) => v, onError: (Object e) => e);
      expect(render.renders, hasLength(2));
      expect(render.closed, 1);
      expect(r, isA<Cancelled>());
      expect(File(out).existsSync(), isFalse);
      expect(workLeft(), isEmpty);
    });
  });

  group('U8 compressRasterBuildJob (gọi qua runIsolateJob)', () {
    late Directory tmp;
    setUp(() async => tmp = await Directory.systemTemp.createTemp('wb_rbuild'));
    tearDown(() async {
      try {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      } on FileSystemException {
        // bỏ qua
      }
    });

    Future<String> jpgFile(String name, int w, int h) async {
      final path = p.join(tmp.path, name);
      await File(path).writeAsBytes(_jpeg(w, h));
      return path;
    }

    Future<Object?> run(List<String> images, List<double> w, List<double> h, String out) =>
        runIsolateJob(compressRasterBuildJob, {
          'images': images,
          'widths': w,
          'heights': h,
          'output': out,
        }).then<Object?>((v) => v, onError: (Object e) => e);

    test('U8-1 1 ảnh khổ 595×842 ⇒ 1 trang dọc đúng khổ', () async {
      final out = p.join(tmp.path, 'o.pdf');
      final r = await run([await jpgFile('a.jpg', 60, 84)], [595.0], [842.0], out);
      expect(r, out);
      final d = sf.PdfDocument(inputBytes: File(out).readAsBytesSync());
      expect(d.pages.count, 1);
      expect(d.pages[0].size.width, closeTo(595, 1));
      expect(d.pages[0].size.height, closeTo(842, 1));
      d.dispose();
    });

    test('U8-2 không có ảnh ⇒ ArgumentError', () async {
      final out = p.join(tmp.path, 'o.pdf');
      final r = await run([], [], [], out);
      expect(r, isA<ArgumentError>());
      expect(File(out).existsSync(), isFalse);
    });

    test('U8-3 số khổ rộng lệch số ảnh ⇒ ArgumentError', () async {
      final out = p.join(tmp.path, 'o.pdf');
      final r = await run([await jpgFile('a.jpg', 6, 8)], [], [842.0], out);
      expect(r, isA<ArgumentError>());
      expect(File(out).existsSync(), isFalse);
    });

    test('U8-4 số khổ cao lệch số ảnh ⇒ ArgumentError', () async {
      final out = p.join(tmp.path, 'o.pdf');
      final r = await run([await jpgFile('a.jpg', 6, 8)], [595.0], [842.0, 842.0], out);
      expect(r, isA<ArgumentError>());
      expect(File(out).existsSync(), isFalse);
    });

    test('U8-6 khổ rộng 0 ⇒ vẫn dựng được trang khổ dương', () async {
      final out = p.join(tmp.path, 'o.pdf');
      final r = await run([await jpgFile('a.jpg', 6, 8)], [0.0], [842.0], out);
      expect(r, out);
      final d = sf.PdfDocument(inputBytes: File(out).readAsBytesSync());
      expect(d.pages.count, 1);
      expect(d.pages[0].size.width, greaterThan(0));
      d.dispose();
    });

    test('U8-7 khổ cao 0 ⇒ vẫn dựng được trang khổ dương', () async {
      final out = p.join(tmp.path, 'o.pdf');
      final r = await run([await jpgFile('a.jpg', 6, 8)], [595.0], [0.0], out);
      expect(r, out);
      final d = sf.PdfDocument(inputBytes: File(out).readAsBytesSync());
      expect(d.pages.count, 1);
      expect(d.pages[0].size.height, greaterThan(0));
      d.dispose();
    });

    test('U8-8 khổ ngang 842×595 ⇒ trang ngang đúng khổ', () async {
      final out = p.join(tmp.path, 'o.pdf');
      final r = await run([await jpgFile('a.jpg', 84, 60)], [842.0], [595.0], out);
      expect(r, out);
      final d = sf.PdfDocument(inputBytes: File(out).readAsBytesSync());
      expect(d.pages[0].size.width, closeTo(842, 1));
      expect(d.pages[0].size.height, closeTo(595, 1));
      d.dispose();
    });
  });
}
