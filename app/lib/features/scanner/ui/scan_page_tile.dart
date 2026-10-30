import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_ops/image_ops.dart' as ops;
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../model/scan_page.dart';

/// Khoá xem trước: đủ để biết khi nào phải render lại.
typedef PreviewKey = ({String path, int turns, ops.ImageFilter filter});

/// Ảnh xem trước (cạnh dài ≤ 400px) đã áp xoay + bộ lọc, chạy trong isolate.
final pagePreviewProvider = FutureProvider.autoDispose
    .family<Uint8List, PreviewKey>((ref, key) {
      return Isolate.run(
        () => ops.renderPreview(
          Uint8List.fromList(File(key.path).readAsBytesSync()),
          ops.ImageEdit(rotationQuarterTurns: key.turns, filter: key.filter),
          maxSide: 400,
        ),
      );
    });

String scanFilterLabel(BuildContext context, ops.ImageFilter f) {
  final l = context.l10n;
  return switch (f) {
    ops.ImageFilter.original => l.scan_filterOriginal,
    ops.ImageFilter.grayscale => l.scan_filterGrayscale,
    ops.ImageFilter.blackWhite => l.scan_filterBlackWhite,
    ops.ImageFilter.enhance => l.scan_filterEnhance,
    ops.ImageFilter.brighten => l.scan_filterBrighten,
    ops.ImageFilter.magicColor => l.scan_filterMagic,
  };
}

/// Thẻ một trang trong danh sách: ảnh nhỏ, số trang, xoay / bộ lọc / chụp lại / xoá, tay kéo sắp xếp.
/// Thẻ nền `surface` bo 20, không đổ bóng (thiết kế §1.5–1.6).
class ScanPageTile extends ConsumerWidget {
  const ScanPageTile({
    super.key,
    required this.page,
    required this.index,
    required this.onRotate,
    required this.onFilter,
    required this.onRetake,
    required this.onDelete,
  });

  final ScanPage page;
  final int index;
  final VoidCallback onRotate, onFilter, onRetake, onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = context.tokens;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 96,
            decoration: BoxDecoration(
              color: t.surface2,
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: _Thumb(page: page),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.scan_pageNumber(index + 1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: t.text,
                  ),
                ),
                if (page.filter != ops.ImageFilter.original) ...[
                  const SizedBox(height: 2),
                  Text(
                    scanFilterLabel(context, page.filter),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: t.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _RoundAction(
                      tooltip: l.scan_rotate,
                      icon: Symbols.rotate_right_rounded,
                      onPressed: onRotate,
                    ),
                    _RoundAction(
                      tooltip: l.scan_filter,
                      icon: Symbols.tune_rounded,
                      onPressed: onFilter,
                    ),
                    _RoundAction(
                      tooltip: l.scan_retake,
                      icon: Symbols.photo_camera_rounded,
                      onPressed: onRetake,
                    ),
                    _RoundAction(
                      tooltip: l.scan_deletePage,
                      icon: Symbols.delete_rounded,
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Icon(
                Symbols.drag_indicator_rounded,
                size: 24,
                color: t.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nút icon tròn 40 nền `surface2` trong hàng thao tác của thẻ trang.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: t.surface2,
        foregroundColor: t.text,
        fixedSize: const Size(40, 40),
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const CircleBorder(),
      ),
    );
  }
}

class _Thumb extends ConsumerWidget {
  const _Thumb({required this.page});
  final ScanPage page;

  Widget _broken(BuildContext context) => Center(
    child: Icon(
      Symbols.broken_image_rounded,
      color: context.tokens.textMuted,
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (page.isUnedited) {
      return Image.file(
        File(page.path),
        fit: BoxFit.contain,
        cacheWidth: 300,
        errorBuilder: (_, _, _) => _broken(context),
      );
    }
    final preview = ref.watch(
      pagePreviewProvider((
        path: page.path,
        turns: page.quarterTurns,
        filter: page.filter,
      )),
    );
    return preview.when(
      data: (bytes) => Image.memory(bytes, fit: BoxFit.contain),
      loading: () => const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) => _broken(context),
    );
  }
}
