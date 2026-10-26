import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../documents_logic.dart';
import '../documents_providers.dart';

String sortLabel(AppLocalizations l, DocSort s) => switch (s) {
  DocSort.nameAsc => l.docs_sortNameAsc,
  DocSort.nameDesc => l.docs_sortNameDesc,
  DocSort.dateDesc => l.docs_sortDateDesc,
  DocSort.dateAsc => l.docs_sortDateAsc,
  DocSort.sizeDesc => l.docs_sortSizeDesc,
  DocSort.sizeAsc => l.docs_sortSizeAsc,
};

/// Nút ⇅ mở menu chọn cách sắp xếp (lựa chọn được lưu).
class SortMenuButton extends ConsumerWidget {
  const SortMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final current = ref.watch(docSortProvider);
    return PopupMenuButton<DocSort>(
      key: const ValueKey('sort-menu'),
      tooltip: l.docs_sort,
      icon: const Icon(Icons.swap_vert),
      initialValue: current,
      onSelected: (s) => ref.read(docSortProvider.notifier).set(s),
      itemBuilder: (_) => [
        for (final s in DocSort.values)
          CheckedPopupMenuItem(
            value: s,
            checked: s == current,
            child: Text(sortLabel(l, s)),
          ),
      ],
    );
  }
}
