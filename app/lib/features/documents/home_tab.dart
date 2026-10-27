import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/tools/tool_registry.dart';
import 'document_actions.dart';
import 'documents_logic.dart';
import 'documents_providers.dart';
import 'widgets/document_tile.dart';

/// Tab "Trang chủ": ô tìm kiếm, 3 ô tính năng chính, Yêu thích và Gần đây.
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final recents = ref.watch(homeRecentItemsProvider).value ?? const [];
    final favorites = ref.watch(homeFavoriteItemsProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(l.core_appName)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _SearchBar(hint: l.docs_searchHint),
          const _FeatureTiles(),
          _Section(
            title: l.docs_favorites,
            viewAllKey: const ValueKey('home-favorites-all'),
            route: Routes.favorites,
            empty: l.docs_emptyFavorites,
            items: favorites,
          ),
          _Section(
            title: l.docs_recents,
            viewAllKey: const ValueKey('home-view-all'),
            route: Routes.recents,
            empty: l.docs_emptyRecents,
            items: recents,
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        key: const ValueKey('home-tab-search'),
        borderRadius: BorderRadius.circular(28),
        onTap: () => context.push(Routes.search),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.search),
              const SizedBox(width: 12),
              Text(hint, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FeatureTiles extends StatelessWidget {
  const _FeatureTiles();

  ToolSpec _tool(String id) => allTools.firstWhere((t) => t.id == id);

  @override
  Widget build(BuildContext context) {
    final image = _tool('imageToPdf');
    final scanner = _tool('scanner');
    final toImage = _tool('pdfToImage');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SizedBox(
        height: 176,
        child: Row(
          children: [
            Expanded(
              flex: 11,
              child: _Tile(
                tool: image,
                colors: const [Color(0xFFEF5350), AppColors.primaryDark],
                iconSize: 56,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _Tile(
                      tool: scanner,
                      colors: const [Color(0xFF42A5F5), Color(0xFF1565C0)],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _Tile(
                      tool: toImage,
                      colors: const [Color(0xFFFFA726), Color(0xFFE65100)],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.tool, required this.colors, this.iconSize = 32});

  final ToolSpec tool;
  final List<Color> colors;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Material(
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: Ink(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: InkWell(
        key: ValueKey('home-tile-${tool.id}'),
        onTap: () => launchTool(context, tool),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(tool.icon, color: Colors.white, size: iconSize),
              const Spacer(),
              Text(
                toolLabel(context, tool),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.viewAllKey,
    required this.route,
    required this.empty,
    required this.items,
  });

  final String title;
  final Key viewAllKey;
  final String route;
  final String empty;
  final List<DocItem> items;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              key: viewAllKey,
              onPressed: () => context.push(route),
              child: Text('${context.l10n.docs_viewAll} ›'),
            ),
          ],
        ),
      ),
      if (items.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text(empty)),
        )
      else
        for (final item in items) DocumentTile(item),
    ],
  );
}
