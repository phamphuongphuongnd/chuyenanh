import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/widgets.dart';
import '../logic/outline.dart';

/// Bảng mục lục (outline) PDF. Chạm một mục → [onSelect].
Future<void> showOutlineSheet(
  BuildContext context, {
  required List<OutlineEntry> entries,
  required ValueChanged<OutlineEntry> onSelect,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => OutlineList(
        entries: entries,
        scrollController: scroll,
        onSelect: (e) {
          Navigator.of(ctx).pop();
          onSelect(e);
        },
      ),
    ),
  );
}

class OutlineList extends StatelessWidget {
  const OutlineList({
    super.key,
    required this.entries,
    required this.onSelect,
    this.scrollController,
  });

  final List<OutlineEntry> entries;
  final ValueChanged<OutlineEntry> onSelect;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(l.reader_outline, style: theme.textTheme.titleLarge),
        ),
        Expanded(
          child: entries.isEmpty
              ? EmptyState(
                  icon: Icons.format_list_bulleted,
                  title: l.reader_noOutline,
                )
              : ListView.builder(
                  controller: scrollController,
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    return ListTile(
                      key: Key('outline_$i'),
                      contentPadding: EdgeInsets.only(
                        left: 20.0 + 16.0 * e.depth.clamp(0, 6),
                        right: 20,
                      ),
                      dense: e.depth > 0,
                      title: Text(
                        e.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: e.pageNumber == null
                          ? null
                          : Text(
                              '${e.pageNumber}',
                              style: theme.textTheme.bodySmall,
                            ),
                      onTap: () => onSelect(e),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
