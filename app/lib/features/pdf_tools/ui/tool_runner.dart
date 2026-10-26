import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/cancel_token.dart';
import '../../../core/utils/file_paths.dart';
import '../../../core/utils/output_directory.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/db/app_database.dart';
import '../pdf_tools_providers.dart';

/// Một PDF đã chọn và đã mở thử được (đã có mật khẩu nếu cần).
class PdfInput {
  const PdfInput({
    required this.path,
    required this.pageCount,
    this.password,
    this.sizeBytes,
  });

  final String path;
  final int pageCount;

  /// Mật khẩu người dùng đã nhập (null = file không khoá).
  final String? password;
  final int? sizeBytes;

  String get name => p.basename(path);
}

/// Hiện [error] bằng SnackBar (đổi sang [AppError] nếu cần).
void showToolError(BuildContext context, Object error) {
  if (!context.mounted) return;
  final e = AppError.from(error);
  if (e is Cancelled) return;
  showToolMessage(context, appErrorMessage(context, e));
}

void showToolMessage(BuildContext context, String message) {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Mở thử [path] để lấy số trang; file có mật khẩu → hỏi mật khẩu tới khi đúng hoặc người
/// dùng huỷ. Lỗi khác → báo SnackBar. Trả về `null` nếu huỷ / lỗi.
Future<PdfInput?> loadPdfInput(
  BuildContext context,
  WidgetRef ref,
  String path, {
  String? password,
}) async {
  final engine = ref.read(pdfToolsEngineProvider);
  var pw = password;
  while (true) {
    try {
      final count = await engine.pageCount(path, password: pw);
      int? size;
      try {
        size = await File(path).length();
      } catch (_) {}
      return PdfInput(
        path: path,
        pageCount: count,
        password: pw,
        sizeBytes: size,
      );
    } on AppError catch (e) {
      if (e is PasswordRequired || e is WrongPassword) {
        if (!context.mounted) return null;
        pw = await showPasswordDialog(
          context,
          message: context.l10n.core_passwordDialogMessage(p.basename(path)),
          errorText: e is WrongPassword
              ? context.l10n.core_errorWrongPassword
              : null,
        );
        if (pw == null) return null;
        continue;
      }
      if (context.mounted) showToolError(context, e);
      return null;
    } catch (e) {
      if (context.mounted) showToolError(context, e);
      return null;
    }
  }
}

/// Chạy [job] trong hộp thoại tiến độ có nút huỷ. Trả về kết quả, hoặc `null` nếu người dùng
/// huỷ / lỗi (lỗi đã được báo bằng SnackBar).
Future<T?> runToolJob<T>(
  BuildContext context, {
  required Future<T> Function(ProgressCallback onProgress, CancelToken token)
  job,
  String? title,
}) async {
  final ctrl = showProgressDialog(context, title: title);
  try {
    return await job((v) => ctrl.update(v), ctrl.cancelToken);
  } on Cancelled {
    return null;
  } catch (e) {
    ctrl.close();
    if (context.mounted) showToolError(context, e);
    return null;
  } finally {
    ctrl.close();
  }
}

/// Đường dẫn file kết quả không trùng, trong thư mục lưu theo cài đặt.
Future<String> newOutputPath(WidgetRef ref, String baseName) async {
  final dir = await ref.read(outputDirectoryProvider.future);
  return uniqueOutputPath(dir, baseName, 'pdf');
}

/// Thư mục lưu kết quả theo cài đặt.
Future<String> outputDirOf(WidgetRef ref) =>
    ref.read(outputDirectoryProvider.future);

/// Ghi file kết quả vào bảng `documents` để hiện ngay ở trang chủ (không bắt buộc: lỗi bỏ qua).
Future<void> registerOutputs(WidgetRef ref, List<String> paths) async {
  try {
    final dao = ref.read(appDatabaseProvider).documentsDao;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final path in paths) {
      final stat = await File(path).stat();
      await dao.upsert(
        DocumentsCompanion(
          path: Value(path),
          name: Value(p.basename(path)),
          ext: const Value('pdf'),
          size: Value(stat.size),
          modifiedMs: Value(stat.modified.millisecondsSinceEpoch),
          folder: Value(parentFolderName(path)),
          scannedAtMs: Value(now),
        ),
      );
    }
  } catch (_) {
    // bảng documents chỉ là bộ đệm; lần quét sau sẽ thấy file.
  }
}
