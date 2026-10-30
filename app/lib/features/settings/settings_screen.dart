import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/l10n.dart';
import '../../core/platform/app_platform.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/link_opener.dart';
import '../../core/widgets/widgets.dart';
import '../../data/settings/settings_providers.dart';
import 'language_screen.dart';
import 'output_dir_screen.dart';
import 'page_size_screen.dart';
import 'privacy_screen.dart';
import 'settings_logic.dart';
import 'theme_screen.dart';

/// Màn Cài đặt gốc (tab thứ 4): tiêu đề lớn, nhóm "Chung" (Ngôn ngữ, Giao diện, Thư mục lưu,
/// Khổ giấy mặc định) và nhóm "Về ứng dụng" (Chia sẻ, Phản hồi, Chính sách, Giới thiệu);
/// phụ đề hiện giá trị đang chọn. Ngôn ngữ / Giao diện / Khổ giấy mở bảng chọn tại chỗ.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = context.tokens;
    final s = ref.watch(settingsProvider);
    final isIos = ref.watch(appPlatformProvider) == AppPlatform.ios;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = ModalRoute.of(context)?.canPop ?? false;

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

    final general = <Widget>[
      _SettingsRow(
        key: const ValueKey('settings_language'),
        icon: Symbols.translate_rounded,
        title: l.settings_language,
        subtitle: s.locale == null
            ? l.settings_languageSystem
            : (localeNativeNames[s.locale!.languageCode] ??
                  s.locale!.languageCode),
        onTap: () => showLanguageSheet(context, ref),
      ),
      _SettingsRow(
        key: const ValueKey('settings_theme'),
        icon: Symbols.contrast_rounded,
        title: l.settings_theme,
        subtitle: themeModeLabel(context, s.themeMode),
        onTap: () => showThemeSheet(context, ref),
      ),
      // iOS không cho chọn thư mục tuỳ ý: file luôn lưu trong Documents của app.
      if (!isIos)
        _SettingsRow(
          key: const ValueKey('settings_outputDir'),
          icon: Symbols.folder_open_rounded,
          title: l.settings_outputDir,
          subtitle: effectiveOutputDir(s.outputDir),
          subtitleMaxLines: 2,
          onTap: () => open(const OutputDirScreen()),
        ),
      _SettingsRow(
        key: const ValueKey('settings_pageSize'),
        icon: Symbols.description_rounded,
        title: l.settings_pageSize,
        subtitle: pageSizeLabel(context, s.defaultPageSize),
        onTap: () => showPageSizeSheet(context, ref),
      ),
    ];

    final about = <Widget>[
      _SettingsRow(
        key: const ValueKey('settings_share'),
        icon: Symbols.share_rounded,
        title: l.settings_share,
        onTap: () => SharePlus.instance.share(
          ShareParams(
            text: appShareMessage(l.settings_shareText),
            sharePositionOrigin: defaultShareOrigin(
              platform: ref.read(appPlatformProvider),
            ),
          ),
        ),
      ),
      _SettingsRow(
        key: const ValueKey('settings_feedback'),
        icon: Symbols.mail_rounded,
        title: l.settings_feedback,
        onTap: sendFeedback,
      ),
      _SettingsRow(
        key: const ValueKey('settings_privacy'),
        icon: Symbols.shield_rounded,
        title: l.settings_privacy,
        onTap: () => open(const PrivacyScreen()),
      ),
      _SettingsRow(
        key: const ValueKey('settings_about'),
        icon: Symbols.info_rounded,
        title: l.settings_about,
        subtitle: l.settings_version(kAppVersion),
        onTap: () => context.push(Routes.about),
      ),
    ];

    // Màn không có AppBar nên tự đặt màu icon thanh trạng thái theo nền.
    final overlay =
        (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(statusBarColor: Colors.transparent);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              // Mở thành trang riêng (vd. từ ngăn kéo Trang chủ) thì cần nút quay lại;
              // ở tab Cài đặt của khung chính thì không có.
              if (canPop)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: BackButton(color: t.text),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  l.settings_title,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: t.text,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _SettingsGroup(title: l.settings_sectionGeneral, rows: general),
              const SizedBox(height: 22),
              _SettingsGroup(title: l.settings_sectionAbout, rows: about),
            ],
          ),
        ),
      ),
    );
  }
}

/// Một nhóm cài đặt: tiêu đề nhỏ màu phụ + khối nền trắng bo 22 chứa các dòng.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.tokens.textMuted,
          ),
        ),
      ),
      const SizedBox(height: 8),
      CardSection(radius: 22, children: rows),
    ],
  );
}

/// Một dòng cài đặt: ô icon đỏ nhạt 38 · tiêu đề (+ phụ đề) · mũi tên ›.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.subtitleMaxLines = 1,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final int subtitleMaxLines;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Material trong suốt để hiệu ứng chạm vẽ trên nền trắng của khối (không bị nền che).
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 21, color: t.primaryText),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: t.text,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: subtitleMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: t.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Icon(
                Symbols.chevron_right_rounded,
                size: 22,
                color: t.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
