import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/l10n/l10n.dart';
import '../../core/utils/link_opener.dart';
import 'settings_logic.dart';

/// Màn Chính sách bảo mật: tóm tắt ngắn trong app + nút mở bản đầy đủ công khai
/// ([kPrivacyPolicyUrl]). Hai bản phải nói cùng một nội dung.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.settings_privacy)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            l.settings_privacyBody,
            key: const ValueKey('privacy_body'),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            key: const ValueKey('privacy_fullPolicy'),
            onPressed: () => openSettingsLink(context, kPrivacyPolicyUrl),
            icon: const Icon(Symbols.open_in_new_rounded),
            label: Text(l.settings_privacyFull),
          ),
        ],
      ),
    );
  }
}

/// Mở [url] (link do chính app khai báo) bằng trình duyệt ngoài; không mở được thì báo SnackBar.
Future<void> openSettingsLink(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  final failed = context.l10n.settings_linkOpenFailed;
  final res = await openLink(linkLauncherOf(context), url);
  if (!res.opened) {
    messenger.showSnackBar(SnackBar(content: Text(failed)));
  }
}
