import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/errors/app_error.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/db/app_database.dart' show ContentHit;
import '../content_index/content_index_providers.dart';
import '../content_index/logic/search_text.dart';
import '../content_index/widgets/content_search_widgets.dart';
import 'documents_logic.dart';
import 'documents_providers.dart';
import 'widgets/document_list.dart';
import 'widgets/document_tile.dart';
import 'widgets/sort_menu.dart';

/// Danh sách tài liệu trong một khối bo 20 (dòng đầu/cuối tự bo góc), lề 16/14/16/24.
class _DocCardList extends StatelessWidget {
  const _DocCardList(this.items);

  final List<DocItem> items;

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
    itemCount: items.length,
    itemBuilder: (_, i) => CardRow(
      first: i == 0,
      last: i == items.length - 1,
      child: DocumentTile(items[i]),
    ),
  );
}

/// Màn danh sách đơn giản: tiêu đề + danh sách từ [provider] (Gần đây, Yêu thích).
class SimpleDocListScreen extends ConsumerWidget {
  const SimpleDocListScreen({
    super.key,
    required this.title,
    required this.provider,
    required this.emptyTitle,
    this.emptyMessage,
    this.emptyIcon = Symbols.folder_open_rounded,
  });

  final String title;
  final StreamProvider<List<DocItem>> provider;
  final String emptyTitle;
  final String? emptyMessage;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(provider);
    return Scaffold(
      backgroundColor: context.tokens.bg,
      appBar: AppBar(title: Text(title)),
      body: items.when(
        loading: () => const DocumentListSkeleton(),
        error: (e, _) => EmptyState(
          icon: Symbols.error_rounded,
          title: appErrorMessage(context, AppError.from(e)),
        ),
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: emptyIcon,
                title: emptyTitle,
                message: emptyMessage,
              )
            : _DocCardList(list),
      ),
    );
  }
}

class RecentsScreen extends StatelessWidget {
  const RecentsScreen({super.key});

  @override
  Widget build(BuildContext context) => SimpleDocListScreen(
    title: context.l10n.docs_recents,
    provider: recentItemsProvider,
    emptyTitle: context.l10n.docs_emptyRecents,
    emptyIcon: Symbols.history_rounded,
  );
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) => SimpleDocListScreen(
    title: context.l10n.docs_favorites,
    provider: favoriteItemsProvider,
    emptyTitle: context.l10n.docs_emptyFavorites,
    emptyMessage: context.l10n.docs_emptyFavoritesHint,
    emptyIcon: Symbols.star_rounded,
  );
}

