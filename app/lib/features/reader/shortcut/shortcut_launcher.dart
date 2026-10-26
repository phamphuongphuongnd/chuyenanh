import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/open_file_args.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/doc_type.dart';
import '../../../data/db/app_database.dart';
import 'shortcut_service.dart';

/// Mở trình đọc khi app được bật từ lối tắt màn hình chính (cả lúc khởi động lẫn
/// `onNewIntent` khi app đang chạy).
///
/// **Cần MÓNG nối vào app:** thêm một dòng `ref.watch(shortcutLaunchProvider);` vào
/// `PdfOfficeApp.build` (`lib/app.dart`) để provider này được tạo lúc khởi động.
final shortcutLaunchProvider = Provider<void>((ref) {
  final service = ref.watch(shortcutServiceProvider);
  var disposed = false;

  void open(String path) {
    if (disposed) return;
    openShortcutPath(ref, path);
  }

  service.setOpenPathHandler(open);
  ref.onDispose(() {
    disposed = true;
    service.setOpenPathHandler(null);
  });

  service.takeInitialPath().then((path) {
    if (path != null) open(path);
  });
});

/// Mở PDF [path] trong trình đọc. Bỏ qua nếu không phải PDF hoặc file không còn.
/// Trả về `true` nếu đã điều hướng.
bool openShortcutPath(Ref ref, String path) {
  if (docTypeFromPath(path) != DocType.pdf) return false;
  if (!File(path).existsSync()) return false;
  unawaited(
    ref
        .read(appDatabaseProvider)
        .recentsDao
        .touch(path)
        .catchError((Object _) {}),
  );
  ref.read(appRouterProvider).push(Routes.pdfReader, extra: OpenFileArgs(path));
  return true;
}
