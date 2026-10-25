import 'dart:typed_data';

import '../../core/utils/cancel_token.dart';
import '../../core/utils/page_size.dart';

export '../../core/utils/cancel_token.dart' show CancelToken, ProgressCallback;
export '../../core/utils/page_size.dart' show PageSizeOption;

/// Khoảng trang 1-based, gồm cả hai đầu (`PageRange(1, 3)` = trang 1,2,3).
class PageRange {
  const PageRange(this.start, this.end) : assert(start >= 1 && end >= start);
  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is PageRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '$start-$end';
}

/// Cách tách PDF.
sealed class SplitMode {
  const SplitMode();
}

/// Mỗi trang một file.
final class SplitEveryPage extends SplitMode {
  const SplitEveryPage();
}

/// Mỗi khoảng một file (vd. `1-3, 4-4, 5-10`).
final class SplitByRanges extends SplitMode {
  const SplitByRanges(this.ranges);
  final List<PageRange> ranges;
}

/// Mỗi N trang một file.
final class SplitEveryN extends SplitMode {
  const SplitEveryN(this.pagesPerFile) : assert(pagesPerFile >= 1);
  final int pagesPerFile;
}

/// Một trang của tài liệu kết quả khi sắp xếp: lấy trang [sourceIndex] (0-based) của file
/// gốc, xoay thêm [rotation] độ (0/90/180/270). Thứ tự trong list = thứ tự mới;
/// trang không có trong list = bị xoá; list con = trích trang.
class PageOp {
  const PageOp(this.sourceIndex, {this.rotation = 0});
  final int sourceIndex;
  final int rotation;
}

/// Watermark chữ ([text]) hoặc ảnh ([imageBytes] PNG/JPG) — đúng một trong hai.
class WatermarkSpec {
  const WatermarkSpec.text(
    String this.text, {
    this.fontSize = 48,
    this.colorArgb = 0xFFE5393B,
    this.opacity = 0.3,
    this.angle = -45,
  }) : imageBytes = null,
       imageScale = 1;

  const WatermarkSpec.image(
    Uint8List this.imageBytes, {
    this.imageScale = 0.5,
    this.opacity = 0.3,
    this.angle = 0,
  }) : text = null,
       fontSize = 0,
       colorArgb = 0;

  final String? text;
  final double fontSize;
  final int colorArgb;
  final Uint8List? imageBytes;

  /// Ảnh: tỉ lệ so với chiều rộng trang (0–1).
  final double imageScale;

  /// 0 (trong suốt) → 1 (đặc).
  final double opacity;

  /// Góc xoay độ, ngược chiều kim đồng hồ âm.
  final double angle;
}

/// Mẫu trang trắng.
enum BlankTemplate { blank, lined, grid }

/// Thông số tạo tài liệu trắng.
class BlankDocSpec {
  const BlankDocSpec({
    this.template = BlankTemplate.blank,
    this.title = '',
    this.pageSize = PageSizeOption.a4,
    this.landscape = false,
    this.backgroundArgb = 0xFFFFFFFF,
    this.category,
    this.pageCount = 1,
  }) : assert(pageCount >= 1 && pageCount <= 1000);

  final BlankTemplate template;

  /// Tiêu đề vẽ đầu trang 1 (rỗng = không vẽ) và đặt vào metadata.
  final String title;

  /// `fit` coi như A4.
  final PageSizeOption pageSize;
  final bool landscape;
  final int backgroundArgb;

  /// Danh mục (ghi vào metadata `subject`).
  final String? category;

  /// 1–1000.
  final int pageCount;
}

/// Gộp / tách / sắp xếp / watermark / tạo trắng. Mọi hàm **không ghi đè file gốc**, ghi an toàn
/// (`.tmp` rồi rename), kiểm [CancelToken] giữa các trang, báo [ProgressCallback] 0→1.
/// File vào có mật khẩu: truyền `password` (sai → `WrongPassword`, thiếu → `PasswordRequired`).
/// Chấp nhận mất annotation/form/link ở file kết quả.
abstract interface class PdfToolsEngine {
  /// Gộp [inputPaths] theo thứ tự → [outputPath]. [passwords] map path → mật khẩu.
  Future<String> merge(
    List<String> inputPaths,
    String outputPath, {
    Map<String, String> passwords = const {},
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  });

  /// Tách [inputPath] vào [outputDir], tên `<baseName> (1-3).pdf`… (không trùng).
  /// Trả về list path kết quả theo thứ tự.
  Future<List<String>> split(
    String inputPath,
    SplitMode mode,
    String outputDir,
    String baseName, {
    String? password,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  });

  /// Tạo file mới theo [pages] (sắp xếp / xoá / xoay / trích trang).
  Future<String> organize(
    String inputPath,
    List<PageOp> pages,
    String outputPath, {
    String? password,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  });

  /// Áp watermark lên mọi trang.
  Future<String> watermark(
    String inputPath,
    WatermarkSpec spec,
    String outputPath, {
    String? password,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  });

  /// Tạo tài liệu trắng.
  Future<String> createBlank(
    BlankDocSpec spec,
    String outputPath, {
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  });

  /// Số trang (để hiện chọn khoảng). Có mật khẩu → cần [password].
  Future<int> pageCount(String inputPath, {String? password});
}
