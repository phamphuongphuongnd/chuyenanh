import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/navigation/open_document.dart';
import '../../../core/platform/app_platform.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/doc_type.dart';
import '../../../core/utils/file_format.dart';
import '../../../core/widgets/widgets.dart';
import 'tool_runner.dart';

/// Màu ✓ của màn kết quả (xanh lá như icon XLS).
const _successColor = Color(0xFF43A047);

/// Khung chung của màn công cụ: AppBar sáng theo nền + thân + (tuỳ chọn) thanh nút dưới.
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
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: body),
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: bottom,
              ),
            ),
    );
  }
}

/// Nút chính đỏ đặc cao 52, rộng hết chiều ngang, chữ thường đầu câu; bật thì có bóng đỏ.
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
    final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    final style = FilledButton.styleFrom(
      minimumSize: const Size(64, 52),
      textStyle: const TextStyle(
        fontFamily: kUiFontFamily,
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: onPressed == null ? null : AppShadows.primary,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: icon == null
            ? FilledButton(style: style, onPressed: onPressed, child: text)
            : FilledButton.icon(
                style: style,
                onPressed: onPressed,
                icon: Icon(icon, size: 22),
                label: text,
              ),
      ),
    );
  }
}

/// Nút phụ viền (pill) cao 52, đi cặp với [PrimaryActionButton].
class SecondaryActionButton extends StatelessWidget {
  const SecondaryActionButton({
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
    final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    final style = OutlinedButton.styleFrom(
      minimumSize: const Size(64, 52),
      padding: const EdgeInsets.symmetric(horizontal: 16),
    );
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: icon == null
          ? OutlinedButton(style: style, onPressed: onPressed, child: text)
          : OutlinedButton.icon(
              style: style,
              onPressed: onPressed,
              icon: Icon(icon, size: 22),
              label: text,
            ),
    );
  }
}

/// Khối nền `surface` bo 20, không bóng — nhóm các tuỳ chọn của màn công cụ.
class ToolCard extends StatelessWidget {
  const ToolCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: context.tokens.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

/// Nhãn mục 13 / w700 màu chữ phụ (vd. "Mẫu trang", "Màu").
class ToolSectionLabel extends StatelessWidget {
  const ToolSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: context.tokens.textMuted,
      ),
    ),
  );
}

/// Dòng hướng dẫn ngắn (chữ phụ 13.5, giãn dòng 1.45).
class ToolHintText extends StatelessWidget {
  const ToolHintText(this.text, {super.key, this.color});

  final String text;

  /// Mặc định `textMuted`.
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 13.5,
      height: 1.45,
      fontWeight: FontWeight.w500,
      color: color ?? context.tokens.textMuted,
    ),
  );
}

