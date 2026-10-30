// Provider của tính năng PowerPoint → PDF (test ghi đè bằng bản giả).
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/file_import.dart';
import 'ppt_to_pdf.dart';
import 'slide_rasterizer.dart';

final pptToPdfEngineProvider = Provider<PptToPdfEngine>(
  (ref) => const DefaultPptToPdfEngine(),
);

/// Tạo bộ chụp slide gắn với overlay gốc của [BuildContext] (màn đang mở).
final slideRasterizerFactoryProvider =
    Provider<SlideRasterizer Function(BuildContext context)>(
      (ref) =>
          (context) =>
              OverlaySlideRasterizer(Overlay.of(context, rootOverlay: true)),
    );

/// Chọn một file PowerPoint. Tách interface để test không cần hộp thoại hệ thống.
abstract interface class PptxFilePicker {
  /// Trả về đường dẫn, hoặc `null` nếu huỷ.
  Future<String?> pickPresentation();
}

/// Dùng `file_picker`. Cho chọn cả `.ppt` để báo rõ "không hỗ trợ" thay vì ẩn file.
class SystemPptxFilePicker implements PptxFilePicker {
  const SystemPptxFilePicker();

  @override
  Future<String?> pickPresentation() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pptx', 'ppt'],
    );
    final path = file?.path;
    return path == null ? null : importIntoAppDocuments(path);
  }
}

final pptxFilePickerProvider = Provider<PptxFilePicker>(
  (ref) => const SystemPptxFilePicker(),
);
