import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/db/app_database.dart';
import '../logic/bookmark_logic.dart';
import '../reader_viewer.dart';

/// Bảng danh sách bookmark của một file. Chạm một trang → [onOpenPage] (0-based).
Future<void> showBookmarksSheet(
  BuildContext context, {
  required String path,
  required ValueChanged<int> onOpenPage,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (ctx, scroll) => BookmarksList(
        path: path,
        scrollController: scroll,
        onOpenPage: (page) {
          Navigator.of(ctx).pop();
          onOpenPage(page);
        },
      ),
    ),
  );
}

class BookmarksList extends ConsumerWidget {
  const BookmarksList({
    super.key,
    required this.path,
    required this.onOpenPage,
    this.scrollController,
  });

  final String path;
  final ValueChanged<int> onOpenPage;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final bookmarks =
        ref.watch(bookmarksForPathProvider(path)).value ?? const <Bookmark>[];
    final whole = bookmarks.where((b) => b.page == wholeDocumentPage);
    final pages = pageBookmarks(bookmarks);
    final dao = ref.read(appDatabaseProvider).bookmarksDao;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SheetTitle(l.reader_bookmarks),
        ),
        Expanded(
          child: bookmarks.isEmpty
              // Trống: vẫn cuộn theo sheet để kéo nhỏ không bị tràn.
              ? ListView(
                  controller: scrollController,
                  children: [
                    EmptyState(
                      icon: Symbols.bookmark_rounded,
                      title: l.reader_noBookmarks,
                      message: l.reader_noBookmarksHint,
                    ),
                  ],
                )
              : ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  children: [
                    for (final b in whole)
                      _BookmarkRow(
                        key: Key('bookmark_whole_${b.id}'),
                        icon: Symbols.collections_bookmark_rounded,
                        label: l.reader_wholeDocument,
                        deleteTooltip: l.core_delete,
                        onDelete: () => dao.removeById(b.id),
                      ),
                    for (final b in pages)
                      _BookmarkRow(
                        key: Key('bookmark_page_${b.page}'),
                        icon: Symbols.bookmark_rounded,
                        label: l.reader_pageLabel(b.page + 1),
                        deleteTooltip: l.core_delete,
                        onTap: () => onOpenPage(b.page),
                        onDelete: () => dao.removeById(b.id),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Một dòng kiểu bảng chọn (bo 16, cao 52): icon đánh dấu đặc · nhãn · nút xoá.
class _BookmarkRow extends StatelessWidget {
  const _BookmarkRow({
    super.key,
    required this.icon,
    required this.label,
    required this.deleteTooltip,
    required this.onDelete,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String deleteTooltip;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(icon, size: 22, fill: 1, color: t.primaryText),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                    color: t.text,
                  ),
                ),
              ),
              IconButton(
                tooltip: deleteTooltip,
                icon: const Icon(Symbols.delete_rounded, size: 22),
                color: t.textMuted,
                onPressed: onDelete,
              ),
              const SizedBox(width: 2),
            ],
          ),
        ),
      ),
    );
  }
}
