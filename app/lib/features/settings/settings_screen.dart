import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/router/routes.dart';
import '../../data/settings/settings_providers.dart';
import 'output_dir_screen.dart';
import 'page_size_screen.dart';
import 'settings_logic.dart';
import 'theme_screen.dart';

/// Màn Cài đặt gốc: liệt kê Ngôn ngữ, Giao diện, Thư mục lưu, Khổ giấy mặc định, Giới thiệu;
/// phụ đề hiện giá trị đang chọn.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);

    void open(Widget screen) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => screen));

    return Scaffold(
      appBar: AppBar(title: Text(l.settings_title)),
      body: ListView(
        children: [
          ListTile(
            key: const ValueKey('settings_language'),
            leading: const Icon(Icons.language),
            title: Text(l.settings_language),
            subtitle: Text(
              s.locale == null
                  ? l.settings_languageSystem
                  : (localeNativeNames[s.locale!.languageCode] ??
                        s.locale!.languageCode),
            ),
            onTap: () => context.push(Routes.language),
          ),
          ListTile(
            key: const ValueKey('settings_theme'),
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(l.settings_theme),
            subtitle: Text(themeModeLabel(context, s.themeMode)),
            onTap: () => open(const ThemeScreen()),
          ),
          ListTile(
            key: const ValueKey('settings_outputDir'),
            leading: const Icon(Icons.folder_outlined),
            title: Text(l.settings_outputDir),
            subtitle: Text(
              effectiveOutputDir(s.outputDir),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => open(const OutputDirScreen()),
          ),
          ListTile(
            key: const ValueKey('settings_pageSize'),
            leading: const Icon(Icons.crop_portrait),
            title: Text(l.settings_pageSize),
            subtitle: Text(pageSizeLabel(context, s.defaultPageSize)),
            onTap: () => open(const PageSizeScreen()),
          ),
          const Divider(),
          ListTile(
            key: const ValueKey('settings_about'),
            leading: const Icon(Icons.info_outline),
            title: Text(l.settings_about),
            subtitle: Text(l.settings_version(kAppVersion)),
            onTap: () => context.push(Routes.about),
          ),
        ],
      ),
    );
  }
}
