import 'package:flutter/material.dart';

/// Dòng chọn một trong nhiều (Ngôn ngữ, Giao diện, Khổ giấy): dấu tích ở mục đang chọn.
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
    final primary = Theme.of(context).colorScheme.primary;
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: selected ? Icon(Icons.check, color: primary) : null,
      selected: selected,
      onTap: onTap,
    );
  }
}
