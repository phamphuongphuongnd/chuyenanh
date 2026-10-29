import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/l10n.dart';
import '../../core/platform/app_platform.dart';
import '../../core/router/routes.dart';
import '../../core/utils/link_opener.dart';
import '../../data/settings/settings_providers.dart';
import 'output_dir_screen.dart';
import 'page_size_screen.dart';
import 'privacy_screen.dart';
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
    final isIos = ref.watch(appPlatformProvider) == AppPlatform.ios;

    void open(Widget screen) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => screen));

    Future<void> sendFeedback() async {
      final messenger = ScaffoldMessenger.of(context);
      final launcher = linkLauncherOf(context);
      // Link do chính app tạo, nên không qua bộ lọc `safeLinkUri` của link trong tài liệu.
      final uri = Uri(
        scheme: 'mailto',
        path: kFeedbackEmail,
        query: 'subject=${Uri.encodeComponent(l.settings_feedbackSubject)}',
      );
      var opened = false;
      try {
        opened = await launcher(uri);
      } catch (_) {}
      if (!opened) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.settings_feedbackFailed)),
        );
      }
    }

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.settings_title)),
      body: ListView(
        children: [
          header(l.settings_sectionGeneral),
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
          // iOS không cho chọn thư mục tuỳ ý: file luôn lưu trong Documents của app.
          if (!isIos)
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
          header(l.settings_sectionAbout),
          ListTile(
            key: const ValueKey('settings_share'),
            leading: const Icon(Icons.share_outlined),
            title: Text(l.settings_share),
            onTap: () => SharePlus.instance.share(
              ShareParams(
                text: appShareMessage(l.settings_shareText),
                sharePositionOrigin: defaultShareOrigin(
                  platform: ref.read(appPlatformProvider),
                ),
              ),
            ),
          ),
          ListTile(
            key: const ValueKey('settings_feedback'),
            leading: const Icon(Icons.feedback_outlined),
            title: Text(l.settings_feedback),
            onTap: sendFeedback,
          ),
          ListTile(
            key: const ValueKey('settings_privacy'),
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l.settings_privacy),
            onTap: () => open(const PrivacyScreen()),
          ),
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
