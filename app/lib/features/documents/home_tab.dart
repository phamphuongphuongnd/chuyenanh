import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/l10n/l10n.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/tools/tool_registry.dart';
import '../../core/widgets/widgets.dart';
import '../settings/app_logo.dart';
import 'document_actions.dart';
import 'documents_logic.dart';
import 'documents_providers.dart';
import 'widgets/document_tile.dart';

/// Bề rộng nội dung tối thiểu để đặt Yêu thích và Gần đây cạnh nhau (2 × 340 + khe 20).
const double _kSideBySideMinWidth = 700;

/// Tab "Trang chủ" (thiết kế `design-mobile`, khối `isHome`): logo + tên app, ô tìm kiếm,
/// 3 ô tính năng chính, Yêu thích và Gần đây.
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
      _FeatureTiles(tablet: tablet),
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

/// 3 ô tính năng: điện thoại = ô "Ảnh sang PDF" lớn + hàng 2 ô; máy tính bảng = 3 ô một hàng.
class _FeatureTiles extends StatelessWidget {
  const _FeatureTiles({required this.tablet});

  final bool tablet;

  ToolSpec _tool(String id) => allTools.firstWhere((t) => t.id == id);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final image = _tool('imageToPdf');
    final scanner = _tool('scanner');
    final toImage = _tool('pdfToImage');
    final scan = _SmallTile(
      tool: scanner,
      icon: Symbols.document_scanner_rounded,
      iconColor: AppColors.doc,
      iconBg: t.tintBlue,
      tablet: tablet,
    );
    final toImg = _SmallTile(
      tool: toImage,
      icon: Symbols.imagesmode_rounded,
      iconColor: AppColors.ppt,
      iconBg: t.tintOrange,
      tablet: tablet,
    );

    if (tablet) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 13, child: _PrimaryTile(tool: image, tablet: true)),
            const SizedBox(width: 14),
            Expanded(flex: 10, child: scan),
            const SizedBox(width: 14),
            Expanded(flex: 10, child: toImg),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PrimaryTile(tool: image, tablet: false),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: scan),
              const SizedBox(width: 10),
              Expanded(child: toImg),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ô đỏ "Ảnh sang PDF": [ảnh] → [trang PDF], nhãn, nút tròn "+".
class _PrimaryTile extends StatelessWidget {
  const _PrimaryTile({required this.tool, required this.tablet});

  final ToolSpec tool;
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(tablet ? 24 : 22);
    final box = tablet ? 44.0 : 40.0;
    final graphic = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: box,
          height: box,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(tablet ? 14 : 12),
          ),
          alignment: Alignment.center,
          child: Icon(
            Symbols.photo_library_rounded,
            size: tablet ? 25 : 23,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 6),
        Icon(
          Symbols.arrow_forward_rounded,
          size: 18,
          color: Colors.white.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 6),
        _MiniPdfPage(
          width: tablet ? 34 : 30,
          height: tablet ? 42 : 38,
          fontSize: tablet ? 9 : 8.5,
          bottomPadding: tablet ? 6 : 5,
        ),
      ],
    );
    final label = Text(
      toolLabel(context, tool),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: tablet ? 19 : 18,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: Colors.white,
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: AppShadows.primary,
      ),
      child: Material(
        color: AppColors.primary,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('home-tile-${tool.id}'),
          onTap: () => launchTool(context, tool),
          child: tablet
              ? ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 150),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [graphic, const SizedBox(height: 28), label],
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                  child: Row(
                    children: [
                      graphic,
                      const SizedBox(width: 14),
                      Expanded(child: label),
                      const SizedBox(width: 14),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Symbols.add_rounded,
                          size: 22,
                          color: AppColors.primary,
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

/// Trang PDF trắng nhỏ cắt góc trên phải, chữ "PDF" đỏ ở đáy.
class _MiniPdfPage extends StatelessWidget {
  const _MiniPdfPage({
    required this.width,
    required this.height,
    required this.fontSize,
    required this.bottomPadding,
  });

  final double width;
  final double height;
  final double fontSize;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: const _CutCornerClipper(radius: 5),
    child: Container(
      width: width,
      height: height,
      color: Colors.white,
      alignment: Alignment.bottomCenter,
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Text(
        'PDF',
        maxLines: 1,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          height: 1,
          color: AppColors.primary,
        ),
      ),
    ),
  );
}

/// Hình trang giấy bo góc, cắt góc trên phải từ 68% cạnh trên xuống 28% cạnh phải
/// (cùng hình học với `FileTypeIcon`).
class _CutCornerClipper extends CustomClipper<Path> {
  const _CutCornerClipper({required this.radius});

  final double radius;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final r = radius;
    return Path()
      ..moveTo(r, 0)
      ..lineTo(w * 0.68, 0)
      ..lineTo(w, h * 0.28)
      ..lineTo(w, h - r)
      ..quadraticBezierTo(w, h, w - r, h)
      ..lineTo(r, h)
      ..quadraticBezierTo(0, h, 0, h - r)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..close();
  }

  @override
  bool shouldReclip(_CutCornerClipper old) => old.radius != radius;
}

/// Ô tính năng nền surface: hộp icon màu nhạt + nhãn.
class _SmallTile extends StatelessWidget {
  const _SmallTile({
    required this.tool,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.tablet,
  });

  final ToolSpec tool;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final box = tablet ? 44.0 : 40.0;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: tablet
          ? MainAxisAlignment.spaceBetween
          : MainAxisAlignment.start,
      children: [
        Container(
          width: box,
          height: box,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(tablet ? 14 : 12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: tablet ? 25 : 23, color: iconColor),
        ),
        SizedBox(height: tablet ? 28 : 14),
        Text(
          toolLabel(context, tool),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: tablet ? 17 : 14.5,
            fontWeight: FontWeight.w700,
            height: 1.25,
            color: t.text,
          ),
        ),
      ],
    );
    return Material(
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tablet ? 24 : 20),
        side: BorderSide(color: t.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('home-tile-${tool.id}'),
        onTap: () => launchTool(context, tool),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: tablet ? 150 : 0),
          child: Padding(
            padding: EdgeInsets.all(tablet ? 18 : 14),
            child: content,
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
