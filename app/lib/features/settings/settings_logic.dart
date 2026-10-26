import 'dart:io';

import 'package:path/path.dart' as p;

import '../../data/settings/settings_providers.dart';

/// Phiên bản hiển thị ở màn Giới thiệu. Giữ khớp `version:` trong `pubspec.yaml`
/// (chưa có gói đọc phiên bản app — xem "Cần MÓNG bổ sung").
const String kAppVersion = '1.0.0';

/// `true` nếu ghi được file vào [path] (thư mục phải tồn tại). Thử bằng cách tạo rồi xoá
/// một file tạm — không để lại dấu vết.
Future<bool> isDirectoryWritable(String path) async {
  if (path.isEmpty) return false;
  try {
    final dir = Directory(path);
    if (!await dir.exists()) return false;
    final probe = File(
      p.join(
        path,
        '.pdfoffice_write_test_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    await probe.writeAsString('ok', flush: true);
    await probe.delete();
    return true;
  } on FileSystemException {
    return false;
  }
}

/// Đặt thư mục lưu. [dir] null = về mặc định. Thư mục không ghi được → trả `false`,
/// giữ nguyên cài đặt cũ.
Future<bool> applyOutputDirectory(
  SettingsNotifier settings,
  String? dir,
) async {
  if (dir != null && !await isDirectoryWritable(dir)) return false;
  await settings.setOutputDir(dir);
  return true;
}
