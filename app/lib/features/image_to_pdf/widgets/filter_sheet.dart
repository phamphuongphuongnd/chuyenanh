import 'package:flutter/material.dart';
import 'package:image_ops/image_ops.dart' as ops;

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';

/// Tên hiển thị của bộ lọc theo ngôn ngữ hiện tại.
String filterLabel(BuildContext context, ops.ImageFilter filter) {
  final l = context.l10n;
  return switch (filter) {
    ops.ImageFilter.original => l.img2pdf_filterOriginal,
    ops.ImageFilter.grayscale => l.img2pdf_filterGrayscale,
    ops.ImageFilter.blackWhite => l.img2pdf_filterBlackWhite,
    ops.ImageFilter.enhance => l.img2pdf_filterEnhance,
    ops.ImageFilter.brighten => l.img2pdf_filterBrighten,
    ops.ImageFilter.magicColor => l.img2pdf_filterMagic,
  };
}

/// Chip lựa chọn dạng viên theo thiết kế: bo 18, cao ~36; chọn = nền đỏ chữ trắng,
/// chưa chọn = nền `surface2` chữ `text`. [onSelected] = null thì chip bị khoá (mờ đi).
/// Vẫn là [ChoiceChip] để giữ ngữ nghĩa trợ năng và test dò `selected` / `onSelected`.
Widget pillChoiceChip(
  BuildContext context, {
  required String label,
  required bool selected,
  required ValueChanged<bool>? onSelected,
}) {
  final t = context.tokens;
  final enabled = onSelected != null;
  final Color bg = selected ? AppColors.primary : t.surface2;
  final Color fg = selected ? Colors.white : (enabled ? t.text : t.textMuted);
  return Opacity(
    opacity: enabled ? 1 : 0.5,
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      elevation: 0,
      pressElevation: 0,
      color: WidgetStatePropertyAll(bg),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      labelPadding: EdgeInsets.zero,
      labelStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: fg,
      ),
    ),
  );
}

/// Bảng chọn bộ lọc (chọn chip là đóng ngay). Trả về bộ lọc được chọn, `null` nếu đóng.
Future<ops.ImageFilter?> showFilterSheet(
  BuildContext context, {
  required ops.ImageFilter current,
}) {
  return showModalBottomSheet<ops.ImageFilter>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ctx.l10n.img2pdf_filter,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ctx.tokens.text,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in ops.ImageFilter.values)
                  pillChoiceChip(
                    ctx,
                    label: filterLabel(ctx, f),
                    selected: f == current,
                    onSelected: (_) => Navigator.of(ctx).pop(f),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
