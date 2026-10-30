import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/utils/page_size.dart';
import '../../core/widgets/widgets.dart';
import '../../data/settings/settings_providers.dart';
import 'settings_widgets.dart';

/// Tên hiển thị của khổ giấy.
String pageSizeLabel(BuildContext context, PageSizeOption size) {
  final l = context.l10n;
  return switch (size) {
    PageSizeOption.a4 => l.settings_pageSizeA4,
    PageSizeOption.letter => l.settings_pageSizeLetter,
    PageSizeOption.fit => l.settings_pageSizeFit,
  };
}

/// Các lựa chọn khổ giấy. Dùng chung cho bảng chọn và [PageSizeScreen].
List<(PageSizeOption, String, Key)> pageSizeChoices(BuildContext context) => [
  for (final size in PageSizeOption.values)
    (size, pageSizeLabel(context, size), ValueKey('pagesize_${size.name}')),
];

/// Bảng chọn khổ giấy mặc định (mở từ màn Cài đặt). Chọn là lưu và đóng bảng.
Future<void> showPageSizeSheet(BuildContext context, WidgetRef ref) {
  final notifier = ref.read(settingsProvider.notifier);
  return showChoiceSheet<PageSizeOption>(
    context,
    title: context.l10n.settings_pageSize,
    options: pageSizeChoices(context),
    current: ref.read(settingsProvider).defaultPageSize,
    onSelect: notifier.setDefaultPageSize,
  );
}

/// Màn Khổ giấy mặc định (dùng cho Ảnh → PDF, tạo tài liệu trắng, chuyển đổi).
class PageSizeScreen extends ConsumerWidget {
  const PageSizeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final current = ref.watch(
      settingsProvider.select((s) => s.defaultPageSize),
    );
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l.settings_pageSize)),
      body: ChoiceList(
        children: [
          for (final (size, label, key) in pageSizeChoices(context))
            ChoiceTile(
              key: key,
              title: label,
              selected: current == size,
              onTap: () => notifier.setDefaultPageSize(size),
            ),
        ],
      ),
    );
  }
}
