import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../data/settings/settings_providers.dart';
import 'settings_widgets.dart';

/// Màn Giao diện: Theo máy / Sáng / Tối. Đổi tức thì (app đọc `settings.themeMode`).
class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final current = ref.watch(settingsProvider.select((s) => s.themeMode));
    final notifier = ref.read(settingsProvider.notifier);
    final options = <(ThemeMode, String)>[
      (ThemeMode.system, l.settings_themeSystem),
      (ThemeMode.light, l.settings_themeLight),
      (ThemeMode.dark, l.settings_themeDark),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.settings_theme)),
      body: ListView(
        children: [
          for (final (mode, label) in options)
            ChoiceTile(
              key: ValueKey('theme_${mode.name}'),
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
