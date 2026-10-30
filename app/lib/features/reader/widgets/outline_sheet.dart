import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
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
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SheetTitle(l.reader_outline),
        ),
        Expanded(
          child: entries.isEmpty
              // Trống: vẫn cuộn theo sheet để kéo nhỏ không bị tràn.
              ? ListView(
                  controller: scrollController,
                  children: [
                    EmptyState(
                      icon: Symbols.format_list_bulleted_rounded,
                      title: l.reader_noOutline,
                    ),
                  ],
                )
              : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    final nested = e.depth > 0;
                    // Dòng kiểu bảng chọn (bo 16); thụt lề 16/cấp, tối đa 6 cấp.
                    return Material(
                      key: Key('outline_$i'),
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => onSelect(e),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: nested ? 44 : 52,
                          ),
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: 14.0 + 16.0 * e.depth.clamp(0, 6),
                              right: 14,
                              top: 8,
                              bottom: 8,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    e.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: nested ? 14.5 : 15.5,
                                      fontWeight: nested
                                          ? FontWeight.w500
                                          : FontWeight.w600,
                                      color: t.text,
                                    ),
                                  ),
                                ),
                                if (e.pageNumber != null) ...[
                                  const SizedBox(width: 12),
                                  Text(
                                    '${e.pageNumber}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: t.textMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
