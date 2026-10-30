import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/widgets/widgets.dart';
import '../../data/settings/settings_providers.dart';
import 'settings_widgets.dart';

/// Các lựa chọn ngôn ngữ: `null` = "Theo máy", còn lại là mã ngôn ngữ trong [appLocales]
/// (nhãn là tên bản địa). Dùng chung cho bảng chọn và [LanguageScreen].
List<(String?, String, Key)> languageChoices(BuildContext context) => [
  (null, context.l10n.settings_languageSystem, const ValueKey('lang_system')),
  for (final locale in appLocales)
    (
      locale.languageCode,
      localeNativeNames[locale.languageCode] ?? locale.languageCode,
      ValueKey('lang_${locale.languageCode}'),
    ),
];

/// Locale ứng với mã [code] (`null` = theo máy).
Locale? _localeOf(String? code) => code == null
    ? null
    : appLocales.firstWhere(
        (l) => l.languageCode == code,
        orElse: () => Locale(code),
      );

/// Bảng chọn ngôn ngữ (mở từ màn Cài đặt). Chọn là đổi tức thì và đóng bảng.
Future<void> showLanguageSheet(BuildContext context, WidgetRef ref) {
  final notifier = ref.read(settingsProvider.notifier);
  return showChoiceSheet<String?>(
    context,
    title: context.l10n.settings_language,
    options: languageChoices(context),
    current: ref.read(settingsProvider).locale?.languageCode,
    onSelect: (code) => notifier.setLocale(_localeOf(code)),
  );
}

/// Màn chọn ngôn ngữ (route `/settings/language`): "Theo máy" + 6 ngôn ngữ (tên bản địa).
/// Chọn là đổi tức thì.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final current = ref.watch(
      settingsProvider.select((s) => s.locale?.languageCode),
    );
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l.settings_language)),
      body: ChoiceList(
        children: [
          for (final (code, label, key) in languageChoices(context))
            ChoiceTile(
              key: key,
              title: label,
              selected: current == code,
              onTap: () => notifier.setLocale(_localeOf(code)),
            ),
        ],
      ),
    );
  }
}
