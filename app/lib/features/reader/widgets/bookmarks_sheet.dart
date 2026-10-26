import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
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
    final theme = Theme.of(context);
    final bookmarks =
        ref.watch(bookmarksForPathProvider(path)).value ?? const <Bookmark>[];
    final whole = bookmarks.where((b) => b.page == wholeDocumentPage);
    final pages = pageBookmarks(bookmarks);
    final dao = ref.read(appDatabaseProvider).bookmarksDao;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(l.reader_bookmarks, style: theme.textTheme.titleLarge),
        ),
        Expanded(
          child: bookmarks.isEmpty
              ? EmptyState(
                  icon: Icons.bookmark_border,
                  title: l.reader_noBookmarks,
                  message: l.reader_noBookmarksHint,
                )
              : ListView(
                  controller: scrollController,
                  children: [
                    for (final b in whole)
                      ListTile(
                        key: Key('bookmark_whole_${b.id}'),
                        leading: const Icon(Icons.collections_bookmark),
                        title: Text(l.reader_wholeDocument),
                        trailing: IconButton(
                          tooltip: l.core_delete,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => dao.removeById(b.id),
                        ),
                      ),
                    for (final b in pages)
                      ListTile(
                        key: Key('bookmark_page_${b.page}'),
                        leading: const Icon(Icons.bookmark),
                        title: Text(l.reader_pageLabel(b.page + 1)),
                        onTap: () => onOpenPage(b.page),
                        trailing: IconButton(
                          tooltip: l.core_delete,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => dao.removeById(b.id),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
