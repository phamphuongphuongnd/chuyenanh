import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_error.dart';
import '../../core/l10n/l10n.dart';
import '../../core/widgets/widgets.dart';
import 'documents_logic.dart';
import 'documents_providers.dart';
import 'widgets/document_list.dart';
import 'widgets/document_tile.dart';
import 'widgets/sort_menu.dart';

/// Màn danh sách đơn giản: tiêu đề + danh sách từ [provider] (Gần đây, Yêu thích).
class SimpleDocListScreen extends ConsumerWidget {
  const SimpleDocListScreen({
    super.key,
    required this.title,
    required this.provider,
    required this.emptyTitle,
    this.emptyMessage,
    this.emptyIcon = Icons.folder_open_outlined,
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
      appBar: AppBar(title: Text(title)),
      body: items.when(
        loading: () => const DocumentListSkeleton(),
        error: (e, _) =>
            EmptyState(title: appErrorMessage(context, AppError.from(e))),
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: emptyIcon,
                title: emptyTitle,
                message: emptyMessage,
              )
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) => DocumentTile(list[i]),
              ),
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
    emptyIcon: Icons.history,
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
    emptyIcon: Icons.star_border,
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
      appBar: AppBar(
        title: AppSearchField(
          key: const ValueKey('search-field'),
          controller: _controller,
          hintText: l.docs_searchHint,
          onChanged: _onChanged,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _clear,
            ),
          const SortMenuButton(),
        ],
      ),
      body: docs.when(
        loading: () => const DocumentListSkeleton(),
        error: (e, _) =>
            EmptyState(title: appErrorMessage(context, AppError.from(e))),
        data: (items) {
          final result = sortDocuments(
            filterDocuments(items, query: _query),
            sort,
          );
          if (result.isEmpty) {
            return EmptyState(
              icon: Icons.search_off,
              title: l.docs_emptySearch,
            );
          }
          return ListView.builder(
            itemCount: result.length,
            itemBuilder: (_, i) => DocumentTile(result[i]),
          );
        },
      ),
    );
  }
}
