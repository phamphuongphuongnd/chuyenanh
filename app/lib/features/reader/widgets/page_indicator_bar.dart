import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/widgets.dart';
import '../logic/page_range.dart';

/// Thanh dưới trình đọc: ‹ 3 / 25 › — chạm vào số trang để nhập số cần nhảy tới.
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
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: l.reader_previousPage,
                onPressed: page > 1 ? onPrevious : null,
                icon: const Icon(Icons.chevron_left),
              ),
              InkWell(
                key: const Key('reader_pageIndicator'),
                borderRadius: BorderRadius.circular(8),
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    '$page / $pageCount',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: l.reader_nextPage,
                onPressed: page < pageCount ? onNext : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
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
        errorText: _invalid
            ? l.reader_goToPageInvalid(widget.pageCount)
            : null,
        onChanged: (_) {
          if (_invalid) setState(() => _invalid = false);
        },
        onSubmitted: (_) => _submit(),
      ),
      onConfirm: _submit,
    );
  }
}
