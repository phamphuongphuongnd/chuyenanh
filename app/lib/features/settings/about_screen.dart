import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import 'app_logo.dart';
import 'settings_logic.dart';

/// Màn Giới thiệu: logo, tên app, phiên bản, ghi chú ngoại tuyến + Syncfusion Community,
/// nút mở trang giấy phép mã nguồn mở.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
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
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            l.settings_version(kAppVersion),
            key: const ValueKey('about_version'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            l.settings_tagline,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Text(l.settings_aboutOffline, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Text(l.settings_aboutSyncfusion, style: theme.textTheme.bodyMedium),
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
            icon: const Icon(Icons.description_outlined),
            label: Text(l.settings_licenses),
          ),
        ],
      ),
    );
  }
}
