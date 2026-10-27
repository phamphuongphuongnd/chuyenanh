import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';

/// Màn Chính sách bảo mật: nội dung tĩnh, app hoạt động ngoại tuyến.
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
        ],
      ),
    );
  }
}
