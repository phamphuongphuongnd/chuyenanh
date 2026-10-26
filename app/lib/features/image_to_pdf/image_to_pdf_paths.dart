import '../../core/router/routes.dart';

/// Màn thêm ảnh từ màn sửa: `context.push<List<String>>(img2pdfAddPath)` trả về đường dẫn ảnh đã chọn.
const String img2pdfAddPath = '${Routes.imageToPdf}/add';

/// Màn sửa: `extra: List<String>` (đường dẫn ảnh theo thứ tự).
const String img2pdfEditPath = '${Routes.imageToPdf}/edit';

/// Màn kết quả: `extra: ExportOutcome`.
const String img2pdfResultPath = '${Routes.imageToPdf}/result';
