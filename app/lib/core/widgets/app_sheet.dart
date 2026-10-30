import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Cạnh ngắn tối thiểu để dùng bố cục máy tính bảng.
const double kTabletMinShortestSide = 601;

/// Màn hình đang ở bố cục máy tính bảng? (thanh bên thay thanh dưới, sheet → hộp thoại).
bool isTabletLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide >= kTabletMinShortestSide;

/// Bảng chọn theo thiết kế: điện thoại là bottom sheet có tay kéo (bo 28);
/// máy tính bảng là hộp thoại giữa màn rộng 400.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  if (isTabletLayout(context)) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            child: builder(ctx),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: builder(ctx),
      ),
    ),
  );
}

/// Một dòng trong bảng chọn: (icon) · nhãn · (dấu ✓ tròn đỏ khi đang chọn).
class SheetOption extends StatelessWidget {
  const SheetOption({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.checked = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool checked;

  /// Chữ đỏ (vd. Xoá).
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = danger ? t.primaryText : t.text;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              const SizedBox(width: 14),
              if (icon != null) ...[
                Icon(icon, size: 22, color: color),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
              if (checked)
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Symbols.check_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiêu đề bảng chọn.
class SheetTitle extends StatelessWidget {
  const SheetTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: context.tokens.text,
      ),
    ),
  );
}

/// Bảng chọn một trong nhiều; chọn là đóng. Mỗi lựa chọn có `key` riêng để test.
Future<void> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<(T value, String label, Key key)> options,
  required T current,
  required ValueChanged<T> onSelect,
}) {
  return showAppSheet<void>(
    context,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(title),
        for (final (value, label, key) in options)
          SheetOption(
            key: key,
            label: label,
            checked: value == current,
            onTap: () {
              Navigator.of(ctx).pop();
              onSelect(value);
            },
          ),
      ],
    ),
  );
}

/// Khối nền trắng bo 20 chứa các dòng (danh sách file, mục cài đặt), có kẻ giữa các dòng.
class CardSection extends StatelessWidget {
  const CardSection({super.key, required this.children, this.radius = 20});

  final List<Widget> children;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: t.line),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Một dòng trong danh sách dài dựng lười (`ListView.builder`): tự bo góc dòng đầu/cuối
/// để cả danh sách trông như một [CardSection].
class CardRow extends StatelessWidget {
  const CardRow({
    super.key,
    required this.child,
    required this.first,
    required this.last,
  });

  final Widget child;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const r = Radius.circular(20);
    return Container(
      padding: EdgeInsets.only(top: first ? 4 : 0, bottom: last ? 4 : 0),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.vertical(
          top: first ? r : Radius.zero,
          bottom: last ? r : Radius.zero,
        ),
        border: first ? null : Border(top: BorderSide(color: t.line)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
