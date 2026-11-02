// Kiểm thử hộp trắng (A09 · reader) — pdf_to_image_export.dart.
// Bộ dữ liệu + expected chép từ test-output/whitebox/reader/pdf_to_image_export/buoc-5-du-lieu-thu.md.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/pdf/pdf_render_engine.dart';
import 'package:pdf_office/features/reader/logic/pdf_to_image_export.dart';

class _Doc implements PdfRenderDocument {
  _Doc(this.pageCount, {this.failOnPage, this.onRender});
  @override
  final int pageCount;
  final int? failOnPage;
  final void Function(int page)? onRender;
  final rendered = <int>[];

  @override
  Future<Uint8List> renderPage(
    int pageIndex, {
    double dpi = 150,
    RenderFormat format = RenderFormat.png,
    int jpgQuality = 90,
    CancelToken? cancelToken,
  }) async {
    onRender?.call(pageIndex);
    if (pageIndex == failOnPage) throw const CorruptFile('boom');
    rendered.add(pageIndex);
    return Uint8List.fromList([pageIndex, 1, 2]);
  }

  @override
  Future<PdfPageSize> pageSize(int pageIndex) async => const PdfPageSize(595, 842);
  @override
  Future<Uint8List> renderThumbnail(int pageIndex, {int maxSide = 300}) async => Uint8List(0);
  @override
  Future<void> close() async {}
}

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('wb_a09_export_'));
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<Object> run(
    _Doc doc,
    List<int> pages, {
    CancelToken? token,
    ProgressCallback? onProgress,
    RenderFormat format = RenderFormat.png,
  }) => exportPdfToImages(
    document: doc,
    pages: pages,
    dpi: 150,
    format: format,
    parentDir: tmp.path,
    baseName: 'x',
    cancelToken: token,
    onProgress: onProgress,
  ).then((r) => r as Object, onError: (Object e) => e);

  group('imageExtension', () {
    test('IE-1 PNG ⇒ "png"', () => expect(imageExtension(RenderFormat.png), 'png'));
    test('IE-2 JPG ⇒ "jpg"', () => expect(imageExtension(RenderFormat.jpg), 'jpg'));
  });

  group('exportImageName', () {
    test('EN-1 tổng < 100 trang ⇒ đệm tối thiểu 3 chữ số', () {
      expect(exportImageName('bao cao', 0, 12, RenderFormat.jpg), 'bao cao_001.jpg');
      expect(exportImageName('a', 98, 99, RenderFormat.png), 'a_099.png');
    });
    test('EN-2 tổng ≥ 100 trang ⇒ đệm theo số chữ số của tổng', () {
      expect(exportImageName('a', 99, 100, RenderFormat.png), 'a_100.png');
      expect(exportImageName('a', 0, 1200, RenderFormat.png), 'a_0001.png');
      expect(exportImageName('a', 999, 1200, RenderFormat.jpg), 'a_1000.jpg');
    });
  });

  group('exportPdfToImages', () {
    test('EX-1 1 trang, không token, không tiến độ ⇒ 1 ảnh trong thư mục con "x"', () async {
      final doc = _Doc(1);
      final r = await run(doc, [0]);
      expect(doc.rendered, [0]);
      expect(r, isA<PdfExportResult>());
      final res = r as PdfExportResult;
      expect(res.directory, p.join(tmp.path, 'x'));
      expect(res.files.map(p.basename), ['x_001.png']);
      expect(File(res.files.single).existsSync(), isTrue);
    });

    test('EX-2 pages rỗng ⇒ ném lỗi, không tạo thư mục/ảnh', () async {
      final doc = _Doc(3);
      final r = await run(doc, const []);
      expect(doc.rendered, isEmpty);
      expect(r, isNot(isA<PdfExportResult>()));
      expect(tmp.listSync(), isEmpty);
    });

    test('EX-3 có token chưa huỷ ⇒ xuất đủ', () async {
      final doc = _Doc(2);
      final r = await run(doc, [0, 1], token: CancelToken());
      expect(doc.rendered, [0, 1]);
      expect((r as PdfExportResult).files.map(p.basename), ['x_001.png', 'x_002.png']);
    });

    test('EX-4 token đã huỷ từ trước ⇒ Cancelled, không render, không tạo thư mục', () async {
      final doc = _Doc(2);
      final token = CancelToken()..cancel();
      final r = await run(doc, [0, 1], token: token);
      expect(doc.rendered, isEmpty);
      expect(r, isA<Cancelled>());
      expect(tmp.listSync(), isEmpty);
    });

    test('EX-5 3 trang [0,2,4] / 5 ⇒ 3 ảnh đúng thứ tự trang', () async {
      final doc = _Doc(5);
      final r = await run(doc, [0, 2, 4], format: RenderFormat.jpg);
      expect(doc.rendered, [0, 2, 4]);
      expect((r as PdfExportResult).files.map(p.basename), ['x_001.jpg', 'x_003.jpg', 'x_005.jpg']);
    });

    test('EX-7 huỷ trong lúc render trang 0 ⇒ Cancelled, dừng trước trang 1, xoá thư mục', () async {
      final token = CancelToken();
      final doc = _Doc(2, onRender: (pg) {
        if (pg == 0) token.cancel();
      });
      final r = await run(doc, [0, 1], token: token);
      expect(doc.rendered, [0]);
      expect(r, isA<Cancelled>());
      expect(tmp.listSync(), isEmpty);
    });

    test('EX-8 render trang 1 lỗi ⇒ ném lại CorruptFile, xoá thư mục dở', () async {
      final doc = _Doc(3, failOnPage: 1);
      final r = await run(doc, [0, 1, 2]);
      expect(doc.rendered, [0]);
      expect(r, isA<CorruptFile>());
      expect(tmp.listSync(), isEmpty);
    });

    test('EX-9 có onProgress ⇒ báo 1/3, 2/3, 1.0', () async {
      final progress = <double>[];
      final r = await run(_Doc(3), [0, 1, 2], onProgress: progress.add);
      expect(r, isA<PdfExportResult>());
      expect(progress, [1 / 3, 2 / 3, 1.0]);
    });

    test('EX-10 thư mục đã mất trước khi lỗi ⇒ vẫn ném lại đúng lỗi gốc', () async {
      final doc = _Doc(2, failOnPage: 0, onRender: (_) {
        final d = Directory(p.join(tmp.path, 'x'));
        if (d.existsSync()) d.deleteSync(recursive: true);
      });
      final r = await run(doc, [0, 1]);
      expect(Directory(p.join(tmp.path, 'x')).existsSync(), isFalse);
      expect(r, isA<CorruptFile>());
    });
  });
}
