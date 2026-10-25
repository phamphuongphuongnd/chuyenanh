import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../utils/cancel_token.dart';
import 'app_dialog.dart';
import 'app_text_field.dart';

/// Hỏi xác nhận. `true` = đồng ý, `false`/đóng = không.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AppDialog(
      title: title,
      content: Text(message),
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      onConfirm: () => Navigator.of(ctx).pop(true),
      onCancel: () => Navigator.of(ctx).pop(false),
    ),
  );
  return result ?? false;
}

/// Hỏi mật khẩu. Trả về chuỗi đã nhập (không rỗng) hoặc `null` nếu huỷ.
/// [errorText] hiện dưới ô nhập (vd. sau lần nhập sai).
Future<String?> showPasswordDialog(
  BuildContext context, {
  String? title,
  String? message,
  String? errorText,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _PasswordDialog(
      title: title ?? ctx.l10n.core_passwordDialogTitle,
      message: message,
      errorText: errorText,
    ),
  );
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.title, this.message, this.errorText});

  final String title;
  final String? message;
  final String? errorText;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text;
    if (text.isEmpty) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message != null) ...[
            Text(widget.message!),
            const SizedBox(height: 12),
          ],
          AppTextField(
            controller: _controller,
            autofocus: true,
            obscureText: _obscure,
            hintText: context.l10n.core_password,
            errorText: widget.errorText,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ],
      ),
      onConfirm: _submit,
    );
  }
}

/// Điều khiển hộp thoại tiến độ: cập nhật % bằng [update], đóng bằng [close].
class ProgressDialogController {
  ProgressDialogController._(this._context, this.cancelToken);

  final BuildContext _context;
  final CancelToken cancelToken;
  final ValueNotifier<double?> progress = ValueNotifier<double?>(null);
  final ValueNotifier<String?> message = ValueNotifier<String?>(null);
  bool _closed = false;

  /// [value] 0.0 → 1.0 (null = chạy vô định).
  void update(double? value, {String? text}) {
    if (_closed) return;
    progress.value = value?.clamp(0.0, 1.0);
    if (text != null) message.value = text;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    if (_context.mounted) Navigator.of(_context, rootNavigator: true).pop();
  }
}

/// Hiện hộp thoại tiến độ (% + nút huỷ). Nút huỷ gọi `cancelToken.cancel()` và đóng hộp thoại.
///
/// ```dart
/// final ctrl = showProgressDialog(context, title: l.core_processing);
/// try { await engine.run(onProgress: ctrl.update, cancelToken: ctrl.cancelToken); }
/// finally { ctrl.close(); }
/// ```
ProgressDialogController showProgressDialog(
  BuildContext context, {
  String? title,
  CancelToken? cancelToken,
  bool cancellable = true,
}) {
  final token = cancelToken ?? CancelToken();
  final navigator = Navigator.of(context, rootNavigator: true);
  final ctrl = ProgressDialogController._(navigator.context, token);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(title ?? ctx.l10n.core_processing),
          content: ValueListenableBuilder<double?>(
            valueListenable: ctrl.progress,
            builder: (ctx, value, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<String?>(
                  valueListenable: ctrl.message,
                  builder: (_, msg, _) =>
                      msg == null ? const SizedBox.shrink() : Text(msg),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: value),
                const SizedBox(height: 8),
                if (value != null)
                  Text(ctx.l10n.core_progressPercent((value * 100).round())),
              ],
            ),
          ),
          actions: [
            if (cancellable)
              OutlinedButton(
                onPressed: () {
                  token.cancel();
                  ctrl.close();
                },
                child: Text(ctx.l10n.core_cancel.toUpperCase()),
              ),
          ],
        ),
      ),
    ),
  );
  return ctrl;
}
