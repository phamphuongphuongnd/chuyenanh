import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
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
      icon: Icons.folder_off_outlined,
      title: l.docs_permissionTitle,
      message: l.docs_permissionMessage,
      actionLabel: l.docs_grantPermission,
      onAction: () =>
          ref.read(scanControllerProvider.notifier).requestPermissionAndScan(),
    );
  }
}

/// Băng nhắc cấp quyền (đã có tài liệu cũ trong DB nhưng quyền đang thiếu).
class PermissionBanner extends ConsumerWidget {
  const PermissionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.lock_outline),
        title: Text(l.docs_permissionBanner),
        trailing: TextButton(
          onPressed: () => ref
              .read(scanControllerProvider.notifier)
              .requestPermissionAndScan(),
          child: Text(l.docs_grantPermission),
        ),
        onTap: () => ref
            .read(scanControllerProvider.notifier)
            .requestPermissionAndScan(),
      ),
    );
  }
}

/// Nút "chọn file thủ công" cho chế độ không có quyền.
class PickFileButton extends StatelessWidget {
  const PickFileButton({super.key});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: const Icon(Icons.folder_open),
    label: Text(context.l10n.docs_pickFileInstead),
    onPressed: () => pickAndOpenDocument(context),
  );
}
