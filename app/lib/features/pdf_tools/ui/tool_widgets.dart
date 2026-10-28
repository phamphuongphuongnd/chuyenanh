import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/navigation/open_document.dart';
import '../../../core/platform/app_platform.dart';
import '../../../core/utils/doc_type.dart';
import '../../../core/utils/file_format.dart';
import '../../../core/widgets/widgets.dart';
import 'tool_runner.dart';

/// Khung chung của màn công cụ: AppBar + thân + (tuỳ chọn) thanh nút dưới.
class ToolScaffold extends StatelessWidget {
  const ToolScaffold({
    super.key,
    required this.title,
    required this.body,
    this.bottom,
  });

  final String title;
  final Widget body;

  /// Nút chính ở đáy màn hình.
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: body),
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: bottom,
              ),
            ),
    );
  }
}

/// Nút chính đỏ đặc, rộng hết chiều ngang.
class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = Text(label.toUpperCase());
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: icon == null
          ? FilledButton(onPressed: onPressed, child: text)
          : FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: text,
            ),
    );
  }
}

/// Thẻ thông tin file đang chọn: biểu tượng, tên, số trang • dung lượng, nút đổi file.
class PdfInputCard extends StatelessWidget {
  const PdfInputCard({super.key, required this.input, this.onChange});

  final PdfInput input;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final info = [
      l.tools_pages(input.pageCount),
      if (input.sizeBytes != null) formatFileSize(input.sizeBytes!, locale),
    ].join(' • ');
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: FileTypeIcon.forPath(input.path, locked: input.password != null),
        title: Text(input.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(info),
        trailing: onChange == null
            ? null
            : TextButton(onPressed: onChange, child: Text(l.tools_changeFile)),
      ),
    );
  }
}

/// Trạng thái chưa chọn file: minh hoạ + nút chọn.
class PickPdfPrompt extends StatelessWidget {
  const PickPdfPrompt({super.key, required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return EmptyState(
      title: l.tools_pickPdfHint,
      illustration: const FileTypeIcon(DocType.pdf, size: 96),
      actionLabel: l.tools_pickPdf,
      onAction: onPick,
    );
  }
}

/// Khung cảnh báo nhẹ (vd. "mất annotation/form/link").
class NoteBanner extends StatelessWidget {
  const NoteBanner(this.text, {super.key, this.icon = Icons.info_outline});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Màn kết quả dùng chung: các file đã tạo, mở / chia sẻ, xong.
class ToolResultView extends StatelessWidget {
  const ToolResultView({super.key, required this.paths, required this.onDone});

  final List<String> paths;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final single = paths.length == 1;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 8),
              const Icon(
                Icons.check_circle,
                size: 72,
                color: Color(0xFF43A047),
              ),
              const SizedBox(height: 12),
              Text(
                l.tools_resultDone,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                single
                    ? l.tools_resultSavedTo(p.dirname(paths.first))
                    : l.tools_resultFiles(paths.length),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 16),
              for (final path in paths)
                _ResultTile(path: path, compact: !single),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                if (single) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => shareToolFile(context, paths.first),
                      icon: const Icon(Icons.share_outlined),
                      label: Text(l.core_share.toUpperCase()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => openToolFile(context, paths.first),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(l.core_open.toUpperCase()),
                    ),
                  ),
                ] else
                  Expanded(
                    child: FilledButton(
                      onPressed: onDone,
                      child: Text(l.core_done.toUpperCase()),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.path, required this.compact});

  final String path;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: FileTypeIcon.forPath(path),
        title: Text(p.basename(path), maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: () => openToolFile(context, path),
        trailing: compact
            ? IconButton(
                tooltip: l.core_share,
                icon: const Icon(Icons.share_outlined),
                onPressed: () => shareToolFile(context, path),
              )
            : null,
      ),
    );
  }
}

/// Mở file kết quả bằng trình đọc của app.
Future<void> openToolFile(BuildContext context, String path) async {
  try {
    await openDocument(context, path);
  } catch (e) {
    if (context.mounted) showToolError(context, e);
  }
}

/// Chia sẻ file kết quả.
Future<void> shareToolFile(BuildContext context, String path) async {
  try {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        sharePositionOrigin: defaultShareOrigin(),
      ),
    );
  } catch (e) {
    if (context.mounted) showToolError(context, AppError.from(e));
  }
}

/// Hộp thoại hỏi tên file (ô nhập nền vàng, CANCEL + nút đỏ). Trả về tên đã nhập hoặc `null`.
Future<String?> showNameDialog(
  BuildContext context, {
  required String title,
  required String initial,
  String? confirmLabel,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _NameDialog(
      title: title,
      initial: initial,
      confirmLabel: confirmLabel,
    ),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.initial,
    this.confirmLabel,
  });

  final String title;
  final String initial;
  final String? confirmLabel;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.title,
      confirmLabel: widget.confirmLabel,
      content: AppTextField(
        controller: _controller,
        autofocus: true,
        hintText: context.l10n.core_fileName,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      onConfirm: _submit,
    );
  }
}
