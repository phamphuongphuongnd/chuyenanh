import 'dart:typed_data';

import '../../core/utils/cancel_token.dart';

export '../../core/utils/cancel_token.dart' show CancelToken, ProgressCallback;

/// Định dạng ảnh khi render trang.
enum RenderFormat { png, jpg }

/// Kích thước trang tính bằng point (1/72 inch).
class PdfPageSize {
  const PdfPageSize(this.width, this.height);
  final double width;
  final double height;
}

/// Render trang PDF thành ảnh (PDF→ảnh, thumbnail sắp xếp trang).
abstract interface class PdfRenderEngine {
  /// Mở PDF từ file. Có mật khẩu: truyền [password] — impl tự giải mã bằng
  /// `pdfSecurityProvider` ra bytes trong bộ nhớ (pdfx không mở được file có mật khẩu).
  /// Lỗi: `PasswordRequired`, `WrongPassword`, `CorruptFile`.
  Future<PdfRenderDocument> openFile(String path, {String? password});

  /// Mở PDF từ bytes (đã giải mã).
  Future<PdfRenderDocument> openBytes(Uint8List bytes);
}

/// Tài liệu đang mở để render. Nhớ gọi [close].
abstract interface class PdfRenderDocument {
  int get pageCount;

  /// [pageIndex] 0-based.
  Future<PdfPageSize> pageSize(int pageIndex);

  /// Render trang [pageIndex] (0-based) ở [dpi]: pixel = point / 72 × dpi
  /// (xem `pointsToPixels`). Trả về bytes PNG/JPG. [jpgQuality] 1–100.
  Future<Uint8List> renderPage(
    int pageIndex, {
    double dpi = 150,
    RenderFormat format = RenderFormat.png,
    int jpgQuality = 90,
    CancelToken? cancelToken,
  });

  /// Ảnh thu nhỏ: cạnh dài = [maxSide] px.
  Future<Uint8List> renderThumbnail(int pageIndex, {int maxSide = 300});

  Future<void> close();
}
