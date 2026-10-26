import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/doc_type.dart';
import '../../../core/widgets/widgets.dart';
import '../document_actions.dart';
import '../documents_providers.dart';
import 'document_tile.dart';
import 'permission_views.dart';

/// Danh sách tài liệu của một tab trang chủ ([category] null = All).
///
/// Xử lý đủ trạng thái: đang quét (skeleton + "đã tìm N file"), thiếu quyền (màn xin quyền /
/// băng nhắc), trống, lỗi; kéo xuống để quét lại. Tab All có thêm lưới loại file ở đầu.
class DocumentList extends ConsumerWidget {
  const DocumentList({super.key, required this.category, this.onPickCategory});

  final DocCategory? category;

  /// Bấm một ô trong lưới loại file → chuyển sang tab tương ứng. `null` = không hiện lưới.
  final ValueChanged<DocCategory>? onPickCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final scan = ref.watch(scanControllerProvider);
    final docs = ref.watch(categoryDocumentsProvider(category));

    return docs.when(
      loading: () => const DocumentListSkeleton(),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: appErrorMessage(context, AppError.from(e)),
        actionLabel: l.core_retry,
        onAction: () => ref.invalidate(documentsProvider),
      ),
      data: (items) {
        if (items.isEmpty && scan.isScanning) {
          return Column(
            children: [
              ScanProgressBar(found: scan.found),
              const Expanded(child: DocumentListSkeleton()),
            ],
          );
        }
        final showGrid = onPickCategory != null;
        return Column(
          children: [
            if (scan.needsPermission && items.isNotEmpty)
              const PermissionBanner(),
            if (scan.isScanning) ScanProgressBar(found: scan.found),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.read(scanControllerProvider.notifier).refresh(),
                child: items.isEmpty
                    ? _EmptyScrollable(
                        child: scan.needsPermission
                            ? const _NoPermissionView()
                            : EmptyState(
                                illustration: category == null
                                    ? null
                                    : FileTypeIcon(
                                        _typeOfCategory(category!),
                                        size: 72,
                                      ),
                                title: l.docs_emptyAll,
                              ),
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: items.length + (showGrid ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (showGrid && i == 0) {
                            return CategoryGrid(onPick: onPickCategory!);
                          }
                          return DocumentTile(items[i - (showGrid ? 1 : 0)]);
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  static DocType _typeOfCategory(DocCategory c) => switch (c) {
    DocCategory.pdf => DocType.pdf,
    DocCategory.doc => DocType.docx,
    DocCategory.xls => DocType.xlsx,
    DocCategory.ppt => DocType.pptx,
    DocCategory.txt => DocType.txt,
  };
}

class _EmptyScrollable extends StatelessWidget {
  const _EmptyScrollable({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [SizedBox(height: constraints.maxHeight, child: child)],
    ),
  );
}

class _NoPermissionView extends StatelessWidget {
  const _NoPermissionView();

  @override
  Widget build(BuildContext context) => const Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [PermissionGate(), PickFileButton(), SizedBox(height: 32)],
  );
}

/// Thanh tiến độ quét + "Đang quét… đã tìm N file".
class ScanProgressBar extends StatelessWidget {
  const ScanProgressBar({super.key, required this.found});

  final int found;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const LinearProgressIndicator(minHeight: 3),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(
          context.l10n.docs_scanning(found),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ],
  );
}

/// Khung xương hiện lúc chưa có dữ liệu.
class DocumentListSkeleton extends StatelessWidget {
  const DocumentListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.outlineVariant;
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
    );
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      itemBuilder: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            bar(32, 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(180, 14),
                  const SizedBox(height: 8),
                  bar(120, 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lưới loại file ở đầu tab All: PDF · DOC · XLS · PPT · Text · More.
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({super.key, required this.onPick});

  final ValueChanged<DocCategory> onPick;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget cell(Widget icon, String label, VoidCallback onTap, Key key) =>
        Expanded(
          child: InkWell(
            key: key,
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 40, child: icon),
                  const SizedBox(height: 6),
                  Text(label, style: Theme.of(context).textTheme.labelMedium),
                ],
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          cell(
            const FileTypeIcon(DocType.pdf),
            'PDF',
            () => onPick(DocCategory.pdf),
            const ValueKey('grid-pdf'),
          ),
          cell(
            const FileTypeIcon(DocType.docx),
            'DOC',
            () => onPick(DocCategory.doc),
            const ValueKey('grid-doc'),
          ),
          cell(
            const FileTypeIcon(DocType.xlsx),
            'XLS',
            () => onPick(DocCategory.xls),
            const ValueKey('grid-xls'),
          ),
          cell(
            const FileTypeIcon(DocType.pptx),
            'PPT',
            () => onPick(DocCategory.ppt),
            const ValueKey('grid-ppt'),
          ),
          cell(
            const FileTypeIcon(DocType.txt),
            'TXT',
            () => onPick(DocCategory.txt),
            const ValueKey('grid-txt'),
          ),
          cell(
            const Icon(Icons.more_horiz, color: AppColors.other, size: 32),
            l.docs_categoryMore,
            () => pickAndOpenDocument(context),
            const ValueKey('grid-more'),
          ),
        ],
      ),
    );
  }
}
