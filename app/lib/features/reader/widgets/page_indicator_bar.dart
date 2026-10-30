import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../logic/page_range.dart';

/// Thanh dưới trình đọc: ‹ 3 / 25 › — chạm vào số trang để nhập số cần nhảy tới.
/// Kiểu thiết kế mới: ‹ › là nút tròn nền `surface2`, số trang nằm trong viên `surface2`.
class PageIndicatorBar extends StatelessWidget {
  const PageIndicatorBar({
    super.key,
    required this.page,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
    required this.onJump,
  });

  /// Trang hiện tại, đánh số từ 1.
  final int page;
  final int pageCount;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  /// Người dùng nhập số trang (1..[pageCount]).
  final ValueChanged<int> onJump;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    const pill = StadiumBorder();
    // Nền surface, kẻ mảnh phía trên (không đổ bóng — nhẹ cho máy yếu).
    return Material(
      color: t.surface,
      shape: Border(top: BorderSide(color: t.line)),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RoundNavButton(
                tooltip: l.reader_previousPage,
                icon: Symbols.chevron_left_rounded,
                onPressed: page > 1 ? onPrevious : null,
              ),
              const SizedBox(width: 12),
              // Viên số trang: chạm để mở hộp thoại "Đến trang".
              Material(
                color: t.surface2,
                shape: pill,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const Key('reader_pageIndicator'),
                  customBorder: pill,
                  onTap: pageCount <= 0
                      ? null
                      : () async {
                          final target = await showGoToPageDialog(
                            context,
                            pageCount: pageCount,
                            current: page,
                          );
                          if (target != null) onJump(target);
                        },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 88),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      child: Text(
                        '$page / $pageCount',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: t.text,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _RoundNavButton(
                tooltip: l.reader_nextPage,
                icon: Symbols.chevron_right_rounded,
                onPressed: page < pageCount ? onNext : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nút tròn 40 nền `surface2` (‹ / ›). Vùng chạm vẫn 48 theo `materialTapTargetSize`.
class _RoundNavButton extends StatelessWidget {
  const _RoundNavButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 24),
      style: IconButton.styleFrom(
        fixedSize: const Size(40, 40),
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
        backgroundColor: t.surface2,
        disabledBackgroundColor: t.surface2.withValues(alpha: 0.5),
        foregroundColor: t.text,
        disabledForegroundColor: t.textMuted.withValues(alpha: 0.45),
      ),
    );
  }
}

/// Hộp thoại nhập số trang. Trả về số trang hợp lệ (1..[pageCount]) hoặc null nếu huỷ.
Future<int?> showGoToPageDialog(
  BuildContext context, {
  required int pageCount,
  required int current,
}) {
  return showDialog<int>(
    context: context,
    builder: (ctx) => _GoToPageDialog(pageCount: pageCount, current: current),
  );
}

class _GoToPageDialog extends StatefulWidget {
  const _GoToPageDialog({required this.pageCount, required this.current});

  final int pageCount;
  final int current;

  @override
  State<_GoToPageDialog> createState() => _GoToPageDialogState();
}

class _GoToPageDialogState extends State<_GoToPageDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.current}',
  );
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final n = parseJumpPage(_controller.text, widget.pageCount);
    if (n == null) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(n);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppDialog(
      title: l.reader_goToPage,
      content: AppTextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.go,
        hintText: l.reader_goToPageHint(widget.pageCount),
        errorText: _invalid ? l.reader_goToPageInvalid(widget.pageCount) : null,
        onChanged: (_) {
          if (_invalid) setState(() => _invalid = false);
        },
        onSubmitted: (_) => _submit(),
      ),
      onConfirm: _submit,
    );
  }
}
