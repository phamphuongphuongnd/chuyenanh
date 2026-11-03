import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/settings/settings_providers.dart';
import '../../settings/privacy_screen.dart';
import '../document_actions.dart';
import '../documents_providers.dart';

/// Sau khi người dùng tắt biểu ngữ, chỉ nhắc lại sau khoảng này.
const Duration storageBannerSnooze = Duration(days: 14);

/// Biểu ngữ còn đang bị tắt ([dismissedAt] chưa quá [storageBannerSnooze] tính tới [now])?
bool isStorageBannerSnoozed(DateTime? dismissedAt, DateTime now) =>
    dismissedAt != null && now.difference(dismissedAt) < storageBannerSnooze;

/// Hộp thoại giải thích trước khi mở trang Cài đặt xin "Truy cập tất cả file".
/// `true` = "Tiếp tục"; "Để sau" / bấm ra ngoài = `false`.
Future<bool> showStoragePermissionDialog(BuildContext context) async {
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
        key: const ValueKey('storage_permission_dialog'),
        title: Semantics(
          header: true,
          child: Text(l.docs_permissionDialogTitle),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              line(Symbols.search_rounded, l.docs_permissionDialogWhy),
              line(Symbols.lock_rounded, l.docs_permissionDialogLocal),
              line(Symbols.folder_open_rounded, l.docs_permissionDialogDecline),
              TextButton(
                key: const ValueKey('storage_permission_privacy'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  alignment: Alignment.centerLeft,
                ),
                onPressed: () => Navigator.of(ctx).push(
                  MaterialPageRoute<void>(builder: (_) => const PrivacyScreen()),
                ),
                child: Text(l.docs_permissionPrivacyLink),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('storage_permission_later'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.docs_permissionLater),
          ),
          FilledButton(
            key: const ValueKey('storage_permission_continue'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            autofocus: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.docs_permissionContinue),
          ),
        ],
      );
    },
  );
  return ok ?? false;
}

/// Bấm "Cấp quyền": giải thích trước, chỉ khi người dùng "Tiếp tục" mới xin quyền (mở Cài đặt).
Future<void> _explainThenRequest(BuildContext context, WidgetRef ref) async {
  if (!await showStoragePermissionDialog(context)) return;
  await ref.read(scanControllerProvider.notifier).requestPermissionAndScan();
}

/// Màn xin quyền (chưa có quyền và chưa có tài liệu nào để hiện).
class PermissionGate extends ConsumerWidget {
  const PermissionGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return EmptyState(
      icon: Symbols.folder_off_rounded,
      title: l.docs_permissionTitle,
      message: l.docs_permissionMessage,
      actionLabel: l.docs_grantPermission,
      onAction: () => _explainThenRequest(context, ref),
    );
  }
}

/// Băng nhắc cấp quyền (đã có tài liệu cũ trong DB nhưng quyền đang thiếu):
/// khối bo 16 nền đỏ nhạt · ổ khoá đặc · lời nhắc · nút "Cấp quyền" đỏ.
class PermissionBanner extends ConsumerWidget {
  const PermissionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = context.tokens;
    void grant() => _explainThenRequest(context, ref);
    return Material(
      color: t.primarySoft,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: grant,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
          child: Row(
            children: [
              Icon(
                Symbols.lock_rounded,
                fill: 1,
                size: 20,
                color: t.primaryText,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l.docs_permissionBanner,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: t.text,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontFamily: kUiFontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: grant,
                child: Text(l.docs_grantPermission),
              ),
              IconButton(
                key: const ValueKey('permission_banner_dismiss'),
                tooltip: l.docs_permissionDismiss,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Symbols.close_rounded, size: 20),
                onPressed: () => ref
                    .read(settingsProvider.notifier)
                    .setStorageBannerDismissedAt(DateTime.now()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nút viền "chọn file thủ công" cho chế độ không có quyền (cao 50, rộng tối đa 280).
class PickFileButton extends StatelessWidget {
  const PickFileButton({super.key});

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 280),
    child: OutlinedButton(
      // Cùng cỡ tối thiểu với nút "Cấp quyền" của EmptyState để hai nút thẳng hàng.
      style: OutlinedButton.styleFrom(minimumSize: const Size(200, 50)),
      onPressed: () => pickAndOpenDocument(context),
      child: Text(context.l10n.docs_pickFileInstead),
    ),
  );
}
