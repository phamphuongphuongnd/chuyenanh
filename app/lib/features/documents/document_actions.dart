import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../core/errors/app_error.dart';
import '../../core/l10n/l10n.dart';
import '../../core/tools/tool_registry.dart';
import '../../core/navigation/open_document.dart';
import '../../core/utils/doc_type.dart';
import '../../core/utils/file_format.dart';
import '../../core/utils/file_paths.dart';
import '../../core/widgets/widgets.dart';
import '../../data/db/app_database.dart';
import 'documents_logic.dart';

/// Mở [path] bằng viewer phù hợp; lỗi hiện SnackBar thay vì ném ra UI.
Future<void> openDocumentWithFeedback(BuildContext context, String path) async {
  final messenger = ScaffoldMessenger.of(context);
  final l = context.l10n;
  try {
    await openDocument(context, path);
  } catch (e) {
    final err = AppError.from(e);
    final text = err is CorruptFile ? l.docs_fileMissing : null;
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(text ?? appErrorMessage(context, err))),
    );
  }
}

/// Chế độ chọn file (khi chưa có quyền quét): chọn một tài liệu rồi mở.
Future<void> pickAndOpenDocument(BuildContext context) async {
  final picked = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: documentExtensions.toList(),
  );
  final path = picked?.path;
  if (path == null || !context.mounted) return;
  await openDocumentWithFeedback(context, path);
}

/// Chia sẻ file qua hộp thoại chia sẻ của hệ thống.
Future<void> shareDocument(DocItem item) =>
    SharePlus.instance.share(ShareParams(files: [XFile(item.path)]));

/// Hộp thoại Thông tin file.
Future<void> showDocumentInfo(BuildContext context, DocItem item) {
  final l = context.l10n;
  final locale = Localizations.localeOf(context).toString();
  Widget row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
  return showDialog<void>(
    context: context,
    builder: (ctx) => AppDialog(
      title: l.core_info,
      showCancel: false,
      onConfirm: () => Navigator.of(ctx).pop(),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row(l.docs_infoName, item.name),
          row(l.docs_infoPath, item.path),
          row(l.docs_infoSize, formatFileSize(item.size, locale)),
          row(l.docs_infoModified, formatDateTime(item.modified, locale)),
        ],
      ),
    ),
  );
}

/// Hộp thoại đổi tên; thành công → đổi file thật + cập nhật mọi bảng DB.
Future<void> renameDocument(
  BuildContext context,
  WidgetRef ref,
  DocItem item,
) async {
  final l = context.l10n;
  final controller = TextEditingController(
    text: p.basenameWithoutExtension(item.path),
  );
  final newBase = await showDialog<String>(
    context: context,
    builder: (ctx) {
      String? error;
      return StatefulBuilder(
        builder: (ctx, setState) => AppDialog(
          title: l.docs_renameTitle,
          content: AppTextField(
            controller: controller,
            autofocus: true,
            errorText: error,
            textInputAction: TextInputAction.done,
          ),
          onConfirm: () {
            final problem = validateRename(
              oldPath: item.path,
              newBaseName: controller.text,
              exists: (path) => File(path).existsSync(),
            );
            if (problem == null) {
              Navigator.of(ctx).pop(controller.text);
              return;
            }
            setState(
              () => error = switch (problem) {
                RenameProblem.empty => l.docs_renameEmpty,
                RenameProblem.exists => l.docs_renameExists,
              },
            );
          },
        ),
      );
    },
  );
  controller.dispose();
  if (newBase == null) return;
  final target = renameTarget(item.path, newBase.trim());
  if (p.equals(target, item.path)) return;
  try {
    await File(item.path).rename(target);
    await ref
        .read(appDatabaseProvider)
        .renamePath(
          item.path,
          target,
          newName: p.basename(target),
          newFolder: parentFolderName(target),
        );
  } on FileSystemException catch (e) {
    if (!context.mounted) return;
    final err = AppError.from(e);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          err is Unknown ? l.docs_renameFailed : appErrorMessage(context, err),
        ),
      ),
    );
  }
}

/// Hỏi xác nhận rồi xoá file thật + bỏ khỏi DB.
Future<void> deleteDocument(
  BuildContext context,
  WidgetRef ref,
  DocItem item,
) async {
  final l = context.l10n;
  final ok = await showConfirmDialog(
    context,
    title: l.core_confirmDeleteTitle,
    message: l.core_confirmDeleteMessage(item.name),
    confirmLabel: l.core_delete,
  );
  if (!ok || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final file = File(item.path);
    if (await file.exists()) await file.delete();
    await ref.read(appDatabaseProvider).forgetPath(item.path);
    messenger.showSnackBar(SnackBar(content: Text(l.docs_deleted(item.name))));
  } on FileSystemException catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(appErrorMessage(context, AppError.from(e)))),
    );
  }
}

/// Mở công cụ [tool]. Công cụ bắt buộc có PDF (`pdfRequired`) thì chọn PDF trước.
Future<void> launchTool(BuildContext context, ToolSpec tool) async {
  if (tool.inputType == ToolInputType.pdfRequired) {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final path = picked?.path;
    if (path == null || !context.mounted) return;
    await context.push(tool.route, extra: path);
    return;
  }
  await context.push(tool.route);
}
