import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hàm chọn thư mục (trả đường dẫn hoặc `null` nếu huỷ). Tách thành provider để test
/// thay bằng bản giả — không mở hộp thoại hệ thống.
typedef DirectoryPicker = Future<String?> Function(String dialogTitle);

final directoryPickerProvider = Provider<DirectoryPicker>(
  (ref) =>
      (title) => FilePicker.getDirectoryPath(dialogTitle: title),
);
