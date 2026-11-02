import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/l10n/l10n.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../settings/app_logo.dart';
import 'documents_logic.dart';
import 'documents_providers.dart';
import 'widgets/document_tile.dart';

/// Bề rộng nội dung tối thiểu để đặt Yêu thích và Gần đây cạnh nhau (2 × 340 + khe 20).
const double _kSideBySideMinWidth = 700;

/// Tab "Trang chủ": logo + tên app, ô tìm kiếm, Yêu thích và Gần đây (không còn ô tính năng:
/// các công cụ nằm ở tab Công cụ).
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = context.tokens;
    final tablet = isTabletLayout(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final recents = ref.watch(homeRecentItemsProvider).value ?? const [];
    final favorites = ref.watch(homeFavoriteItemsProvider).value ?? const [];

    final favSection = _Section(
      title: l.docs_favorites,
      viewAllKey: const ValueKey('home-favorites-all'),
      route: Routes.favorites,
      empty: l.docs_emptyFavorites,
      emptyKind: _EmptyKind.favorites,
      items: favorites,
      tablet: tablet,
    );
    final recentSection = _Section(
      title: l.docs_recents,
      viewAllKey: const ValueKey('home-view-all'),
      route: Routes.recents,
      empty: l.docs_emptyRecents,
      emptyKind: _EmptyKind.recents,
      items: recents,
      tablet: tablet,
    );

    final gap = tablet ? 24.0 : 18.0;
    final children = <Widget>[
      if (tablet)
        // Máy tính bảng: logo + tên app và ô tìm kiếm trên cùng một hàng.
        Row(
          children: [
            const Expanded(child: _Brand()),
            const SizedBox(width: 20),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _SearchBar(hint: l.docs_searchHint, height: 48),
              ),
            ),
          ],
        )
      else ...[
        const _Brand(),
        _SearchBar(hint: l.docs_searchHint, height: 50),
      ],
      if (tablet)
        LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth < _kSideBySideMinWidth) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [favSection, SizedBox(height: gap), recentSection],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: favSection),
                const SizedBox(width: 20),
                Expanded(child: recentSection),
              ],
            );
          },
        )
      else ...[
        favSection,
        recentSection,
      ],
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Icon thanh trạng thái tối ở bản sáng, sáng ở bản tối.
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: ListView(
            padding: tablet
                ? const EdgeInsets.fromLTRB(32, 24, 32, 32)
                : const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: gap),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Logo bo 10 + tên app 24/w800.
class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: const AppLogo(size: 34),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            context.l10n.core_appName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.48, // −0.02em
              color: context.tokens.text,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Ô tìm kiếm dạng viên; bấm → màn Tìm kiếm.
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.hint, required this.height});

  final String hint;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = BorderRadius.circular(height / 2);
    return Material(
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: t.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('home-tab-search'),
        onTap: () => context.push(Routes.search),
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Icon(Symbols.search_rounded, size: 22, color: t.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: t.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _EmptyKind { favorites, recents }

/// Một mục (Yêu thích / Gần đây): tiêu đề + "Xem tất cả ›", tối đa 5 file hoặc khối trống.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.viewAllKey,
    required this.route,
    required this.empty,
    required this.emptyKind,
    required this.items,
    required this.tablet,
  });

  final String title;
  final Key viewAllKey;
  final String route;
  final String empty;
  final _EmptyKind emptyKind;
  final List<DocItem> items;
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: tablet ? 18 : 17,
                    fontWeight: FontWeight.w700,
                    color: t.text,
                  ),
                ),
              ),
              TextButton(
                key: viewAllKey,
                onPressed: () => context.push(route),
                style: TextButton.styleFrom(
                  foregroundColor: t.primaryText,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 10,
                  ),
                  minimumSize: const Size(0, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: TextStyle(
                    fontSize: tablet ? 14 : 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text('${context.l10n.docs_viewAll} ›'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (items.isEmpty)
          _EmptyBlock(text: empty, kind: emptyKind)
        else
          CardSection(
            children: [
              for (final item in items.take(homeSectionLimit))
                DocumentTile(item),
            ],
          ),
      ],
    );
  }
}

/// Khối trống: vòng tròn minh hoạ (tờ giấy + huy hiệu) và một dòng chữ mờ.
class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.text, required this.kind});

  final String text;
  final _EmptyKind kind;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fav = kind == _EmptyKind.favorites;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: t.surface2,
              shape: BoxShape.circle,
            ),
            child: Stack(
              children: [
                // Tờ giấy nhỏ có viền.
                Positioned(
                  left: 17,
                  top: 11,
                  child: Container(
                    width: 22,
                    height: 28,
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: t.lineStrong, width: 1.5),
                    ),
                  ),
                ),
                // Huy hiệu: sao vàng (Yêu thích) / đồng hồ (Gần đây).
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: fav ? AppColors.favorite : t.textMuted,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      fav ? Symbols.star_rounded : Symbols.schedule_rounded,
                      fill: fav ? 1 : 0,
                      size: 14,
                      color: fav ? Colors.white : t.surface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: t.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
