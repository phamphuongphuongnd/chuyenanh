// Tiện ích UI dùng chung cho 3 màn của feature `editor`.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path/path.dart' as p;

import '../../core/errors/app_error.dart';
import '../../core/l10n/l10n.dart';
import '../../core/navigation/open_document.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/output_directory.dart';
import '../../core/widgets/widgets.dart';
import 'edited_output.dart';
import 'editor_viewer.dart';

/// Báo lỗi bằng SnackBar theo ngôn ngữ hiện tại.
void showEditorError(BuildContext context, Object error) {
  if (!context.mounted) return;
  final err = error is AppError ? error : AppError.from(error);
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(appErrorMessage(context, err))));
}

/// Hộp thoại "đã lưu file mới": Mở / Đóng.
Future<void> showSavedDialog(BuildContext context, String path) async {
  final l = context.l10n;
  final open = await showDialog<bool>(
    context: context,
    builder: (ctx) => AppDialog(
      title: l.edit_savedTitle,
      content: Text(l.edit_savedMessage(p.basename(path))),
      confirmLabel: l.core_open,
      cancelLabel: l.core_close,
      onConfirm: () => Navigator.of(ctx).pop(true),
      onCancel: () => Navigator.of(ctx).pop(false),
    ),
  );
  if (open != true || !context.mounted) return;
  try {
    await openDocument(context, path);
  } catch (e) {
    if (context.mounted) showEditorError(context, e);
  }
}

/// Lưu tài liệu đang mở trong viewer ra file mới ([kind] quyết định hậu tố tên). Trả về đường dẫn
/// file mới, hoặc `null` nếu lỗi (đã báo cho người dùng).
Future<String?> saveViewerDocument({
  required BuildContext context,
  required WidgetRef ref,
  required EditorViewerArgs viewer,
  required EditKind kind,
  bool flatten = false,
}) async {
  final progress = showProgressDialog(context, cancellable: false);
  try {
    final bytes = await ref.read(editorDocumentSaverProvider)(
      viewer.controller,
      flatten: flatten,
    );
    if (bytes.isEmpty) throw const CorruptFile('empty save');
    final dir = await ref.read(outputDirectoryProvider.future);
    return await writeEditedPdf(dir, viewer.path, kind, bytes);
  } catch (e) {
    progress.close();
    if (context.mounted) showEditorError(context, e);
    return null;
  } finally {
    progress.close();
  }
}

/// Chặn thoát khi còn thay đổi chưa lưu: hỏi xác nhận trước.
class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.hasChanges,
    required this.child,
  });

  final bool hasChanges;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final l = context.l10n;
        final leave = await showConfirmDialog(
          context,
          title: l.edit_unsavedTitle,
          message: l.edit_unsavedMessage,
          confirmLabel: l.edit_discard,
        );
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: child,
    );
  }
}

/// Dải gợi ý dưới AppBar: thẻ bo 16 nền `surface2`, cách mép 12, icon ⓘ màu phụ, chữ 13.
class HintBanner extends StatelessWidget {
  const HintBanner(this.text, {super.key, this.icon = Symbols.info_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: t.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: t.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
