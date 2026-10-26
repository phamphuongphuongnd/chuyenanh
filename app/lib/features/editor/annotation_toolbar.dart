import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../core/l10n/l10n.dart';

/// Màu chọn nhanh cho chú thích.
const List<Color> kAnnotationColors = [
  Color(0xFFFFEB3B), // vàng
  Color(0xFF66BB6A), // xanh lá
  Color(0xFF29B6F6), // xanh dương nhạt
  Color(0xFFF48FB1), // hồng
  Color(0xFFEF5350), // đỏ
  Color(0xFFFFA726), // cam
  Color(0xFF7E57C2), // tím
];

/// Các công cụ chú thích hỗ trợ (theo thứ tự hiển thị).
const List<PdfAnnotationMode> kAnnotationTools = [
  PdfAnnotationMode.highlight,
  PdfAnnotationMode.underline,
  PdfAnnotationMode.strikethrough,
  PdfAnnotationMode.squiggly,
  PdfAnnotationMode.stickyNote,
];

IconData annotationToolIcon(PdfAnnotationMode mode) => switch (mode) {
  PdfAnnotationMode.highlight => Icons.border_color_outlined,
  PdfAnnotationMode.underline => Icons.format_underlined,
  PdfAnnotationMode.strikethrough => Icons.format_strikethrough,
  PdfAnnotationMode.squiggly => Icons.waves,
  PdfAnnotationMode.stickyNote => Icons.sticky_note_2_outlined,
  PdfAnnotationMode.none => Icons.pan_tool_alt_outlined,
};

String annotationToolLabel(BuildContext context, PdfAnnotationMode mode) {
  final l = context.l10n;
  return switch (mode) {
    PdfAnnotationMode.highlight => l.edit_highlight,
    PdfAnnotationMode.underline => l.edit_underline,
    PdfAnnotationMode.strikethrough => l.edit_strikethrough,
    PdfAnnotationMode.squiggly => l.edit_squiggly,
    PdfAnnotationMode.stickyNote => l.edit_stickyNote,
    PdfAnnotationMode.none => '',
  };
}

/// Thanh công cụ dưới cùng: hàng màu + hàng công cụ. Không giữ trạng thái riêng.
class AnnotationToolbar extends StatelessWidget {
  const AnnotationToolbar({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.selectedColor,
    required this.onColorChanged,
  });

  /// Công cụ đang bật (`none` = không công cụ nào).
  final PdfAnnotationMode mode;
  final ValueChanged<PdfAnnotationMode> onModeChanged;

  /// Màu đang chọn; `null` = màu mặc định của từng công cụ.
  final Color? selectedColor;
  final ValueChanged<Color> onColorChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final c in kAnnotationColors)
                    _ColorDot(
                      color: c,
                      selected: selectedColor == c,
                      label: context.l10n.edit_color,
                      onTap: () => onColorChanged(c),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                for (final tool in kAnnotationTools)
                  Expanded(
                    child: _ToolButton(
                      key: Key('tool_${tool.name}'),
                      icon: annotationToolIcon(tool),
                      label: annotationToolLabel(context, tool),
                      active: mode == tool,
                      onTap: () => onModeChanged(
                        mode == tool ? PdfAnnotationMode.none : tool,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.black26,
                width: selected ? 3 : 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = active ? scheme.primary : scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
