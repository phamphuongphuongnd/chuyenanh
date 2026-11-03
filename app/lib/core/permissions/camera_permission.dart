import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:permission_handler/permission_handler.dart';

import '../errors/app_error.dart';
import '../l10n/l10n.dart';

/// Quyền camera lúc chạy. Tách interface để test thay bằng bản giả (plugin chỉ chạy trên máy thật).
abstract interface class CameraPermissionApi {
  /// Trạng thái hiện tại — không hiện hộp thoại hệ thống.
  Future<PermissionStatus> status();

  /// Hiện hộp xin quyền của hệ thống (nếu hệ thống còn cho hỏi).
  Future<PermissionStatus> request();
}

class PermissionHandlerCameraPermission implements CameraPermissionApi {
  const PermissionHandlerCameraPermission();

  @override
  Future<PermissionStatus> status() => Permission.camera.status;

  @override
  Future<PermissionStatus> request() => Permission.camera.request();
}

final cameraPermissionProvider = Provider<CameraPermissionApi>(
  (ref) => const PermissionHandlerCameraPermission(),
);

/// Hộp thoại giải thích trước khi xin quyền camera (chính sách Google Play).
/// `true` = "Tiếp tục"; "Để sau" / bấm ra ngoài = `false`.
Future<bool> showCameraPermissionDialog(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final l = ctx.l10n;
      final body = Theme.of(ctx).textTheme.bodyMedium;
      Widget line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 20)),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: body)),
          ],
        ),
      );
      return AlertDialog(
        key: const ValueKey('camera_permission_dialog'),
        title: Semantics(
          header: true,
          child: Text(l.core_cameraPermissionTitle),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              line(Symbols.photo_camera_rounded, l.core_cameraPermissionWhy),
              line(Symbols.lock_rounded, l.core_cameraPermissionLocal),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('camera_permission_later'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.core_cameraPermissionLater),
          ),
          FilledButton(
            key: const ValueKey('camera_permission_continue'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            autofocus: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.core_cameraPermissionContinue),
          ),
        ],
      );
    },
  );
  return ok ?? false;
}

/// Gọi ngay trước khi mở camera (UI gọi, service/plugin chụp sau đó):
/// - đã có quyền → `true`, không hỏi gì;
/// - bị chặn vĩnh viễn / hạn chế (hệ thống không hỏi nữa) → ném [PermissionDenied] như trước;
/// - chưa có → hộp giải thích: "Để sau" → `false` (bên gọi dừng lặng lẽ, không báo lỗi);
///   "Tiếp tục" → hộp xin quyền hệ thống: cho → `true`, từ chối → ném [PermissionDenied].
Future<bool> ensureCameraPermission(BuildContext context, WidgetRef ref) async {
  final api = ref.read(cameraPermissionProvider);
  final current = await api.status();
  if (current.isGranted || current.isLimited) return true;
  if (current.isPermanentlyDenied || current.isRestricted) {
    throw const PermissionDenied();
  }
  if (!context.mounted || !await showCameraPermissionDialog(context)) {
    return false;
  }
  final result = await api.request();
  if (result.isGranted || result.isLimited) return true;
  throw const PermissionDenied();
}
