import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/utils/file_paths.dart';
import '../../../engines/pdf/pdf_render_engine.dart';
import '../../../engines/pdf/pdfx_render_engine.dart'
    show RenderSize, computeRenderSize;

/// Các mức DPI cho chọn nhanh (72 = kích thước gốc, 150 = đủ nét cho màn hình, 300 = in).
const List<int> kDpiPresets = [72, 100, 150, 200, 300];
const int kDefaultDpi = 150;

String imageExtension(RenderFormat format) =>
    format == RenderFormat.png ? 'png' : 'jpg';

/// Tên ảnh của một trang: `<base>_001.jpg` (số trang bắt đầu từ 1, đệm 0 theo tổng số trang, tối thiểu 3 chữ số).
String exportImageName(
  String baseName,
  int pageIndex,
  int pageCount,
  RenderFormat format,
) {
  final width = pageCount.toString().length < 3
      ? 3
      : pageCount.toString().length;
  final number = (pageIndex + 1).toString().padLeft(width, '0');
  return '${sanitizeFileName(baseName)}_$number.${imageExtension(format)}';
}

/// Kích thước ảnh sẽ được tạo cho một trang ở [dpi] (đã giới hạn số điểm ảnh tối đa).
RenderSize estimateImageSize(PdfPageSize page, double dpi) =>
    computeRenderSize(page, dpi);

class PdfExportResult {
  const PdfExportResult({required this.directory, required this.files});

  /// Thư mục con chứa ảnh (theo tên file PDF).
  final String directory;

  /// Đường dẫn từng ảnh, theo thứ tự trang.
  final List<String> files;
}

/// Render các trang [pages] (0-based) của [document] thành ảnh, lưu vào thư mục con
/// `<parentDir>/<baseName>` (đặt tên không trùng). Huỷ hoặc lỗi giữa chừng → xoá thư
/// mục đã tạo rồi ném lại lỗi (không để file dở).
Future<PdfExportResult> exportPdfToImages({
  required PdfRenderDocument document,
  required List<int> pages,
  required double dpi,
  required RenderFormat format,
  required String parentDir,
  required String baseName,
  int jpgQuality = 90,
  ProgressCallback? onProgress,
  CancelToken? cancelToken,
}) async {
  if (pages.isEmpty) throw ArgumentError.value(pages, 'pages', 'rong');
  cancelToken?.throwIfCancelled();

  final dirPath = await uniqueOutputPath(parentDir, baseName, '');
  final dir = Directory(dirPath);
  await dir.create(recursive: true);
  final files = <String>[];
  try {
    for (var i = 0; i < pages.length; i++) {
      cancelToken?.throwIfCancelled();
      final page = pages[i];
      final bytes = await document.renderPage(
        page,
        dpi: dpi,
        format: format,
        jpgQuality: jpgQuality,
        cancelToken: cancelToken,
      );
      final name = exportImageName(baseName, page, document.pageCount, format);
      final file = await writeAtomically(p.join(dirPath, name), bytes);
      files.add(file.path);
      onProgress?.call((i + 1) / pages.length);
    }
    return PdfExportResult(directory: dirPath, files: files);
  } catch (_) {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
    rethrow;
  }
}
