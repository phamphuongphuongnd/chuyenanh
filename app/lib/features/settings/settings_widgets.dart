import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';

/// Dòng chọn một trong nhiều (Ngôn ngữ, Giao diện, Khổ giấy) ở các màn chọn riêng,
/// cùng kiểu với `SheetOption` của bảng chọn: nhãn · dấu ✓ tròn đỏ 26 ở mục đang chọn.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w500,
                            color: t.text,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: t.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 12),
                    const ChoiceCheckMark(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dấu ✓ trắng trong vòng tròn đỏ 26 (mục đang chọn).
class ChoiceCheckMark extends StatelessWidget {
  const ChoiceCheckMark({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 26,
    height: 26,
    decoration: const BoxDecoration(
      color: AppColors.primary,
      shape: BoxShape.circle,
    ),
    child: const Icon(Symbols.check_rounded, size: 18, color: Colors.white),
  );
}

/// Thân chung của các màn chọn: danh sách nằm trong một khối nền trắng bo 22.
class ChoiceList extends StatelessWidget {
  const ChoiceList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
    children: [CardSection(radius: 22, children: children)],
  );
}
