import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/widgets/widgets.dart';
import 'translate_languages.dart';
import 'translator_engine.dart';

/// Tên ngôn ngữ [code] theo ngôn ngữ app.
String translateLanguageName(BuildContext context, String code) {
  final l = context.l10n;
  return switch (code) {
    'vi' => l.translate_langVi,
    'en' => l.translate_langEn,
    'zh' => l.translate_langZh,
    'ja' => l.translate_langJa,
    'ko' => l.translate_langKo,
    'id' => l.translate_langId,
    _ => code,
  };
}

/// Hiện lỗi đơn giản (một nút OK).
Future<void> showTranslateError(
  BuildContext context, {
  required String title,
  required String message,
}) => showDialog<void>(
  context: context,
  builder: (ctx) => AppDialog(
    title: title,
    content: Text(message),
    showCancel: false,
    onConfirm: () => Navigator.of(ctx).pop(),
  ),
);

/// Đảm bảo gói dịch của mọi ngôn ngữ trong [codes] đã có trên máy: gói nào thiếu thì hỏi
/// "Cần tải gói dịch … (~30 MB)" → tải (tiến độ không xác định). Lỗi mạng → báo rõ, cho thử lại.
/// Trả `true` khi đủ gói; `false` khi người dùng huỷ hoặc tải lỗi.
Future<bool> ensureTranslateModels(
  BuildContext context,
  TranslatorEngine engine,
  Iterable<String> codes,
) async {
  final l = context.l10n;
  final missing = <String>[];
  try {
    for (final code in codes.toSet()) {
      if (!await engine.isModelDownloaded(code)) missing.add(code);
    }
  } catch (_) {
    if (context.mounted) {
      await showTranslateError(
        context,
        title: l.translate_title,
        message: l.translate_checkFailed,
      );
    }
    return false;
  }
  if (missing.isEmpty) return true;
  if (!context.mounted) return false;

  final names = missing
      .map((c) => translateLanguageName(context, c))
      .join(', ');
  final ok = await showConfirmDialog(
    context,
    title: l.translate_downloadTitle,
    message: l.translate_downloadMessage(names, kTranslateModelSizeMb),
    confirmLabel: l.translate_download,
  );
  if (!ok || !context.mounted) return false;

  for (final code in missing) {
    while (true) {
      if (!context.mounted) return false;
      final failed = await _download(context, engine, code);
      if (failed == null) break; // Tải xong gói này.
      if (failed == _Outcome.cancelled || !context.mounted) return false;
      final retry = await showConfirmDialog(
        context,
        title: l.translate_downloadFailedTitle,
        message: l.translate_downloadFailed(
          translateLanguageName(context, code),
        ),
        confirmLabel: l.core_retry,
        cancelLabel: l.core_close,
      );
      if (!retry) return false;
    }
  }
  return true;
}

enum _Outcome { cancelled, failed }

/// Tải một gói, hiện hộp thoại tiến độ không xác định. `null` = thành công.
Future<_Outcome?> _download(
  BuildContext context,
  TranslatorEngine engine,
  String code,
) async {
  final l = context.l10n;
  final ctrl = showProgressDialog(context, title: l.translate_downloading)
    ..update(null, text: translateLanguageName(context, code));
  // ML Kit không huỷ được lượt tải: bấm Huỷ chỉ thôi chờ (gói vẫn có thể tải xong ngầm).
  final cancelled = Completer<void>();
  ctrl.cancelToken.onCancel(() {
    if (!cancelled.isCompleted) cancelled.complete();
  });
  try {
    await Future.any([engine.downloadModel(code), cancelled.future]);
    return ctrl.cancelToken.isCancelled ? _Outcome.cancelled : null;
  } catch (_) {
    return ctrl.cancelToken.isCancelled ? _Outcome.cancelled : _Outcome.failed;
  } finally {
    ctrl.close();
  }
}
