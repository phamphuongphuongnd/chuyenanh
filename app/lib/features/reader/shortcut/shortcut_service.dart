import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tên kênh — khớp `ShortcutChannel.CHANNEL` (Kotlin).
const String kShortcutChannelName = 'com.phuong.pdfoffice/shortcut';

/// Lối tắt màn hình chính (Android 8.0+). Trên nền tảng không có phần native
/// (iOS, test) mọi hàm trả về `false` / `null`, không ném lỗi.
class ShortcutService {
  ShortcutService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(kShortcutChannelName);

  final MethodChannel _channel;

  /// Launcher có cho ghim lối tắt không (ẩn tính năng nếu `false`, vd. Android 7).
  Future<bool> isSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Yêu cầu ghim lối tắt tới [path]; người dùng xác nhận trên launcher.
  /// `true` = yêu cầu đã được gửi (chưa chắc người dùng đồng ý).
  Future<bool> requestPinShortcut({
    required String path,
    required String label,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('requestPinShortcut', {
            'path': path,
            'label': label,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Đường dẫn file của intent đã mở app (null nếu mở bình thường). Chỉ trả một lần.
  Future<String?> takeInitialPath() async {
    try {
      return await _channel.invokeMethod<String>('takeInitialPath');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Native gọi khi app đang chạy và nhận intent lối tắt mới (`onNewIntent`).
  void setOpenPathHandler(void Function(String path)? handler) {
    if (handler == null) {
      _channel.setMethodCallHandler(null);
      return;
    }
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openPath') {
        final path = call.arguments;
        if (path is String && path.isNotEmpty) handler(path);
      }
      return null;
    });
  }
}

final shortcutServiceProvider = Provider<ShortcutService>(
  (ref) => ShortcutService(),
);

/// Ẩn nút "Thêm vào màn hình chính" nếu `false`.
final shortcutSupportedProvider = FutureProvider<bool>(
  (ref) => ref.watch(shortcutServiceProvider).isSupported(),
);
