import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
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

/// Nút mở menu chọn cách sắp xếp (lựa chọn được lưu).
///
/// Mặc định là nút icon ⇅ trên thanh tiêu đề (`key: sort-menu`); [SortMenuButton.inline]
/// là nút chữ "tên cách sắp xếp ▾" ở đầu danh sách, mở cùng menu.
class SortMenuButton extends ConsumerWidget {
  const SortMenuButton({
    super.key = const ValueKey('sort-menu'),
    this.iconColor,
    this.iconSize = 23,
    this.buttonSize,
  }) : _inline = false;

  const SortMenuButton.inline({super.key = const ValueKey('sort-menu-inline')})
    : _inline = true,
      iconColor = null,
      iconSize = 18,
      buttonSize = null;

  /// Màu icon ⇅ (trắng trên thanh tiêu đề màu); null = theo thanh chứa nó.
  final Color? iconColor;
  final double iconSize;

  /// Cỡ cố định của nút icon (khối tiêu đề Tập tin); null = cỡ mặc định của IconButton.
  final Size? buttonSize;
  final bool _inline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = context.tokens;
    final current = ref.watch(docSortProvider);
    return PopupMenuButton<DocSort>(
      tooltip: l.docs_sort,
      initialValue: current,
      position: PopupMenuPosition.under,
      menuPadding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 230, maxWidth: 280),
      onSelected: (s) => ref.read(docSortProvider.notifier).set(s),
      icon: _inline
          ? null
          : Icon(Symbols.swap_vert_rounded, size: iconSize, color: iconColor),
      iconColor: iconColor,
      style: buttonSize == null
          ? null
          : IconButton.styleFrom(
              fixedSize: buttonSize,
              minimumSize: buttonSize,
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
      child: _inline
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sortLabel(l, current),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: t.text,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Symbols.expand_more_rounded, size: iconSize, color: t.text),
                ],
              ),
            )
          : null,
      itemBuilder: (context) => [
        _SortMenuHeader(l.docs_sort),
        for (final s in DocSort.values)
          PopupMenuItem<DocSort>(
            key: ValueKey('sort-${s.name}'),
            value: s,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    sortLabel(l, s),
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: t.text,
                    ),
                  ),
                ),
                if (s == current)
                  const Icon(
                    Symbols.check_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Dòng chữ "Sắp xếp" nhỏ ở đầu menu (không chọn được).
class _SortMenuHeader extends PopupMenuEntry<DocSort> {
  const _SortMenuHeader(this.text);

  final String text;

  @override
  double get height => 32;

  @override
  bool represents(DocSort? value) => false;

  @override
  State<_SortMenuHeader> createState() => _SortMenuHeaderState();
}

class _SortMenuHeaderState extends State<_SortMenuHeader> {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
    child: Text(
      widget.text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: context.tokens.textMuted,
      ),
    ),
  );
}
