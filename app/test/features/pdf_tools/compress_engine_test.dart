import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/pdf/pdf_render_engine.dart';
import 'package:pdf_office/features/convert/engine/font_set.dart';
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
  _FakeRender(this.sizes, {this.onRender, this.jpeg});

  /// JPEG trả về cho mọi trang (mặc định ảnh nhỏ theo khổ trang).
  final Uint8List? jpeg;

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
    return owner.jpeg ?? _jpeg((s.width / 10).round(), (s.height / 10).round());
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
      final engine = PdfCompressEngine(requireSaving: false, render: _FakeRender(const []));
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
      final engine = PdfCompressEngine(requireSaving: false, render: _FakeRender(const []));
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
      final engine = PdfCompressEngine(requireSaving: false, render: render, tempRoot: tempRoot);
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
      await PdfCompressEngine(requireSaving: false, render: render, tempRoot: tmp.path).compress(
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
        PdfCompressEngine(requireSaving: false, render: render, tempRoot: tempRoot).compress(
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

  group('Lớp chữ vô hình (Vừa / Mạnh giữ chữ chọn được)', () {
    late Directory tmp;
    const fonts = FileFontSource({
      FontSlot.regular: 'assets/fonts/NotoSans-Regular.ttf',
    });
    setUp(() async => tmp = await Directory.systemTemp.createTemp('compress_txt'));
    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    String textOf(String path, int page) {
      final d = sf.PdfDocument(inputBytes: File(path).readAsBytesSync());
      final t = sf.PdfTextExtractor(d).extractText(startPageIndex: page, endPageIndex: page);
      d.dispose();
      return t;
    }

    for (final level in [CompressLevel.medium, CompressLevel.strong]) {
      test('${level.name}: chữ gốc vẫn trích được ở từng trang', () async {
        final src = await _makePdf(tmp.path, 'a.pdf', 3);
        final out = p.join(tmp.path, 'o.pdf');
        final render = _FakeRender(List.filled(3, const PdfPageSize(595, 842)));
        await PdfCompressEngine(requireSaving: false, render: render, tempRoot: tmp.path, fontSource: fonts)
            .compress(src, out, level);
        for (var i = 0; i < 3; i++) {
          expect(textOf(out, i), contains('Doc page ${i + 1}'));
        }
      });
    }

    test('chữ Việt (NFC) cũng trích được', () async {
      final doc = sf.PdfDocument();
      final font = sf.PdfTrueTypeFont(
        File('assets/fonts/NotoSans-Regular.ttf').readAsBytesSync(),
        18,
      );
      doc.pages.add().graphics.drawString(
        'Tiếng Việt: nén tệp PDF',
        font,
        bounds: const Rect.fromLTWH(20, 20, 400, 30),
      );
      final src = p.join(tmp.path, 'vi.pdf');
      File(src).writeAsBytesSync(await doc.save());
      doc.dispose();
      final out = p.join(tmp.path, 'o.pdf');
      await PdfCompressEngine(requireSaving: false, 
        render: _FakeRender(const [PdfPageSize(595, 842)]),
        tempRoot: tmp.path,
        fontSource: fonts,
      ).compress(src, out, CompressLevel.medium);
      expect(textOf(out, 0), contains('Tiếng Việt'));
    });

    test('thiếu font → vẫn nén được, thành ảnh thuần (không có chữ)', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 1);
      final out = p.join(tmp.path, 'o.pdf');
      await PdfCompressEngine(requireSaving: false, 
        render: _FakeRender(const [PdfPageSize(595, 842)]),
        tempRoot: tmp.path,
        fontSource: const NoFontSource(),
      ).compress(src, out, CompressLevel.medium);
      expect(File(out).existsSync(), isTrue);
      expect(textOf(out, 0).trim(), isEmpty);
    });

    test('trang ảnh quét (không chữ) giữ ảnh, trang có chữ vẫn có lớp chữ', () async {
      final doc = sf.PdfDocument();
      doc.pages.add();
      doc.pages.add().graphics.drawString(
        'Only second',
        sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 18),
        bounds: const Rect.fromLTWH(20, 20, 250, 30),
      );
      final src = p.join(tmp.path, 'm.pdf');
      File(src).writeAsBytesSync(await doc.save());
      doc.dispose();
      final out = p.join(tmp.path, 'o.pdf');
      await PdfCompressEngine(requireSaving: false, 
        render: _FakeRender(const [PdfPageSize(595, 842), PdfPageSize(595, 842)]),
        tempRoot: tmp.path,
        fontSource: fonts,
      ).compress(src, out, CompressLevel.medium);
      expect(textOf(out, 0).trim(), isEmpty);
      expect(textOf(out, 1), contains('Only second'));
    });

    test('Nhẹ không đổi: không render, chữ giữ; không ghi đè file gốc', () async {
      final src = await _makePdf(tmp.path, 'a.pdf', 2);
      final before = File(src).readAsBytesSync();
      final out = p.join(tmp.path, 'o.pdf');
      final render = _FakeRender(const []);
      await PdfCompressEngine(requireSaving: false, render: render, tempRoot: tmp.path, fontSource: fonts)
          .compress(src, out, CompressLevel.light);
      expect(render.renders, isEmpty);
      expect(textOf(out, 1), contains('Doc page 2'));
      expect(File(src).readAsBytesSync(), before);
      expect(
        () => PdfCompressEngine(requireSaving: false, render: render).compress(src, src, CompressLevel.medium),
        throwsArgumentError,
      );
    });

    test('Vừa giảm rõ rệt trên PDF nhiều trang chữ + ảnh lớn, lớp chữ chỉ tốn ít', () async {
      // Ảnh "ảnh chụp": nền chuyển màu + nhiễu nhẹ, nhúng PNG không mất dữ liệu (như PDF xuất từ Office).
      final rnd = math.Random(7);
      final big = img.Image(width: 1400, height: 1900);
      for (final px in big) {
        final n = rnd.nextInt(24);
        px
          ..r = (px.x * 255 ~/ 1400 + n).clamp(0, 255)
          ..g = (px.y * 255 ~/ 1900 + n).clamp(0, 255)
          ..b = (128 + n).clamp(0, 255);
      }
      final png = Uint8List.fromList(img.encodePng(big, level: 6));
      final doc = sf.PdfDocument();
      for (var i = 0; i < 4; i++) {
        final page = doc.pages.add();
        page.graphics.drawImage(sf.PdfBitmap(png), const Rect.fromLTWH(0, 100, 595, 700));
        page.graphics.drawString(
          'Report page ${i + 1} body text ' * 3,
          sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12),
          bounds: const Rect.fromLTWH(20, 20, 550, 60),
        );
      }
      final src = p.join(tmp.path, 'big.pdf');
      File(src).writeAsBytesSync(await doc.save());
      doc.dispose();
      // Render giả: JPEG q70 ~150 dpi của cùng nội dung.
      final jpg = Uint8List.fromList(
        img.encodeJpg(img.copyResize(big, width: 1240, height: 1754), quality: 70),
      );
      final render = _FakeRender(List.filled(4, const PdfPageSize(595, 842)), jpeg: jpg);
      final out = p.join(tmp.path, 'o.pdf');
      final r = await PdfCompressEngine(requireSaving: false, render: render, tempRoot: tmp.path, fontSource: fonts)
          .compress(src, out, CompressLevel.medium);
      final plain = p.join(tmp.path, 'plain.pdf');
      final r2 = await PdfCompressEngine(requireSaving: false, 
        render: render,
        tempRoot: tmp.path,
        fontSource: const NoFontSource(),
      ).compress(src, plain, CompressLevel.medium);
      // ignore: avoid_print
      print('SIZE original=${r.originalBytes} medium+text=${r.outputBytes} '
          'imageOnly=${r2.outputBytes} reduction=${r.percent}%');
      expect(textOf(out, 3), contains('Report page 4'));
      expect(r.percent, greaterThanOrEqualTo(60));
      expect(r.outputBytes - r2.outputBytes, lessThan(150 * 1024));
    });
  });

  group('Không bao giờ ra file to hơn gốc', () {
    late Directory tmp;
    const fonts = FileFontSource({
      FontSlot.regular: 'assets/fonts/NotoSans-Regular.ttf',
    });
    setUp(() async => tmp = await Directory.systemTemp.createTemp('compress_nobig'));
    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    /// PDF chữ thuần nhiều trang (vector, không ảnh).
    Future<String> textOnly(String name, int pages, {bool compress = true}) async {
      final doc = sf.PdfDocument();
      if (!compress) doc.compressionLevel = sf.PdfCompressionLevel.none;
      final font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 11);
      for (var i = 0; i < pages; i++) {
        final page = doc.pages.add();
        for (var k = 0; k < 40; k++) {
          page.graphics.drawString(
            'Page ${i + 1} line $k: the quick brown fox jumps over the lazy dog ${i * k}',
            font,
            bounds: Rect.fromLTWH(30, 20.0 + k * 18, 520, 16),
          );
        }
      }
      final path = p.join(tmp.path, name);
      File(path).writeAsBytesSync(await doc.save());
      doc.dispose();
      return path;
    }

    /// JPEG 150 dpi q70 "thật" của một trang chữ: nền trắng + nhiễu nhẹ → vài chục KB.
    Uint8List pageJpeg() {
      final rnd = math.Random(3);
      final im = img.Image(width: 1240, height: 1754)..clear(img.ColorRgb8(255, 255, 255));
      for (var y = 0; y < 1754; y += 3) {
        for (var x = 0; x < 1240; x += 2) {
          if (rnd.nextInt(5) == 0) im.setPixelRgb(x, y, 40, 40, 40);
        }
      }
      return Uint8List.fromList(img.encodeJpg(im, quality: 70));
    }

    test('PDF chữ thuần (đã nén sẵn): Vừa → không to hơn gốc; không đạt thì không ghi file', () async {
      final src = await textOnly('t.pdf', 12);
      final orig = File(src).lengthSync();
      final out = p.join(tmp.path, 'o.pdf');
      final render = _FakeRender(
        List.filled(12, const PdfPageSize(595, 842)),
        jpeg: pageJpeg(),
      );
      final r = await PdfCompressEngine(
        render: render,
        tempRoot: tmp.path,
        fontSource: fonts,
      ).compress(src, out, CompressLevel.medium);
      // ignore: avoid_print
      print('SIZE text-only original=$orig result=${r.outputBytes} '
          'alreadyOptimal=${r.alreadyOptimal} fellBack=${r.fellBackToLight}');
      expect(r.outputBytes, lessThanOrEqualTo(orig));
      if (r.alreadyOptimal) {
        expect(File(out).existsSync(), isFalse, reason: 'không ghi file khi không nén được');
        expect(r.isSmaller, isFalse);
        expect(r.percent, 0);
      } else {
        expect(File(out).lengthSync(), lessThanOrEqualTo(orig * kMinSavingRatio));
      }
      expect(File('$out.tmp').existsSync(), isFalse);
      expect(Directory(tmp.path).listSync().where((e) => p.basename(e.path).startsWith('compress_')), isEmpty);
    });

    test('PDF chữ thuần cồng kềnh (còn rác sau chỉnh sửa): bản ảnh to hơn → dùng mức Nhẹ, vẫn là vector', () async {
      // 24 trang rồi xoá 12 trang, lưu incremental: file giữ nguyên dữ liệu 12 trang đã xoá.
      final big = await textOnly('big.pdf', 24);
      final d0 = sf.PdfDocument(inputBytes: File(big).readAsBytesSync());
      for (var i = 0; i < 12; i++) {
        d0.pages.removeAt(d0.pages.count - 1);
      }
      final src = p.join(tmp.path, 't.pdf');
      File(src).writeAsBytesSync(await d0.save());
      d0.dispose();
      final orig = File(src).lengthSync();
      final out = p.join(tmp.path, 'o.pdf');
      final render = _FakeRender(
        List.filled(12, const PdfPageSize(595, 842)),
        jpeg: pageJpeg(),
      );
      final r = await PdfCompressEngine(
        render: render,
        tempRoot: tmp.path,
        fontSource: fonts,
      ).compress(src, out, CompressLevel.strong);
      // ignore: avoid_print
      print('SIZE text-only with garbage original=$orig result=${r.outputBytes} '
          'fellBack=${r.fellBackToLight} percent=${r.percent}');
      expect(render.renders, hasLength(12)); // đã thử bản ảnh trước
      expect(r.fellBackToLight, isTrue);
      expect(r.alreadyOptimal, isFalse);
      expect(r.lostAnnotations, 0);
      expect(File(out).lengthSync(), lessThanOrEqualTo(orig * kMinSavingRatio));
      final d = sf.PdfDocument(inputBytes: File(out).readAsBytesSync());
      expect(d.pages.count, 12);
      expect(
        sf.PdfTextExtractor(d).extractText(startPageIndex: 11, endPageIndex: 11),
        contains('Page 12 line 39'),
      );
      d.dispose();
    });

    test('Nhẹ trên file đã tối ưu: không ghi file, alreadyOptimal', () async {
      final src = await textOnly('t.pdf', 3);
      final first = p.join(tmp.path, 'first.pdf');
      await PdfCompressEngine(requireSaving: false, render: _FakeRender(const []))
          .compress(src, first, CompressLevel.light);
      final out = p.join(tmp.path, 'again.pdf');
      final r = await PdfCompressEngine(render: _FakeRender(const []))
          .compress(first, out, CompressLevel.light);
      expect(r.alreadyOptimal, isTrue);
      expect(r.outputBytes, r.originalBytes);
      expect(File(out).existsSync(), isFalse);
      expect(File('$out.tmp').existsSync(), isFalse);
    });
  });

  group('Giữ liên kết và chú thích ở trang dựng ảnh', () {
    late Directory tmp;
    const fonts = FileFontSource({
      FontSlot.regular: 'assets/fonts/NotoSans-Regular.ttf',
    });
    setUp(() async => tmp = await Directory.systemTemp.createTemp('compress_annot'));
    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    /// 2 trang, mỗi trang một ảnh nhiễu lớn (để bản ảnh nhỏ hơn gốc) + chú thích ở trang 1.
    Future<String> withAnnotations() async {
      final rnd = math.Random(5);
      final big = img.Image(width: 1000, height: 1000);
      for (final px in big) {
        px
          ..r = rnd.nextInt(256)
          ..g = rnd.nextInt(256)
          ..b = rnd.nextInt(256);
      }
      final png = Uint8List.fromList(img.encodePng(big, level: 1));
      final doc = sf.PdfDocument();
      final p0 = doc.pages.add();
      final p1 = doc.pages.add();
      for (final pg in [p0, p1]) {
        pg.graphics.drawImage(sf.PdfBitmap(png), const Rect.fromLTWH(0, 100, 500, 500));
      }
      p0.graphics.drawString(
        'Visit link',
        sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 14),
        bounds: const Rect.fromLTWH(50, 50, 100, 20),
      );
      p0.annotations.add(
        sf.PdfUriAnnotation(
          bounds: const Rect.fromLTWH(50, 50, 100, 20),
          uri: 'https://example.com/a',
        ),
      );
      p0.annotations.add(
        sf.PdfDocumentLinkAnnotation(
          const Rect.fromLTWH(200, 50, 80, 20),
          sf.PdfDestination(p1, const Offset(10, 20)),
        ),
      );
      p0.annotations.add(
        sf.PdfTextMarkupAnnotation(
          const Rect.fromLTWH(50, 300, 120, 14),
          'important',
          sf.PdfColor(255, 255, 0),
          author: 'Tester',
          textMarkupAnnotationType: sf.PdfTextMarkupAnnotationType.highlight,
        ),
      );
      p0.annotations.add(
        sf.PdfPopupAnnotation(
          const Rect.fromLTWH(400, 60, 20, 20),
          'a sticky note',
          author: 'Tester',
        ),
      );
      p0.annotations.add(
        sf.PdfRectangleAnnotation(
          const Rect.fromLTWH(300, 400, 80, 40),
          'box',
          color: sf.PdfColor(255, 0, 0),
        ),
      );
      final path = p.join(tmp.path, 'annot.pdf');
      File(path).writeAsBytesSync(await doc.save());
      doc.dispose();
      return path;
    }

    test('URI, liên kết nội bộ, highlight, ghi chú còn ở file kết quả (đúng tỉ lệ); hình vẽ được báo mất', () async {
      final src = await withAnnotations();
      // Nguồn: đọc lại để biết thư viện đọc được những gì.
      final s = sf.PdfDocument(inputBytes: File(src).readAsBytesSync());
      expect(s.pages[0].annotations.count, 5);
      s.dispose();

      final out = p.join(tmp.path, 'o.pdf');
      // Trang ảnh khổ gấp đôi trang gốc (595×842) → toạ độ phải nhân 2.
      final render = _FakeRender(
        List.filled(2, const PdfPageSize(1190, 1684)),
        jpeg: _jpeg(100, 140),
      );
      final r = await PdfCompressEngine(
        render: render,
        tempRoot: tmp.path,
        fontSource: fonts,
      ).compress(src, out, CompressLevel.medium);
      expect(r.alreadyOptimal, isFalse);
      expect(r.lostAnnotations, 1); // hình chữ nhật

      final d = sf.PdfDocument(inputBytes: File(out).readAsBytesSync());
      final page = d.pages[0];
      var uri = 0, goto = 0, mark = 0, note = 0;
      for (var i = 0; i < page.annotations.count; i++) {
        final a = page.annotations[i];
        // Link không viền được thư viện đọc lại thành PdfTextWebLink.
        if (a is sf.PdfUriAnnotation || a is sf.PdfTextWebLink) {
          uri++;
          expect(a is sf.PdfUriAnnotation ? a.uri : (a as sf.PdfTextWebLink).url, 'https://example.com/a');
          expect(a.bounds.left, closeTo(180, 1)); // gốc 90 (thư viện cộng lề 40) × 2
          expect(a.bounds.top, closeTo(180, 1));
          expect(a.bounds.width, closeTo(200, 1));
        } else if (a is sf.PdfDocumentLinkAnnotation) {
          goto++;
          expect(identical(a.destination!.page, d.pages[1]) ||
              a.destination!.page.size == d.pages[1].size, isTrue);
          expect(a.destination!.location.dx, closeTo(100, 1)); // gốc 50 × 2
        } else if (a is sf.PdfTextMarkupAnnotation) {
          mark++;
          expect(a.textMarkupAnnotationType, sf.PdfTextMarkupAnnotationType.highlight);
          expect(a.text, 'important');
        } else if (a is sf.PdfPopupAnnotation) {
          note++;
          expect(a.text, 'a sticky note');
        }
      }
      expect([uri, goto, mark, note], [1, 1, 1, 1]);
      d.dispose();
    });

    test('khổ trang ảnh bằng khổ gốc → toạ độ giữ nguyên', () async {
      final src = await withAnnotations();
      final out = p.join(tmp.path, 'o.pdf');
      await PdfCompressEngine(
        render: _FakeRender(List.filled(2, const PdfPageSize(595, 842)), jpeg: _jpeg(60, 84)),
        tempRoot: tmp.path,
        fontSource: fonts,
      ).compress(src, out, CompressLevel.strong);
      final d = sf.PdfDocument(inputBytes: File(out).readAsBytesSync());
      final uri = [
        for (var i = 0; i < d.pages[0].annotations.count; i++) d.pages[0].annotations[i],
      ].where((a) => a is sf.PdfUriAnnotation || a is sf.PdfTextWebLink).single;
      expect(uri.bounds.left, closeTo(90, 1));
      expect(uri.bounds.width, closeTo(100, 1));
      d.dispose();
    });
  });
}
