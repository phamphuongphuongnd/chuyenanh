import 'dart:typed_data';

import 'package:pdf_layout/pdf_layout.dart';
import 'package:pdf_office/engines/pdf/pdf_render_engine.dart';

/// "JPEG" giả theo số trang (writer không giải mã ảnh).
Uint8List fakeJpeg(int page) =>
    Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, page, 0xFF, 0xD9]);

/// Engine render giả: cỡ trang theo [sizes], ghi lại mọi lời gọi, không đụng pdfx.
class FakePptRender implements PdfRenderEngine {
  FakePptRender({
    this.sizes = const [PdfPageSize(595, 842), PdfPageSize(842, 595)],
    this.onRender,
  });

  final List<PdfPageSize> sizes;

  /// Gọi sau khi render trang [page] (test dùng để huỷ giữa chừng).
  final void Function(int page)? onRender;

  final List<String?> openedPasswords = [];
  final List<({int page, double dpi, RenderFormat format})> renders = [];
  int closed = 0;

  @override
  Future<PdfRenderDocument> openFile(String path, {String? password}) async {
    openedPasswords.add(password);
    return _FakeDoc(this);
  }

  @override
  Future<PdfRenderDocument> openBytes(Uint8List bytes) => openFile('');
}

class _FakeDoc implements PdfRenderDocument {
  _FakeDoc(this.owner);

  final FakePptRender owner;

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
    cancelToken?.throwIfCancelled();
    owner.renders.add((page: pageIndex, dpi: dpi, format: format));
    owner.onRender?.call(pageIndex);
    return fakeJpeg(pageIndex + 1);
  }

  @override
  Future<Uint8List> renderThumbnail(int pageIndex, {int maxSide = 300}) async =>
      fakeJpeg(0);

  @override
  Future<void> close() async => owner.closed++;
}

/// Ghi PPTX đồng bộ (không qua isolate) — dùng trong widget test (FakeAsync).
Future<Uint8List> syncPptxEncoder(
  List<PptxImageSlide> slides,
  double slideWidthPt,
  double slideHeightPt,
  String title,
) async => writeImagePptx(
  slides,
  slideWidthPt: slideWidthPt,
  slideHeightPt: slideHeightPt,
  title: title,
);
