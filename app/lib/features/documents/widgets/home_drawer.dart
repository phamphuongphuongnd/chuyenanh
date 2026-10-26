import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';

/// Ngăn kéo bên trái: Gần đây, Yêu thích, rồi các mục cài đặt (route của T10).
class HomeDrawer extends StatelessWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    void go(String route) {
      Navigator.of(context).pop();
      context.push(route);
    }

    Widget item(IconData icon, String label, String route, String key) =>
        ListTile(
          key: ValueKey(key),
          leading: Icon(icon),
          title: Text(label),
          onTap: () => go(route),
        );

    return Drawer(
      child: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              margin: EdgeInsets.zero,
              decoration: const BoxDecoration(color: AppColors.primary),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  l.core_appName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            item(
              Icons.history,
              l.docs_recents,
              Routes.recents,
              'drawer-recents',
            ),
            item(
              Icons.star_border,
              l.docs_favorites,
              Routes.favorites,
              'drawer-favorites',
            ),
            const Divider(),
            item(
              Icons.language,
              l.docs_drawerLanguage,
              Routes.language,
              'drawer-language',
            ),
            item(
              Icons.palette_outlined,
              l.docs_drawerTheme,
              Routes.settings,
              'drawer-theme',
            ),
            item(
              Icons.folder_outlined,
              l.docs_drawerOutputFolder,
              Routes.settings,
              'drawer-output',
            ),
            item(
              Icons.info_outline,
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
