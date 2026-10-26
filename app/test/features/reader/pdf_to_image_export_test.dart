import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/pdf/pdf_render_engine.dart';
import 'package:pdf_office/features/reader/logic/pdf_to_image_export.dart';

class _FakeDoc implements PdfRenderDocument {
  _FakeDoc(this.pageCount, {this.failOnPage, this.onRender});

  @override
  final int pageCount;
  final int? failOnPage;
  final void Function(int page)? onRender;
  final List<(int, double, RenderFormat)> calls = [];

  @override
  Future<PdfPageSize> pageSize(int pageIndex) async =>
      const PdfPageSize(595, 842);

  @override
  Future<Uint8List> renderPage(
    int pageIndex, {
    double dpi = 150,
    RenderFormat format = RenderFormat.png,
    int jpgQuality = 90,
    CancelToken? cancelToken,
  }) async {
    if (pageIndex == failOnPage) throw const CorruptFile('boom');
    calls.add((pageIndex, dpi, format));
    onRender?.call(pageIndex);
    return Uint8List.fromList([pageIndex, 1, 2, 3]);
  }

  @override
  Future<Uint8List> renderThumbnail(int pageIndex, {int maxSide = 300}) async =>
      Uint8List(0);

  @override
  Future<void> close() async {}
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('reader_export_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('exportImageName / imageExtension', () {
    test('dem so 0 theo tong so trang, toi thieu 3 chu so', () {
      expect(
        exportImageName('bao cao', 0, 12, RenderFormat.jpg),
        'bao cao_001.jpg',
      );
      expect(
        exportImageName('a', 11, 12, RenderFormat.png),
        'a_012.png',
      );
      expect(
        exportImageName('a', 999, 1200, RenderFormat.png),
        'a_1000.png',
      );
    });

    test('duoi file theo dinh dang', () {
      expect(imageExtension(RenderFormat.png), 'png');
      expect(imageExtension(RenderFormat.jpg), 'jpg');
    });
  });

  group('exportPdfToImages', () {
    test('ghi vao thu muc con theo ten file, moi trang mot anh', () async {
      final doc = _FakeDoc(5);
      final progress = <double>[];
      final result = await exportPdfToImages(
        document: doc,
        pages: [0, 2, 4],
        dpi: 200,
        format: RenderFormat.jpg,
        parentDir: tmp.path,
        baseName: 'Hop dong',
        onProgress: progress.add,
      );
      expect(p.basename(result.directory), 'Hop dong');
      expect(p.dirname(result.directory), tmp.path);
      expect(result.files.map(p.basename), [
        'Hop dong_001.jpg',
        'Hop dong_003.jpg',
        'Hop dong_005.jpg',
      ]);
      for (final f in result.files) {
        expect(await File(f).exists(), isTrue);
      }
      expect(await File(result.files[1]).readAsBytes(), [2, 1, 2, 3]);
      expect(doc.calls.map((c) => c.$1), [0, 2, 4]);
      expect(doc.calls.every((c) => c.$2 == 200), isTrue);
      expect(progress.last, 1.0);
      expect(progress.length, 3);
    });

    test('thu muc trung ten thi them (1)', () async {
      await Directory(p.join(tmp.path, 'a')).create();
      final result = await exportPdfToImages(
        document: _FakeDoc(1),
        pages: [0],
        dpi: 72,
        format: RenderFormat.png,
        parentDir: tmp.path,
        baseName: 'a',
      );
      expect(p.basename(result.directory), 'a (1)');
    });

    test('huy giua chung: xoa thu muc da tao, nem Cancelled', () async {
      final token = CancelToken();
      final doc = _FakeDoc(
        4,
        onRender: (page) {
          if (page == 1) token.cancel();
        },
      );
      await expectLater(
        exportPdfToImages(
          document: doc,
          pages: [0, 1, 2, 3],
          dpi: 100,
          format: RenderFormat.png,
          parentDir: tmp.path,
          baseName: 'x',
          cancelToken: token,
        ),
        throwsA(isA<Cancelled>()),
      );
      expect(tmp.listSync(), isEmpty);
    });

    test('loi render: xoa thu muc do, nem lai loi', () async {
      await expectLater(
        exportPdfToImages(
          document: _FakeDoc(3, failOnPage: 1),
          pages: [0, 1, 2],
          dpi: 100,
          format: RenderFormat.png,
          parentDir: tmp.path,
          baseName: 'x',
        ),
        throwsA(isA<CorruptFile>()),
      );
      expect(tmp.listSync(), isEmpty);
    });

    test('khong co trang nao thi nem ArgumentError', () {
      expect(
        () => exportPdfToImages(
          document: _FakeDoc(3),
          pages: const [],
          dpi: 100,
          format: RenderFormat.png,
          parentDir: tmp.path,
          baseName: 'x',
        ),
        throwsArgumentError,
      );
    });
  });

  group('dpi', () {
    test('muc DPI co san va mac dinh nam trong danh sach', () {
      expect(kDpiPresets, contains(kDefaultDpi));
      expect(kDpiPresets, orderedEquals([...kDpiPresets]..sort()));
    });

    test('kich thuoc anh du kien = point / 72 x dpi', () {
      final size = estimateImageSize(const PdfPageSize(612, 792), 144);
      expect(size.width, 1224);
      expect(size.height, 1584);
    });
  });
}
