import 'package:flutter/material.dart';
import 'package:image_ops/image_ops.dart' as ops;

import '../../../core/l10n/l10n.dart';

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

/// Bảng chọn bộ lọc. Trả về bộ lọc được chọn, `null` nếu đóng.
Future<ops.ImageFilter?> showFilterSheet(
  BuildContext context, {
  required ops.ImageFilter current,
}) {
  return showModalBottomSheet<ops.ImageFilter>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ctx.l10n.img2pdf_filter,
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in ops.ImageFilter.values)
                  ChoiceChip(
                    label: Text(filterLabel(ctx, f)),
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
