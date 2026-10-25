import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Hộp thoại kiểu app gốc: thẻ bo góc giữa màn hình, tiêu đề đậm, nút CANCEL viền +
/// nút đỏ đặc. [onConfirm] null → nút xác nhận bị vô hiệu.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmLabel,
    this.cancelLabel,
    this.onConfirm,
    this.onCancel,
    this.showCancel = true,
    this.destructive = false,
  });

  final String title;
  final Widget content;

  /// Mặc định `core_ok`.
  final String? confirmLabel;

  /// Mặc định `core_cancel`.
  final String? cancelLabel;
  final VoidCallback? onConfirm;

  /// Mặc định `Navigator.pop(context)` (trả về null).
  final VoidCallback? onCancel;
  final bool showCancel;

  /// Giữ cho tương lai (nút xoá) — hiện cùng màu đỏ chủ đạo.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(title),
      content: content,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            if (showCancel) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel ?? () => Navigator.of(context).pop(),
                  child: Text((cancelLabel ?? l.core_cancel).toUpperCase()),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: FilledButton(
                onPressed: onConfirm,
                child: Text((confirmLabel ?? l.core_ok).toUpperCase()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
