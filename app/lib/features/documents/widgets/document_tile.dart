import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_format.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/db/app_database.dart';
import '../document_actions.dart';
import '../documents_logic.dart';
import '../documents_providers.dart';

/// Trạng thái riêng của một file mà dòng / thẻ cần theo dõi.
/// select: đổi sao của file khác không làm dựng lại dòng này.
(bool isFavorite, bool locked) _watchDocState(WidgetRef ref, DocItem item) => (
  ref.watch(
    favoritePathsProvider.select((v) => v.value?.contains(item.path) ?? false),
  ),
  ref.watch(pdfLockedProvider(item.path)).value ?? false,
);

String _infoLine(BuildContext context, DocItem item) => formatFileInfoLine(
  item.size,
  item.modified,
  item.folder,
  Localizations.localeOf(context).toString(),
);

/// Một dòng tài liệu: biểu tượng · tên · thông tin · ⭐ · ⋮.
///
/// Không có nền riêng: nền trắng bo góc do khối cha vẽ (`CardSection` / `CardRow`).
class DocumentTile extends ConsumerWidget {
  const DocumentTile(this.item, {super.key});

  final DocItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final (isFavorite, locked) = _watchDocState(ref, item);

    // Material trong suốt: vệt chạm vẽ trên nền của khối cha thay vì bị nền che mất.
    return Material(
      key: ValueKey(item.path),
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => openDocumentWithFeedback(context, item.path),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 2, 8),
          child: Row(
            children: [
              FileTypeIcon(item.type, size: 40, locked: locked),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: t.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _infoLine(context, item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: t.textMuted),
                    ),
                  ],
                ),
              ),
              _FavoriteButton(item: item, isFavorite: isFavorite),
              _MoreButton(
                onPressed: () => showDocumentMenu(
                  context,
                  ref,
                  item,
                  isFavorite: isFavorite,
                  locked: locked,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thẻ tài liệu lớn cho lưới Tập tin trên máy tính bảng: vùng xem trước màu nhạt theo
/// loại file + icon 48×60, tên tối đa 2 dòng, ⭐ và ⋮ xếp dọc bên phải.
class DocumentCard extends ConsumerWidget {
  const DocumentCard(this.item, {super.key});

  final DocItem item;

  /// Chiều cao vùng xem trước.
  static const double previewHeight = 116;

  /// Chiều cao cả thẻ theo cỡ chữ hệ thống (để lưới đặt `mainAxisExtent`).
  static double heightFor(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final text =
        scaler.scale(14) * 1.35 * 2 + 4 + scaler.scale(12) * 1.45;
    // 12 + 12: đệm trên/dưới phần chữ; 84 = cột ⭐ (44) + ⋮ (40); 2 = viền.
    return previewHeight + 24 + (text > 84 ? text : 84) + 2;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (isFavorite, locked) = _watchDocState(ref, item);

    return Container(
      key: ValueKey(item.path),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => openDocumentWithFeedback(context, item.path),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: previewHeight,
                color: AppColors.forDocType(
                  item.type,
                ).withValues(alpha: dark ? 0.16 : 0.09),
                alignment: Alignment.center,
                child: FileTypeIcon(item.type, size: 60, locked: locked),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 2, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                              color: t.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _infoLine(context, item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: t.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        _FavoriteButton(item: item, isFavorite: isFavorite),
                        _MoreButton(
                          height: 40,
                          onPressed: () => showDocumentMenu(
                            context,
                            ref,
                            item,
                            isFavorite: isFavorite,
                            locked: locked,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nút sao 36×44: đặc màu vàng khi đã thích, viền mờ khi chưa.
class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton({required this.item, required this.isFavorite});

  final DocItem item;
  final bool isFavorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return IconButton(
      tooltip: isFavorite ? l.core_removeFavorite : l.core_favorite,
      style: _smallIconStyle(44),
      icon: Icon(
        Symbols.star_rounded,
        size: 22,
        fill: isFavorite ? 1 : 0,
        color: isFavorite ? AppColors.favorite : context.tokens.lineStrong,
      ),
      onPressed: () =>
          ref.read(appDatabaseProvider).favoritesDao.toggle(item.path),
    );
  }
}

/// Nút ⋮ mở bảng thao tác của file.
class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.onPressed, this.height = 44});

  final VoidCallback onPressed;
  final double height;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: MaterialLocalizations.of(context).showMenuTooltip,
    style: _smallIconStyle(height),
    icon: Icon(
      Symbols.more_vert_rounded,
      size: 22,
      color: context.tokens.textMuted,
    ),
    onPressed: onPressed,
  );
}

/// Nút icon hẹp (rộng 36) như thiết kế, không nới vùng chạm ra 48 để dòng không cao thêm.
ButtonStyle _smallIconStyle(double height) => IconButton.styleFrom(
  fixedSize: Size(36, height),
  minimumSize: Size(36, height),
  padding: EdgeInsets.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

/// Bảng thao tác của một file (⋮): điện thoại là bottom sheet, máy tính bảng là hộp thoại.
/// Đầu bảng là icon + tên + thông tin; mỗi thao tác đóng bảng trước rồi mới chạy.
Future<void> showDocumentMenu(
  BuildContext context,
  WidgetRef ref,
  DocItem item, {
  required bool isFavorite,
  required bool locked,
}) {
  final l = context.l10n;
  final info = _infoLine(context, item);
  return showAppSheet<void>(
    context,
    builder: (sheetContext) {
      final t = sheetContext.tokens;
      void run(Future<void> Function() action) {
        Navigator.of(sheetContext).pop();
        unawaited(action());
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: t.line)),
            ),
            child: Row(
              children: [
                FileTypeIcon(item.type, size: 40, locked: locked),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: t.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        info,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: t.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SheetOption(
            key: const ValueKey('doc-menu-open'),
            icon: Symbols.open_in_new_rounded,
            label: l.core_open,
            onTap: () =>
                run(() => openDocumentWithFeedback(context, item.path)),
          ),
          SheetOption(
            key: const ValueKey('doc-menu-rename'),
            icon: Symbols.edit_rounded,
            label: l.core_rename,
            onTap: () => run(() => renameDocument(context, ref, item)),
          ),
          SheetOption(
            key: const ValueKey('doc-menu-share'),
            icon: Symbols.share_rounded,
            label: l.core_share,
            onTap: () => run(() => shareDocument(item)),
          ),
          SheetOption(
            key: const ValueKey('doc-menu-favorite'),
            icon: Symbols.star_rounded,
            label: isFavorite ? l.core_removeFavorite : l.core_favorite,
            onTap: () => run(
              () => ref.read(appDatabaseProvider).favoritesDao.toggle(item.path),
            ),
          ),
          SheetOption(
            key: const ValueKey('doc-menu-info'),
            icon: Symbols.info_rounded,
            label: l.core_info,
            onTap: () => run(() => showDocumentInfo(context, item)),
          ),
          SheetOption(
            key: const ValueKey('doc-menu-delete'),
            icon: Symbols.delete_rounded,
            label: l.core_delete,
            danger: true,
            onTap: () => run(() => deleteDocument(context, ref, item)),
          ),
        ],
      );
    },
  );
}
