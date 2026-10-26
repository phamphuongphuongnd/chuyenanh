import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'url_safety.dart';

/// Hàm mở liên kết bằng ứng dụng ngoài; test ghi đè bằng bản giả.
typedef LinkLauncher = Future<bool> Function(Uri uri);

Future<bool> _defaultLauncher(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

final linkLauncherProvider = Provider<LinkLauncher>((ref) => _defaultLauncher);

/// Lấy launcher từ ProviderScope gần nhất (nếu không có thì dùng mặc định).
LinkLauncher linkLauncherOf(BuildContext context) {
  try {
    return ProviderScope.containerOf(
      context,
      listen: false,
    ).read(linkLauncherProvider);
  } catch (_) {
    return _defaultLauncher;
  }
}

/// Kết quả mở: [uri] null nghĩa là bị chặn; [opened] false nghĩa là lỗi.
Future<({Uri? uri, bool opened})> openLink(
  LinkLauncher launcher,
  String url,
) async {
  final uri = safeLinkUri(url);
  if (uri == null) return (uri: null, opened: false);
  try {
    return (uri: uri, opened: await launcher(uri));
  } catch (_) {
    return (uri: uri, opened: false);
  }
}
