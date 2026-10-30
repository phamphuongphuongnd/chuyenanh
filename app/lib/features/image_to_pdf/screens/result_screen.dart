import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/navigation/open_document.dart';
import '../../../core/platform/app_platform.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_format.dart';
import '../../../core/utils/file_paths.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/db/app_database.dart';
import '../services/export_service.dart';
import '../services/output_registry.dart';

/// Màu xanh "thành công" của dấu ✓ (thiết kế: cùng màu icon XLS).
const Color _successColor = Color(0xFF43A047);

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
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(_path)],
          sharePositionOrigin: defaultShareOrigin(),
        ),
      );
    } catch (e) {
      if (mounted) _snack(appErrorMessage(context, AppError.from(e)));
    }
  }

  Future<void> _rename() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) =>
          _RenameDialog(initialName: baseNameWithoutExtension(_path)),
    );
    if (newName == null || !mounted) return;
    final name = normalizePdfName(
      newName,
      fallback: baseNameWithoutExtension(_path),
    );
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
    final t = context.tokens;
    final locale = Localizations.localeOf(context).toString();
    final outcome = widget.outcome;
    final muted = TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w500,
      color: t.textMuted,
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _home();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.img2pdf_resultTitle),
          leading: IconButton(
            icon: const Icon(Symbols.close_rounded),
            tooltip: l.core_close,
            onPressed: _home,
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Center(
              // Máy tính bảng: giữ khối kết quả gọn giữa màn.
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    // Dấu ✓ trong vòng tròn xanh nhạt.
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        color: _successColor.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Symbols.check_rounded,
                        size: 60,
                        weight: 600,
                        color: _successColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Thẻ thông tin file: nền `surface` bo 20, không bóng.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          FileTypeIcon.forPath(_path, size: 56),
                          const SizedBox(height: 14),
                          Text(
                            p.basename(_path),
                            key: const ValueKey('result_name'),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: t.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l.img2pdf_resultInfo(
                              outcome.pageCount,
                              formatFileSize(outcome.sizeBytes, locale),
                            ),
                            textAlign: TextAlign.center,
                            style: muted,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l.img2pdf_resultSavedIn(parentFolderName(_path)),
                            textAlign: TextAlign.center,
                            style: muted.copyWith(fontSize: 13),
                          ),
                          if (outcome.skippedCount > 0) ...[
                            const SizedBox(height: 12),
                            Text(
                              l.img2pdf_skippedImages(outcome.skippedCount),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: t.primaryText,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey('open_button'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: _open,
                        icon: const Icon(Symbols.open_in_new_rounded, size: 20),
                        label: Text(l.core_open),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const ValueKey('share_button'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            onPressed: _share,
                            icon: const Icon(Symbols.share_rounded, size: 20),
                            label: Text(
                              l.core_share,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const ValueKey('rename_button'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            onPressed: _rename,
                            icon: const Icon(Symbols.edit_rounded, size: 20),
                            label: Text(
                              l.core_rename,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const ValueKey('done_button'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(120, 48),
                      ),
                      onPressed: _home,
                      child: Text(l.core_done),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hộp thoại đổi tên: tự giữ và huỷ ô nhập (huỷ sớm sẽ lỗi khi hộp thoại còn đang đóng dần).
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: context.l10n.img2pdf_renameTitle,
      content: AppTextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      onConfirm: () => Navigator.of(context).pop(_controller.text),
    );
  }
}
