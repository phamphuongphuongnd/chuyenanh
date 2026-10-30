import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/errors/app_error.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sort = ref.watch(docSortProvider);
    final docs = ref.watch(documentsProvider);
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
          final result = sortDocuments(
            filterDocuments(items, query: _query),
            sort,
          );
          if (result.isEmpty) {
            return EmptyState(
              icon: Symbols.search_off_rounded,
              title: l.docs_emptySearch,
            );
          }
          return _DocCardList(result);
        },
      ),
    );
  }
}
