import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_theme.dart';
import 'app_logo.dart';
import 'settings_logic.dart';

/// Màn Giới thiệu: logo, tên app, phiên bản, ghi chú ngoại tuyến + Syncfusion Community,
/// nút mở trang giấy phép mã nguồn mở.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    final body = TextStyle(fontSize: 14.5, height: 1.5, color: t.textMuted);
    return Scaffold(
      appBar: AppBar(title: Text(l.settings_about)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Center(child: AppLogo(size: 96)),
          const SizedBox(height: 16),
          Text(
            l.core_appName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: t.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.settings_version(kAppVersion),
            key: const ValueKey('about_version'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: t.textMuted),
          ),
          const SizedBox(height: 12),
          Text(
            l.settings_tagline,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: t.text,
            ),
          ),
          const SizedBox(height: 24),
          Text(l.settings_aboutOffline, style: body),
          const SizedBox(height: 12),
          Text(l.settings_aboutSyncfusion, style: body),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            key: const ValueKey('about_licenses'),
            onPressed: () => showLicensePage(
              context: context,
              applicationName: l.core_appName,
              applicationVersion: kAppVersion,
              applicationIcon: const Padding(
                padding: EdgeInsets.all(8),
                child: AppLogo(size: 48),
              ),
            ),
            icon: const Icon(Symbols.description_rounded),
            label: Text(l.settings_licenses),
          ),
        ],
      ),
    );
  }
}