/// Tìm theo tên trong mọi tài liệu đã quét.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  /// Truy vấn dùng để lọc (trễ ~200ms so với ô nhập).
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    // Ô nhập/nút xoá cập nhật tức thì; chỉ việc lọc danh sách bị trễ.
    final hadText = _lastHadText;
    _lastHadText = text.isNotEmpty;
    if (hadText != _lastHadText) setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _query = text);
    });
  }

  bool _lastHadText = false;

  void _clear() {
    _debounce?.cancel();
    setState(() {
      _controller.clear();
      _query = '';
      _lastHadText = false;
    });
  }

  /// Tên file đã chuẩn hoá (bỏ dấu) — tính một lần cho mỗi tên.
  final _foldedNames = <String, String>{};

  /// Khớp tên: như cũ (chứa từ khoá, không phân biệt hoa thường) hoặc khớp khi bỏ dấu
  /// (gõ "hop dong" ra "Hợp đồng.pdf").
  List<DocItem> _matchByName(List<DocItem> items, String normalized) {
    final plain = filterDocuments(items, query: _query);
    if (normalized.isEmpty) return plain;
    final hit = {for (final d in plain) d.path};
    return [
      for (final d in items)
        if (hit.contains(d.path) ||
            _foldedNames
                .putIfAbsent(d.name, () => normalizeForSearch(d.name))
                .contains(normalized))
          d,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sort = ref.watch(docSortProvider);
    final docs = ref.watch(documentsProvider);
    // Điểm khởi động bộ lập chỉ mục nội dung (sống suốt phiên, chạy nền từng file một).
    final index = ref.watch(contentIndexProvider);
    final normalized = normalizeQuery(_query);
    final hits = normalized.length >= minContentQueryLength
        ? ref.watch(contentSearchProvider(normalized)).value ??
              const <ContentHit>[]
        : const <ContentHit>[];
    return Scaffold(
      backgroundColor: context.tokens.bg,
      // Ô tìm kiếm chữ trắng → thanh tiêu đề giữ nền đỏ (AppBar mặc định của app là nền sáng).
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: AppSearchField(
          key: const ValueKey('search-field'),
          controller: _controller,
          hintText: l.docs_searchHint,
          onChanged: _onChanged,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Symbols.close_rounded, color: Colors.white),
              onPressed: _clear,
            ),
          const SortMenuButton(iconColor: Colors.white),
        ],
      ),
      body: docs.when(
        loading: () => const DocumentListSkeleton(),
        error: (e, _) => EmptyState(
          icon: Symbols.error_rounded,
          title: appErrorMessage(context, AppError.from(e)),
        ),
        data: (items) {
          if (normalized.isEmpty) {
            final all = sortDocuments(items, sort);
            if (all.isEmpty) {
              return EmptyState(
                icon: Symbols.search_off_rounded,
                title: l.docs_emptySearch,
              );
            }
            return _DocCardList(all);
          }
          final byName = sortDocuments(_matchByName(items, normalized), sort);
          // Nhóm "Trong nội dung": file có chữ khớp, bỏ file đã khớp tên / không còn trong danh sách.
          final namePaths = {for (final d in byName) d.path};
          final itemByPath = {for (final d in items) d.path: d};
          final hitByPath = <String, ContentHit>{
            for (final h in hits)
              if (!namePaths.contains(h.path) && itemByPath.containsKey(h.path))
                h.path: h,
          };
          final byContent = sortDocuments([
            for (final p in hitByPath.keys) itemByPath[p]!,
          ], sort);
          if (byName.isEmpty && byContent.isEmpty) {
            return EmptyState(
              icon: Symbols.search_off_rounded,
              title: l.docs_emptySearch,
              message: index.isIndexing
                  ? l.cindex_indexing(index.done, index.total)
                  : null,
            );
          }
          return _SearchResults(
            byName: byName,
            byContent: [
              for (final d in byContent)
                (d, excerptFor(hitByPath[d.path]!, normalized)),
            ],
            index: index,
          );
        },
      ),
    );
  }
}

/// Kết quả tìm: dòng trạng thái lập chỉ mục · nhóm khớp tên · nhóm "Trong nội dung".
class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.byName,
    required this.byContent,
    required this.index,
  });

  final List<DocItem> byName;
  final List<(DocItem, Excerpt)> byContent;
  final ContentIndexState index;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Dựng lười từng dòng: danh sách tên có thể rất dài.
    final rows = <Widget Function()>[
      if (index.isIndexing) () => ContentIndexStatusLine(index),
      if (byContent.isNotEmpty && byName.isNotEmpty)
        () => SearchGroupHeader(l.cindex_inNames),
      for (var i = 0; i < byName.length; i++)
        () => CardRow(
          first: i == 0,
          last: i == byName.length - 1,
          child: DocumentTile(byName[i]),
        ),
      if (byContent.isNotEmpty)
        () => SearchGroupHeader(
          l.cindex_inContent,
          key: const ValueKey('search-group-content'),
        ),
      for (var i = 0; i < byContent.length; i++)
        () => CardRow(
          first: i == 0,
          last: i == byContent.length - 1,
          child: ContentHitTile(
            item: byContent[i].$1,
            excerpt: byContent[i].$2,
          ),
        ),
    ];
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: rows.length,
      itemBuilder: (_, i) => rows[i](),
    );
  }
}
