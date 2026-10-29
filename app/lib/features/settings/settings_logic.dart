import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/utils/output_directory.dart';
import '../../data/settings/settings_providers.dart';
import 'settings_providers.dart';

/// Phiên bản hiển thị ở màn Giới thiệu. Giữ khớp `version:` trong `pubspec.yaml`
/// (chưa có gói đọc phiên bản app — xem "Cần MÓNG bổ sung").
const String kAppVersion = '1.0.0';

/// Link tải APK mới nhất: file đính kèm của GitHub Release gắn tag `android-latest`
/// (Release cho file tới 2GB, còn file trong repo bị chặn trên 100MB).
const String kAppDownloadUrl =
    'https://github.com/phamphuongphuongnd/chuyenanh/releases/download/android-latest/PDFOffice.apk';

/// Địa chỉ nhận phản hồi (người gửi là tài khoản mail đang dùng trên máy bấm nút).
const String kFeedbackEmail = 'phamphuongphuongnd@gmail.com';

/// Link cài cho iPhone: trang GitHub Release gắn tag `ios-latest` (có ghi chú cách cài bằng Sideloadly).
/// Không trỏ thẳng file .ipa vì IPA không ký không mở được bằng cách bấm tải.
const String kIosDownloadUrl =
    'https://github.com/phamphuongphuongnd/chuyenanh/releases/tag/ios-latest';

/// Nội dung gửi đi khi chia sẻ ứng dụng: lời giới thiệu + link tải cho CẢ hai hệ điều hành, trên mọi nền tảng
/// (người nhận dùng máy nào thì bấm link của máy đó).
///
///     <lời giới thiệu>
///
///     Android: <link APK>
///     iPhone: <link trang cài iOS>
String appShareMessage(String intro) =>
    '$intro\n\nAndroid: $kAppDownloadUrl\niPhone: $kIosDownloadUrl';

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

/// Thư mục lưu đang có hiệu lực: cấu hình của người dùng, hoặc mặc định khi chưa đặt.
String effectiveOutputDir(String? configured) =>
    configured == null || configured.isEmpty
    ? defaultAndroidOutputDir
    : configured;

/// Kết quả của một lần chọn thư mục lưu.
enum OutputDirResult { cancelled, applied, notWritable }

/// Mở bộ chọn thư mục ([pick]) rồi áp dụng. Huỷ → [OutputDirResult.cancelled]; thư mục
/// không ghi được → [OutputDirResult.notWritable] (giữ cài đặt cũ).
Future<OutputDirResult> chooseOutputDirectory(
  SettingsNotifier settings,
  DirectoryPicker pick,
  String dialogTitle,
) async {
  final dir = await pick(dialogTitle);
  if (dir == null || dir.isEmpty) return OutputDirResult.cancelled;
  return await applyOutputDirectory(settings, dir)
      ? OutputDirResult.applied
      : OutputDirResult.notWritable;
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
