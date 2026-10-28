import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/file_import.dart';

/// Chọn file cho các công cụ PDF. Tách thành interface để test không cần hộp thoại hệ thống.
abstract interface class PdfFilePicker {
  /// Chọn một hoặc nhiều PDF. Huỷ → list rỗng.
  Future<List<String>> pickPdfs({bool multiple = false});

  /// Chọn một ảnh (PNG/JPG) làm watermark. Huỷ → `null`.
  Future<Uint8List?> pickImageBytes();
}

/// Dùng `file_picker`.
class SystemPdfFilePicker implements PdfFilePicker {
  const SystemPdfFilePicker();

  @override
  Future<List<String>> pickPdfs({bool multiple = false}) async {
    if (multiple) {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      return [
        for (final f in files)
          if (f.path != null) await importIntoAppDocuments(f.path!),
      ];
    }
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final path = file?.path;
    return path == null ? const [] : [await importIntoAppDocuments(path)];
  }

  @override
  Future<Uint8List?> pickImageBytes() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg'],
    );
    return file?.readAsBytes();
  }
}

final pdfFilePickerProvider = Provider<PdfFilePicker>(
  (ref) => const SystemPdfFilePicker(),
);
