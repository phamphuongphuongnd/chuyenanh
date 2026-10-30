import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/pdf/pdf_render_engine.dart';
import 'package:pdf_office/features/pdf_tools/engine/compress_pdf.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// PDF mẫu: trang i có chữ `Doc page <i+1>`, khổ lấy từ [sizes] (xoay vòng).
Future<String> _makePdf(
  String dir,
  String name,
  int pages, {
  List<Size> sizes = const [Size(595, 842)],
  String? password,
}) async {
  final doc = sf.PdfDocument();
  for (var i = 0; i < pages; i++) {
    final section = doc.sections!.add();
    section.pageSettings.margins.all = 0;
    final size = sizes[i % sizes.length];
    section.pageSettings.orientation = size.width > size.height
        ? sf.PdfPageOrientation.landscape
        : sf.PdfPageOrientation.portrait;
    section.pageSettings.size = size;
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

/// Render giả: khổ trang theo [sizes], trả JPEG nhỏ, ghi lại dpi/chất lượng/định dạng.
class _FakeRender implements PdfRenderEngine {
  _FakeRender(this.sizes, {this.onRender});

  final List<PdfPageSize> sizes;

  /// Gọi trước khi render trang (vd. để huỷ giữa chừng).
  final void Function(int pageIndex)? onRender;

  final List<({double dpi, RenderFormat format, int quality})> renders = [];
  String? openedPassword;
  int closed = 0;

  @override
  Future<PdfRenderDocument> openFile(String path, {String? password}) async {
    openedPassword = password;
    return _FakeDoc(this);
  }

  @override
  Future<PdfRenderDocument> openBytes(Uint8List bytes) => openFile('');
}

class _FakeDoc implements PdfRenderDocument {
  _FakeDoc(this.owner);
  final _FakeRender owner;

  @override
  int get pageCount => owner.sizes.length;

  @override
  Future<PdfPageSize> pageSize(int pageIndex) async => owner.sizes[pageIndex];

  @override
  Future<Uint8List> renderPage(
    int pageIndex, {
    double dpi = 150,
    RenderFormat format = RenderFormat.png,
    int jpgQuality = 90,
    CancelToken? cancelToken,
  }) async {
    owner.onRender?.call(pageIndex);
    cancelToken?.throwIfCancelled();
    owner.renders.add((dpi: dpi, format: format, quality: jpgQuality));
    final s = owner.sizes[pageIndex];
    return _jpeg((s.width / 10).round(), (s.height / 10).round());
  }

  @override
  Future<Uint8List> renderThumbnail(int pageIndex, {int maxSide = 300}) =>
      renderPage(pageIndex);

  @override
  Future<void> close() async => owner.closed++;
}

void main() {
  group('hàm thuần', () {
    test('thông số theo mức: Nhẹ không render, Vừa 150/70, Mạnh 100/50', () {
      expect(rasterSettingsFor(CompressLevel.light), isNull);
      expect(
        rasterSettingsFor(CompressLevel.medium),
        const RasterSettings(150, 70),
      );
      expect(
        rasterSettingsFor(CompressLevel.strong),
        const RasterSettings(100, 50),
      );
      expect(compressLevelRasterizes(CompressLevel.light), isFalse);
      expect(compressLevelRasterizes(CompressLevel.medium), isTrue);
      expect(compressLevelRasterizes(CompressLevel.strong), isTrue);
    });

    test('% giảm: làm tròn, không âm, có giảm thì tối thiểu 1', () {
      expect(reductionPercent(1000, 400), 60);
      expect(reductionPercent(1000, 333), 67); // 66,7 → 67
      expect(reductionPercent(1000, 0), 100);
      expect(reductionPercent(1000, 1000), 0); // bằng nhau
      expect(reductionPercent(1000, 1500), 0); // to hơn
      expect(reductionPercent(100000, 99999), 1); // 0,001% vẫn báo 1
      expect(reductionPercent(0, 10), 0);
      expect(reductionPercent(-5, 0), 0);
    });

    test('CompressResult.isSmaller / percent', () {
      const a = CompressResult(outputPath: 'x', originalBytes: 200, outputBytes: 50);
      expect(a.isSmaller, isTrue);
      expect(a.percent, 75);
      const b = CompressResult(outputPath: 'x', originalBytes: 200, outputBytes: 200);
      expect(b.isSmaller, isFalse);
      expect(b.percent, 0);
    });

    test('tên kết quả <tên>_compressed', () {
      expect(compressedBaseName('/a/b/report.pdf'), 'report_compressed');
      expect(compressedBaseName('báo cáo.PDF'), 'báo cáo_compressed');
    });
  });

  group('PdfCompressEngine', () {
    late Directory tmp;
    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('compress_test');
    });
    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('Nhẹ: file có mật khẩu → file mới không mật khẩu, giữ chữ, gốc không đổi', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 3, password: 'pw');
      final before = File(src).readAsBytesSync();
      final out = p.join(tmp.path, 'a_compressed.pdf');
      final engine = PdfCompressEngine(render: _FakeRender(const []));
      final progress = <double>[];
      final r = await engine.compress(
        src,
        out,
        CompressLevel.light,
        password: 'pw',
        onProgress: progress.add,
      );
      expect(r.outputPath, out);
      expect(r.originalBytes, before.length);
      expect(r.outputBytes, File(out).lengthSync());
      expect(File(src).readAsBytesSync(), before);
      expect(progress.last, 1.0);

      final doc = sf.PdfDocument(inputBytes: File(out).readAsBytesSync());
      expect(doc.pages.count, 3);
      expect(
        sf.PdfTextExtractor(doc).extractText(startPageIndex: 1, endPageIndex: 1),
        contains('Doc page 2'),
      );
      doc.dispose();
    });

    test('Nhẹ: sai mật khẩu → WrongPassword, không để lại file', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 1, password: 'pw');
      final out = p.join(tmp.path, 'a_compressed.pdf');
      final engine = PdfCompressEngine(render: _FakeRender(const []));
      await expectLater(
        engine.compress(src, out, CompressLevel.light, password: 'nope'),
        throwsA(isA<WrongPassword>()),
      );
      expect(File(out).existsSync(), isFalse);
      expect(File('$out.tmp').existsSync(), isFalse);
    });

    test('Mạnh: render JPEG 100 dpi/q50, mỗi trang một ảnh đúng khổ gốc, dọn ảnh tạm', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 2);
      final out = p.join(tmp.path, 'out', 'a_compressed.pdf');
      final tempRoot = p.join(tmp.path, 'work');
      final render = _FakeRender(const [
        PdfPageSize(595, 842),
        PdfPageSize(842, 595),
      ]);
      final engine = PdfCompressEngine(render: render, tempRoot: tempRoot);
      final progress = <double>[];
      final r = await engine.compress(
        src,
        out,
        CompressLevel.strong,
        password: 'pw',
        onProgress: progress.add,
      );
      expect(render.openedPassword, 'pw');
      expect(render.renders, hasLength(2));
      for (final x in render.renders) {
        expect(x.dpi, 100);
        expect(x.quality, 50);
        expect(x.format, RenderFormat.jpg);
      }
      expect(render.closed, 1);
      expect(Directory(tempRoot).listSync(), isEmpty);
      expect(r.outputBytes, File(out).lengthSync());
      for (var i = 1; i < progress.length; i++) {
        expect(progress[i], greaterThanOrEqualTo(progress[i - 1] - 1e-9));
      }
      expect(progress.last, closeTo(1.0, 1e-9));

      final doc = sf.PdfDocument(inputBytes: File(out).readAsBytesSync());
      expect(doc.pages.count, 2);
      expect(doc.pages[0].size.width, closeTo(595, 1));
      expect(doc.pages[0].size.height, closeTo(842, 1));
      expect(doc.pages[1].size.width, closeTo(842, 1));
      expect(doc.pages[1].size.height, closeTo(595, 1));
      doc.dispose();
    });

    test('Vừa: dùng 150 dpi/q70', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 1);
      final render = _FakeRender(const [PdfPageSize(612, 792)]);
      await PdfCompressEngine(render: render, tempRoot: tmp.path).compress(
        src,
        p.join(tmp.path, 'o.pdf'),
        CompressLevel.medium,
      );
      expect(render.renders.single.dpi, 150);
      expect(render.renders.single.quality, 70);
    });

    test('huỷ giữa lúc render → Cancelled, không có file ra, đóng tài liệu, dọn tạm', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 3);
      final out = p.join(tmp.path, 'a_compressed.pdf');
      final tempRoot = p.join(tmp.path, 'work');
      final token = CancelToken();
      final render = _FakeRender(
        const [PdfPageSize(595, 842), PdfPageSize(595, 842), PdfPageSize(595, 842)],
        onRender: (i) {
          if (i == 1) token.cancel();
        },
      );
      await expectLater(
        PdfCompressEngine(render: render, tempRoot: tempRoot).compress(
          src,
          out,
          CompressLevel.medium,
          cancelToken: token,
        ),
        throwsA(isA<Cancelled>()),
      );
      expect(File(out).existsSync(), isFalse);
      expect(render.closed, 1);
      expect(Directory(tempRoot).listSync(), isEmpty);
    });
  });
}
