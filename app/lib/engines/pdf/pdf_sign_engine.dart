import 'dart:typed_data';
import 'dart:ui';

/// Một chữ ký cần đặt: ảnh PNG (nền trong suốt) vào trang [pageIndex] (0-based),
/// khung [bounds] tính bằng **point PDF, gốc trên-trái** của trang (đã đổi từ toạ độ màn hình).
class SignaturePlacement {
  const SignaturePlacement({
    required this.pageIndex,
    required this.bounds,
    required this.pngBytes,
  });

  final int pageIndex;
  final Rect bounds;
  final Uint8List pngBytes;
}

/// Đổi toạ độ màn hình → toạ độ PDF: [viewRect] là khung chữ ký trên widget hiển thị trang
/// có kích thước [viewSize]; trang PDF có kích thước [pageSize] (point). Hàm thuần.
Rect viewRectToPdfRect(Rect viewRect, Size viewSize, Size pageSize) {
  final sx = pageSize.width / viewSize.width;
  final sy = pageSize.height / viewSize.height;
  return Rect.fromLTRB(
    viewRect.left * sx,
    viewRect.top * sy,
    viewRect.right * sx,
    viewRect.bottom * sy,
  );
}

/// Vẽ ảnh chữ ký lên PDF (bằng `PdfBitmap`).
abstract interface class PdfSignEngine {
  /// Ghi file mới [outputPath] (không ghi đè gốc trừ khi người gọi truyền cùng path —
  /// impl vẫn ghi `.tmp` rồi rename). Có mật khẩu → [password]; kết quả giữ nguyên mật khẩu.
  Future<String> applySignatures(
    String inputPath,
    List<SignaturePlacement> placements,
    String outputPath, {
    String? password,
  });

  /// Kích thước trang [pageIndex] (point) — để đổi toạ độ.
  Future<Size> pageSize(String inputPath, int pageIndex, {String? password});
}
