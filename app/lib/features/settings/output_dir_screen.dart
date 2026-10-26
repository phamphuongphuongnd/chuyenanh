import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../data/settings/settings_providers.dart';
import 'settings_logic.dart';
import 'settings_providers.dart';

/// Màn Thư mục lưu: hiện thư mục đang dùng, chọn thư mục khác (`file_picker`, có kiểm ghi được)
/// hoặc về mặc định.
class OutputDirScreen extends ConsumerWidget {
  const OutputDirScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final configured = ref.watch(settingsProvider.select((s) => s.outputDir));
    final isDefault = configured == null || configured.isEmpty;
    final theme = Theme.of(context);

    Future<void> choose() async {
      final result = await chooseOutputDirectory(
        ref.read(settingsProvider.notifier),
        ref.read(directoryPickerProvider),
        l.settings_outputDirChoose,
      );
      if (!context.mounted) return;
      if (result == OutputDirResult.notWritable) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(l.settings_outputDirNotWritable)),
          );
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.settings_outputDir)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              key: const ValueKey('output_dir_current'),
              leading: const Icon(Icons.folder_outlined),
              title: Text(
                effectiveOutputDir(configured),
                style: theme.textTheme.bodyLarge,
              ),
              subtitle: isDefault ? Text(l.settings_outputDirDefault) : null,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey('output_dir_choose'),
            onPressed: choose,
            icon: const Icon(Icons.folder_open),
            label: Text(l.settings_outputDirChoose),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('output_dir_reset'),
            onPressed: isDefault
                ? null
                : () => ref.read(settingsProvider.notifier).setOutputDir(null),
            icon: const Icon(Icons.restore),
            label: Text(l.settings_outputDirReset),
          ),
        ],
      ),
    );
  }
}