/// Chip lựa chọn dạng viên cao 36 bo 18: chọn = đỏ chữ trắng, chưa chọn = `surface2`.
class ToolChoiceChip extends StatelessWidget {
  const ToolChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primary : t.surface2,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : t.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hàng chip lựa chọn (tự xuống dòng khi chật).
class ToolChipWrap extends StatelessWidget {
  const ToolChipWrap({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: children);
}

/// Chấm màu tròn 32 (vùng chạm 44); đang chọn có viền 3 màu chữ chính.
class ToolColorDot extends StatelessWidget {
  const ToolColorDot({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: selected,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(color: t.text, width: 3)
                    : Border.all(color: t.lineStrong),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dòng file: biểu tượng loại file · tên (tối đa 2 dòng) · thông tin phụ · (tuỳ chọn) phần đuôi.
/// Không có nền riêng — đặt trong [ToolCard], [CardSection] hoặc khối cha có nền.
class ToolFileRow extends StatelessWidget {
  const ToolFileRow({
    super.key,
    required this.path,
    this.info,
    this.locked = false,
    this.trailing,
    this.onTap,
    this.maxNameLines = 2,
    this.padding = const EdgeInsets.fromLTRB(14, 10, 8, 10),
  });

  final String path;
  final String? info;
  final bool locked;
  final Widget? trailing;
  final VoidCallback? onTap;
  final int maxNameLines;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final row = Padding(
      padding: padding,
      child: Row(
        children: [
          FileTypeIcon.forPath(path, size: 40, locked: locked),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.basename(path),
                  maxLines: maxNameLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: t.text,
                  ),
                ),
                if (info != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    info!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: t.textMuted),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
    if (onTap == null) return row;
    // Material trong suốt: vệt chạm vẽ trên nền của khối cha.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

/// Thẻ file đầu vào (nền `surface` bo 20): biểu tượng, tên, thông tin, nút "Đổi file".
class ToolFileCard extends StatelessWidget {
  const ToolFileCard({
    super.key,
    required this.path,
    this.info,
    this.locked = false,
    this.onChange,
  });

  final String path;
  final String? info;
  final bool locked;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    return ToolCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ToolFileRow(
        path: path,
        info: info,
        locked: locked,
        trailing: onChange == null
            ? null
            : TextButton(
                onPressed: onChange,
                child: Text(context.l10n.tools_changeFile),
              ),
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
    return ToolFileCard(
      path: input.path,
      info: pdfInputInfo(context, input),
      locked: input.password != null,
      onChange: onChange,
    );
  }
}

/// "{n} trang • {dung lượng}" của một PDF đã mở.
String pdfInputInfo(BuildContext context, PdfInput input) {
  final locale = Localizations.localeOf(context).toString();
  return [
    context.l10n.tools_pages(input.pageCount),
    if (input.sizeBytes != null) formatFileSize(input.sizeBytes!, locale),
  ].join(' • ');
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
      illustration: const FileTypeIcon(DocType.pdf, size: 64),
      actionLabel: l.tools_pickPdf,
      onAction: onPick,
    );
  }
}

/// Khung ghi chú nhẹ bo 16 (vd. "mất annotation/form/link"). [warning] = cảnh báo ⚠ nền đỏ nhạt.
class NoteBanner extends StatelessWidget {
  const NoteBanner(this.text, {super.key, this.warning = false});

  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = warning ? t.primaryText : t.textMuted;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: warning ? t.primarySoft : t.surface2,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warning ? Symbols.warning_rounded : Symbols.info_rounded,
            size: 20,
            color: fg,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: warning ? t.text : t.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Màn kết quả dùng chung: ✓ xanh, "Hoàn tất!", các file đã tạo, mở / chia sẻ, xong.
class ToolResultView extends StatelessWidget {
  const ToolResultView({super.key, required this.paths, required this.onDone});

  final List<String> paths;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    final single = paths.length == 1;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            children: [
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: _successColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Symbols.check_rounded,
                    size: 48,
                    weight: 600,
                    color: _successColor,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l.tools_resultDone,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: t.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                single
                    ? l.tools_resultSavedTo(p.dirname(paths.first))
                    : l.tools_resultFiles(paths.length),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.45, color: t.textMuted),
              ),
              const SizedBox(height: 22),
              CardSection(
                children: [
                  for (final path in paths)
                    _ResultTile(path: path, compact: !single),
                ],
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: single
                ? Row(
                    children: [
                      Expanded(
                        child: SecondaryActionButton(
                          label: l.core_share,
                          icon: Symbols.share_rounded,
                          onPressed: () => shareToolFile(context, paths.first),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PrimaryActionButton(
                          label: l.core_open,
                          icon: Symbols.open_in_new_rounded,
                          onPressed: () => openToolFile(context, paths.first),
                        ),
                      ),
                    ],
                  )
                : PrimaryActionButton(label: l.core_done, onPressed: onDone),
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
    return ToolFileRow(
      path: path,
      onTap: () => openToolFile(context, path),
      padding: EdgeInsets.fromLTRB(14, 10, compact ? 4 : 14, 10),
      trailing: compact
          ? IconButton(
              tooltip: l.core_share,
              icon: Icon(Symbols.share_rounded, color: context.tokens.textMuted),
              onPressed: () => shareToolFile(context, path),
            )
          : null,
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

/// Hộp thoại hỏi tên file (ô nhập nền vàng, nút Huỷ viền + nút đỏ). Trả về tên đã nhập hoặc `null`.
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
