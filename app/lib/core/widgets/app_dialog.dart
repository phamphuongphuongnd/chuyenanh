import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Hộp thoại theo thiết kế: thẻ bo 26 giữa màn hình, tiêu đề đậm, 2 nút pill bằng nhau
/// (Huỷ viền + nút đỏ đặc). [onConfirm] null → nút xác nhận bị vô hiệu.
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
    const buttonSize = Size(64, 46);
    return AlertDialog(
      title: Text(title),
      content: content,
      titlePadding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      actions: [
        Row(
          children: [
            if (showCancel) ...[
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: buttonSize),
                  onPressed: onCancel ?? () => Navigator.of(context).pop(),
                  child: Text(cancelLabel ?? l.core_cancel),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: buttonSize),
                onPressed: onConfirm,
                child: Text(confirmLabel ?? l.core_ok),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
