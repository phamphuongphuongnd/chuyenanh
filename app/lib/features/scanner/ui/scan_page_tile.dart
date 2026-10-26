import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_ops/image_ops.dart' as ops;

import '../../../core/l10n/l10n.dart';
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

/// Hàng một trang trong danh sách: ảnh nhỏ, số trang, xoay / bộ lọc / chụp lại / xoá, tay kéo sắp xếp.
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            SizedBox(width: 72, height: 96, child: _Thumb(page: page)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.scan_pageNumber(index + 1),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (page.filter != ops.ImageFilter.original)
                    Text(
                      scanFilterLabel(context, page.filter),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  Wrap(
                    children: [
                      IconButton(
                        tooltip: l.scan_rotate,
                        icon: const Icon(Icons.rotate_right),
                        onPressed: onRotate,
                      ),
                      IconButton(
                        tooltip: l.scan_filter,
                        icon: const Icon(Icons.tune),
                        onPressed: onFilter,
                      ),
                      IconButton(
                        tooltip: l.scan_retake,
                        icon: const Icon(Icons.camera_alt_outlined),
                        onPressed: onRetake,
                      ),
                      IconButton(
                        tooltip: l.scan_deletePage,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.drag_handle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends ConsumerWidget {
  const _Thumb({required this.page});
  final ScanPage page;

  Widget _broken() => const Center(child: Icon(Icons.broken_image_outlined));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (page.isUnedited) {
      return Image.file(
        File(page.path),
        fit: BoxFit.contain,
        cacheWidth: 300,
        errorBuilder: (_, _, _) => _broken(),
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
      error: (_, _) => _broken(),
    );
  }
}
