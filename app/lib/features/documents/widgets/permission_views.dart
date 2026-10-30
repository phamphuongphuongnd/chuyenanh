import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../document_actions.dart';
import '../documents_providers.dart';

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
      onAction: () =>
          ref.read(scanControllerProvider.notifier).requestPermissionAndScan(),
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
    void grant() =>
        ref.read(scanControllerProvider.notifier).requestPermissionAndScan();
    return Material(
      color: t.primarySoft,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: grant,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
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
