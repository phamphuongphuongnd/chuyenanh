import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/platform/app_platform.dart';
import '../../core/utils/output_directory.dart';
import '../../data/settings/settings_providers.dart';
import 'settings_providers.dart';

/// Phiên bản hiển thị ở màn Giới thiệu. Giữ khớp `version:` trong `pubspec.yaml`
/// (chưa có gói đọc phiên bản app — xem "Cần MÓNG bổ sung").
const String kAppVersion = '1.0.0';

/// Địa chỉ nhận phản hồi (người gửi là tài khoản mail đang dùng trên máy bấm nút).
const String kFeedbackEmail = 'phamphuongphuongnd@gmail.com';

/// Trang ứng dụng trên Google Play (gói `com.phiotron.phiotronpdf`).
const String kPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.phiotron.phiotronpdf';

/// Trang ứng dụng trên App Store. Rỗng tới khi App Store Connect cấp id
/// (dạng `https://apps.apple.com/app/id<số>`); rỗng thì lời chia sẻ trên iOS không kèm link.
const String kAppStoreUrl = '';

/// Chính sách bảo mật công khai (GitHub Pages, nguồn ở `public-site/privacy.md`).
/// Phải khớp với nội dung trong app và hành vi thật của app.
const String kPrivacyPolicyUrl =
    'https://phamphuongphuongnd.github.io/phiotron-pdf/privacy';

/// Trang hỗ trợ công khai (nguồn ở `public-site/index.md`).
const String kSupportUrl = 'https://phamphuongphuongnd.github.io/phiotron-pdf/';

/// Nội dung gửi đi khi chia sẻ ứng dụng: lời giới thiệu + link cửa hàng của đúng nền tảng.
/// - Android: kèm link Google Play.
/// - iOS: chỉ kèm link App Store khi đã có [kAppStoreUrl]; không bao giờ nhắc Android / Google Play
///   (App Store 2.3.10 cấm nhắc nền tảng khác).
/// - Khác: chỉ lời giới thiệu.
///
/// [appStoreUrl] chỉ để test ghi đè.
String appShareMessage(
  String intro,
  AppPlatform platform, {
  String appStoreUrl = kAppStoreUrl,
}) => switch (platform) {
  AppPlatform.android => '$intro\n\n$kPlayStoreUrl',
  AppPlatform.ios when appStoreUrl.isNotEmpty => '$intro\n\n$appStoreUrl',
  _ => intro,
};

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
