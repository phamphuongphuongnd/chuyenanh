import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/utils/file_format.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/db/app_database.dart';
import '../document_actions.dart';
import '../documents_logic.dart';
import '../documents_providers.dart';

enum _Menu { open, rename, share, favorite, info, delete }

/// Một dòng tài liệu: biểu tượng · tên · thông tin · ⭐ · ⋮.
class DocumentTile extends ConsumerWidget {
  const DocumentTile(this.item, {super.key});

  final DocItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final isFavorite =
        ref.watch(favoritePathsProvider).value?.contains(item.path) ?? false;
    final locked = ref.watch(pdfLockedProvider(item.path)).value ?? false;

    return ListTile(
      key: ValueKey(item.path),
      leading: FileTypeIcon(item.type, locked: locked),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        formatFileInfoLine(item.size, item.modified, item.folder, locale),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => openDocumentWithFeedback(context, item.path),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: isFavorite ? l.core_removeFavorite : l.core_favorite,
            icon: Icon(
              isFavorite ? Icons.star : Icons.star_border,
              color: isFavorite ? Colors.amber : null,
            ),
            onPressed: () =>
                ref.read(appDatabaseProvider).favoritesDao.toggle(item.path),
          ),
          PopupMenuButton<_Menu>(
            onSelected: (m) => _onMenu(context, ref, m),
            itemBuilder: (_) => [
              PopupMenuItem(value: _Menu.open, child: Text(l.core_open)),
              PopupMenuItem(value: _Menu.rename, child: Text(l.core_rename)),
              PopupMenuItem(value: _Menu.share, child: Text(l.core_share)),
              PopupMenuItem(
                value: _Menu.favorite,
                child: Text(
                  isFavorite ? l.core_removeFavorite : l.core_favorite,
                ),
              ),
              PopupMenuItem(value: _Menu.info, child: Text(l.core_info)),
              PopupMenuItem(value: _Menu.delete, child: Text(l.core_delete)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onMenu(BuildContext context, WidgetRef ref, _Menu m) {
    switch (m) {
      case _Menu.open:
        return openDocumentWithFeedback(context, item.path);
      case _Menu.rename:
        return renameDocument(context, ref, item);
      case _Menu.share:
        return shareDocument(item);
      case _Menu.favorite:
        return ref.read(appDatabaseProvider).favoritesDao.toggle(item.path);
      case _Menu.info:
        return showDocumentInfo(context, item);
      case _Menu.delete:
        return deleteDocument(context, ref, item);
    }
  }
}
