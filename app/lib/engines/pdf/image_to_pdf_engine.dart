import '../../core/utils/cancel_token.dart';
import '../../core/utils/page_size.dart';

export '../../core/utils/cancel_token.dart' show CancelToken, ProgressCallback;
export '../../core/utils/page_size.dart' show PageSizeOption;

/// Hướng giấy. `auto` = theo chiều ảnh (ảnh ngang → trang ngang).
enum PageOrientation { portrait, landscape, auto }

/// Lề trang: none = 0pt, small = 18pt, large = 36pt.
enum PageMargin {
  none(0),
  small(18),
  large(36);

  const PageMargin(this.points);
  final double points;
}

/// Tuỳ chọn Ảnh→PDF.
class ImageToPdfOptions {
  const ImageToPdfOptions({
    this.pageSize = PageSizeOption.a4,
    this.orientation = PageOrientation.auto,
    this.margin = PageMargin.none,
    this.jpegQuality = 85,
  });

  final PageSizeOption pageSize;

  /// Bỏ qua khi `pageSize == fit`.
  final PageOrientation orientation;
  final PageMargin margin;

  /// Chất lượng nén JPEG 1–100 (ảnh được nén lại trước khi nhúng).
  final int jpegQuality;
}

/// Kết quả xuất.
class ImageToPdfResult {
  const ImageToPdfResult({
    required this.outputPath,
    required this.pageCount,
    this.skippedImages = const [],
  });

  final String outputPath;
  final int pageCount;

  /// Ảnh hỏng / không đọc được đã bị bỏ qua (path gốc).
  final List<String> skippedImages;
}

/// Tạo PDF từ danh sách ảnh — mỗi ảnh một trang, ảnh căn giữa, giữ tỉ lệ trong vùng trừ lề.
abstract interface class ImageToPdfEngine {
  /// [imagePaths] theo đúng thứ tự trang; nhận JPG/PNG/WebP/HEIC (WebP/HEIC tự đổi sang JPEG,
  /// ảnh lớn thu về cạnh dài ≤ 3000px). Ghi an toàn ra [outputPath] (`.tmp` rồi rename).
  ///
  /// Gọi [onProgress] sau mỗi ảnh; kiểm [cancelToken] giữa các ảnh (huỷ → `Cancelled`,
  /// không để lại file dở). Mọi ảnh đều hỏng → `CorruptFile`.
  Future<ImageToPdfResult> createPdf({
    required List<String> imagePaths,
    required String outputPath,
    ImageToPdfOptions options = const ImageToPdfOptions(),
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  });
}
