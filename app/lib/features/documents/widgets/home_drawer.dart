import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/app_logo.dart';

/// Ngăn kéo bên trái (chỉ điện thoại): logo + tên app, rồi Gần đây, Yêu thích và các mục
/// cài đặt (route của T10). Máy tính bảng không dùng ngăn kéo.
class HomeDrawer extends StatelessWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    void go(String route) {
      Navigator.of(context).pop();
      context.push(route);
    }

    // Một dòng cao 50 dạng viên: icon mờ · nhãn.
    Widget item(IconData icon, String label, String route, String key) =>
        Material(
          key: ValueKey(key),
          type: MaterialType.transparency,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => go(route),
            child: SizedBox(
              height: 50,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Icon(icon, size: 22, color: t.textMuted),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: t.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

    return Drawer(
      width: 300,
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 18),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: const AppLogo(size: 40),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.core_appName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: t.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            item(
              Symbols.history_rounded,
              l.docs_recents,
              Routes.recents,
              'drawer-recents',
            ),
            item(
              Symbols.star_rounded,
              l.docs_favorites,
              Routes.favorites,
              'drawer-favorites',
            ),
            item(
              Symbols.translate_rounded,
              l.docs_drawerLanguage,
              Routes.language,
              'drawer-language',
            ),
            item(
              Symbols.contrast_rounded,
              l.docs_drawerTheme,
              Routes.settings,
              'drawer-theme',
            ),
            item(
              Symbols.folder_open_rounded,
              l.docs_drawerOutputFolder,
              Routes.settings,
              'drawer-output',
            ),
            item(
              Symbols.info_rounded,
              l.docs_drawerAbout,
              Routes.about,
              'drawer-about',
            ),
          ],
        ),
      ),
    );
  }
}
