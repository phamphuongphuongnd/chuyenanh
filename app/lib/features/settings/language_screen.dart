import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../data/settings/settings_providers.dart';
import 'settings_widgets.dart';

/// Màn chọn ngôn ngữ: "Theo máy" + 6 ngôn ngữ (tên bản địa). Chọn là đổi tức thì.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final current = ref.watch(settingsProvider.select((s) => s.locale));
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l.settings_language)),
      body: ListView(
        children: [
          ChoiceTile(
            key: const ValueKey('lang_system'),
            title: l.settings_languageSystem,
            selected: current == null,
            onTap: () => notifier.setLocale(null),
          ),
          for (final locale in appLocales)
            ChoiceTile(
              key: ValueKey('lang_${locale.languageCode}'),
              title:
                  localeNativeNames[locale.languageCode] ?? locale.languageCode,
              selected: current?.languageCode == locale.languageCode,
              onTap: () => notifier.setLocale(locale),
            ),
        ],
      ),
    );
  }
}
