import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/widgets/widgets.dart';
import '../../data/settings/settings_providers.dart';
import 'settings_widgets.dart';

/// Các lựa chọn giao diện: Theo máy / Sáng / Tối. Dùng chung cho bảng chọn và [ThemeScreen].
List<(ThemeMode, String, Key)> themeChoices(BuildContext context) => [
  for (final mode in [ThemeMode.system, ThemeMode.light, ThemeMode.dark])
    (mode, themeModeLabel(context, mode), ValueKey('theme_${mode.name}')),
];

/// Bảng chọn giao diện (mở từ màn Cài đặt). Chọn là đổi tức thì và đóng bảng.
Future<void> showThemeSheet(BuildContext context, WidgetRef ref) {
  final notifier = ref.read(settingsProvider.notifier);
  return showChoiceSheet<ThemeMode>(
    context,
    title: context.l10n.settings_theme,
    options: themeChoices(context),
    current: ref.read(settingsProvider).themeMode,
    onSelect: notifier.setThemeMode,
  );
}

/// Màn Giao diện: Theo máy / Sáng / Tối. Đổi tức thì (app đọc `settings.themeMode`).
class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final current = ref.watch(settingsProvider.select((s) => s.themeMode));
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l.settings_theme)),
      body: ChoiceList(
        children: [
          for (final (mode, label, key) in themeChoices(context))
            ChoiceTile(
              key: key,
              title: label,
              selected: current == mode,
              onTap: () => notifier.setThemeMode(mode),
            ),
        ],
      ),
    );
  }
}

/// Tên hiển thị của [mode] (dùng làm phụ đề ở màn Cài đặt).
String themeModeLabel(BuildContext context, ThemeMode mode) {
  final l = context.l10n;
  return switch (mode) {
    ThemeMode.system => l.settings_themeSystem,
    ThemeMode.light => l.settings_themeLight,
    ThemeMode.dark => l.settings_themeDark,
  };
}
