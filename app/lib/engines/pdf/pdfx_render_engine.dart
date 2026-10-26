import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdfx/pdfx.dart' as pdfx;

import '../../core/errors/app_error.dart';
import '../../core/utils/page_size.dart';
import 'pdf_render_engine.dart';
import 'pdf_security.dart';

/// Số điểm ảnh tối đa của một ảnh render (≈ 16 MP ≈ 64 MB RGBA) — tránh hết RAM
/// trên máy yếu khi chọn DPI quá cao với trang lớn.
const int kMaxRenderPixels = 16000000;

/// Kích thước ảnh theo pixel.
class RenderSize {
  const RenderSize(this.width, this.height);
  final int width;
  final int height;
}

/// Quy đổi kích thước trang (point) sang pixel ở [dpi]: `point / 72 × dpi`.
/// Vượt [maxPixels] thì thu nhỏ giữ tỉ lệ. Luôn trả về >= 1 mỗi cạnh.
RenderSize computeRenderSize(
  PdfPageSize page,
  double dpi, {
  int maxPixels = kMaxRenderPixels,
}) {
  final safeDpi = dpi.isFinite && dpi > 0 ? dpi : 72.0;
  var w = math.max(1, pointsToPixels(page.width, safeDpi));
  var h = math.max(1, pointsToPixels(page.height, safeDpi));
  if (w * h > maxPixels) {
    final scale = math.sqrt(maxPixels / (w * h));
    w = math.max(1, (w * scale).floor());
    h = math.max(1, (h * scale).floor());
  }
  return RenderSize(w, h);
}

/// Ảnh thu nhỏ: cạnh dài = [maxSide] px, giữ tỉ lệ.
RenderSize computeThumbnailSize(PdfPageSize page, int maxSide) {
  final longest = math.max(page.width, page.height);
  if (longest <= 0) return RenderSize(maxSide, maxSide);
  final scale = maxSide / longest;
  return RenderSize(
    math.max(1, (page.width * scale).round()),
    math.max(1, (page.height * scale).round()),
  );
}

typedef PdfxOpenFile = Future<pdfx.PdfDocument> Function(String path);
typedef PdfxOpenData = Future<pdfx.PdfDocument> Function(Uint8List data);

/// [PdfRenderEngine] dùng `pdfx` (PdfRenderer gốc của Android).
///
/// pdfx không mở được PDF có mật khẩu → khi có mật khẩu, giải mã bằng
/// [PdfSecurityEngine] ra bytes rồi `openData`.
class PdfxRenderEngine implements PdfRenderEngine {
  PdfxRenderEngine({
    required PdfSecurityEngine security,
    PdfxOpenFile? openFile,
    PdfxOpenData? openData,
  }) : _security = security,
       _openFile = openFile ?? pdfx.PdfDocument.openFile,
       _openData = openData ?? ((d) => pdfx.PdfDocument.openData(d));

  final PdfSecurityEngine _security;
  final PdfxOpenFile _openFile;
  final PdfxOpenData _openData;

  @override
  Future<PdfRenderDocument> openFile(String path, {String? password}) async {
    final file = File(path);
    if (password != null && password.isNotEmpty) {
      final Uint8List bytes;
      try {
        bytes = await file.readAsBytes();
      } on FileSystemException catch (e) {
        final err = AppError.from(e);
        throw err is Unknown ? CorruptFile(e.message) : err;
      }
      final plain = await _security.decrypt(bytes, password);
      return openBytes(plain);
    }

    try {
      return _PdfxDocument(await _openFile(path));
    } catch (e) {
      // Phân biệt PDF có mật khẩu với file hỏng.
      final Uint8List bytes;
      try {
        bytes = await file.readAsBytes();
      } on FileSystemException catch (fe) {
        throw CorruptFile(fe.message);
      }
      if (await _security.isEncrypted(bytes)) throw const PasswordRequired();
      throw CorruptFile(e.toString());
    }
  }

  @override
  Future<PdfRenderDocument> openBytes(Uint8List bytes) async {
    try {
      return _PdfxDocument(await _openData(bytes));
    } catch (e) {
      throw CorruptFile(e.toString());
    }
  }
}

/// Android không cho mở song song nhiều trang → xếp hàng mọi thao tác.
class _PdfxDocument implements PdfRenderDocument {
  _PdfxDocument(this._doc);

  final pdfx.PdfDocument _doc;
  Future<void> _tail = Future<void>.value();
  bool _closed = false;

  @override
  int get pageCount => _doc.pagesCount;

  Future<T> _locked<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<T> _withPage<T>(
    int pageIndex,
    Future<T> Function(pdfx.PdfPage page) action,
  ) {
    return _locked(() async {
      if (_closed) throw const CorruptFile('closed');
      if (pageIndex < 0 || pageIndex >= pageCount) {
        throw RangeError.range(pageIndex, 0, pageCount - 1, 'pageIndex');
      }
      final page = await _doc.getPage(pageIndex + 1);
      try {
        return await action(page);
      } finally {
        if (!page.isClosed) await page.close();
      }
    });
  }

  @override
  Future<PdfPageSize> pageSize(int pageIndex) =>
      _withPage(pageIndex, (p) async => PdfPageSize(p.width, p.height));

  Future<Uint8List> _render(
    int pageIndex,
    RenderSize Function(PdfPageSize) sizeFor,
    pdfx.PdfPageImageFormat format,
    int quality,
    CancelToken? cancelToken,
  ) async {
    cancelToken?.throwIfCancelled();
    return _withPage(pageIndex, (page) async {
      cancelToken?.throwIfCancelled();
      final size = sizeFor(PdfPageSize(page.width, page.height));
      final image = await page.render(
        width: size.width.toDouble(),
        height: size.height.toDouble(),
        format: format,
        // PNG mặc định trong suốt → nền trắng như giấy.
        backgroundColor: '#FFFFFF',
        quality: quality,
        forPrint: true,
      );
      if (image == null) throw const CorruptFile('render');
      return image.bytes;
    });
  }

  @override
  Future<Uint8List> renderPage(
    int pageIndex, {
    double dpi = 150,
    RenderFormat format = RenderFormat.png,
    int jpgQuality = 90,
    CancelToken? cancelToken,
  }) => _render(
    pageIndex,
    (s) => computeRenderSize(s, dpi),
    format == RenderFormat.png
        ? pdfx.PdfPageImageFormat.png
        : pdfx.PdfPageImageFormat.jpeg,
    jpgQuality.clamp(1, 100),
    cancelToken,
  );

  @override
  Future<Uint8List> renderThumbnail(int pageIndex, {int maxSide = 300}) =>
      _render(
        pageIndex,
        (s) => computeThumbnailSize(s, maxSide),
        pdfx.PdfPageImageFormat.jpeg,
        80,
        null,
      );

  @override
  Future<void> close() async {
    if (_closed) return;
    // Chờ các thao tác đang xếp hàng xong rồi mới đóng.
    await _locked(() async {
      _closed = true;
      await _doc.close();
    });
  }
}
