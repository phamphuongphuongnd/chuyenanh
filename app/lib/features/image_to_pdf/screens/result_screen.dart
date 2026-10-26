import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/navigation/open_document.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/file_format.dart';
import '../../../core/utils/file_paths.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/db/app_database.dart';
import '../services/export_service.dart';
import '../services/output_registry.dart';

/// Bước 3: kết quả — Mở / Chia sẻ / Đổi tên.
class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key, required this.outcome});

  final ExportOutcome outcome;

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  late String _path = widget.outcome.outputPath;

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _home() => context.go(Routes.home);

  Future<void> _open() async {
    try {
      await openDocument(context, _path);
    } catch (e) {
      if (mounted) _snack(appErrorMessage(context, AppError.from(e)));
    }
  }

  Future<void> _share() async {
    try {
      await SharePlus.instance.share(ShareParams(files: [XFile(_path)]));
    } catch (e) {
      if (mounted) _snack(appErrorMessage(context, AppError.from(e)));
    }
  }

  Future<void> _rename() async {
    final l = context.l10n;
    final controller = TextEditingController(
      text: baseNameWithoutExtension(_path),
    );
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AppDialog(
        title: l.img2pdf_renameTitle,
        content: AppTextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        onConfirm: () => Navigator.of(ctx).pop(controller.text),
      ),
    );
    controller.dispose();
    if (newName == null || !mounted) return;
    final name = normalizePdfName(newName, fallback: baseNameWithoutExtension(_path));
    try {
      final target = await renameOutputDocument(
        ref.read(appDatabaseProvider),
        _path,
        name,
      );
      if (mounted) setState(() => _path = target);
    } catch (e) {
      if (mounted) _snack(appErrorMessage(context, AppError.from(e)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final outcome = widget.outcome;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _home();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.img2pdf_resultTitle),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: l.core_close,
            onPressed: _home,
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                const Icon(
                  Icons.check_circle,
                  size: 88,
                  color: Color(0xFF43A047),
                ),
                const SizedBox(height: 16),
                FileTypeIcon.forPath(_path, size: 56),
                const SizedBox(height: 12),
                Text(
                  p.basename(_path),
                  key: const ValueKey('result_name'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  l.img2pdf_resultInfo(
                    outcome.pageCount,
                    formatFileSize(outcome.sizeBytes, locale),
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  l.img2pdf_resultSavedIn(parentFolderName(_path)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                if (outcome.skippedCount > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    l.img2pdf_skippedImages(outcome.skippedCount),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('open_button'),
                    onPressed: _open,
                    icon: const Icon(Icons.open_in_new),
                    label: Text(l.core_open.toUpperCase()),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('share_button'),
                        onPressed: _share,
                        icon: const Icon(Icons.share_outlined),
                        label: Text(l.core_share.toUpperCase()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('rename_button'),
                        onPressed: _rename,
                        icon: const Icon(Icons.drive_file_rename_outline),
                        label: Text(l.core_rename.toUpperCase()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextButton(
                  key: const ValueKey('done_button'),
                  onPressed: _home,
                  child: Text(l.core_done.toUpperCase()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
