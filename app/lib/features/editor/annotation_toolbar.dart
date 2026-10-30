import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_theme.dart';

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
  PdfAnnotationMode.highlight => Symbols.ink_highlighter_rounded,
  PdfAnnotationMode.underline => Symbols.format_underlined_rounded,
  PdfAnnotationMode.strikethrough => Symbols.format_strikethrough_rounded,
  PdfAnnotationMode.squiggly => Symbols.waves_rounded,
  PdfAnnotationMode.stickyNote => Symbols.sticky_note_2_rounded,
  PdfAnnotationMode.none => Symbols.pan_tool_alt_rounded,
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

/// Thanh công cụ dưới cùng (nền `surface` bo trên 24, kẻ trên `line`): hàng chấm màu + hàng 5
/// công cụ dạng ô viên dọc. Không giữ trạng thái riêng.
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
    final t = context.tokens;
    return Material(
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: t.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
            SizedBox(
              height: 48,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 10),
              child: Row(
                children: [
                  for (final tool in kAnnotationTools)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
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
                    ),
                ],
              ),
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
    final t = context.tokens;
    // Chấm tròn 30; đang chọn = viền 3 màu chữ chính. Vùng chạm 44×48.
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? t.text : t.lineStrong,
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
    final t = context.tokens;
    final color = active ? t.primaryText : t.textMuted;
    // Ô viên dọc (icon + nhãn); đang chọn = nền `primarySoft`, icon đặc, chữ `primaryText`.
    return Material(
      color: active ? t.primarySoft : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24, fill: active ? 1 : 0),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
