import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/tools/tool_registry.dart';
import '../../../core/widgets/widgets.dart';
import '../document_actions.dart';

String _groupLabel(AppLocalizations l, ToolGroup g) => switch (g) {
  ToolGroup.create => l.core_groupCreate,
  ToolGroup.convert => l.core_groupConvert,
  ToolGroup.pdfTools => l.core_groupPdfTools,
  ToolGroup.edit => l.core_groupEdit,
};

/// Màu nhận diện từng công cụ (thiết kế `PdfOfficeApp.dc.html`, mảng `groups`).
/// Mặc định đỏ thương hiệu.
Color _toolColor(ToolSpec tool) => switch (tool.id) {
  'wordToPdf' || 'pdfToWord' => AppColors.doc,
  'excelToPdf' || 'pdfToExcel' => AppColors.xls,
  'pdfToImage' => AppColors.image,
  'pdfToText' => const Color(0xFF546E7A),
  _ => AppColors.primary,
};

/// Bề rộng ước lượng một ô công cụ ở bố cục máy tính bảng (để tính số cột).
const double _kTabletCellWidth = 100;

/// Các nhóm công cụ (lấy từ `allTools`); [onLaunch] chạy khi chạm một công cụ.
List<Widget> _toolSections(
  BuildContext context,
  void Function(ToolSpec tool) onLaunch,
) {
  final l = context.l10n;
  final tokens = context.tokens;
  return [
    for (final group in ToolGroup.values)
      Builder(
        builder: (context) {
          final tools = [...allTools.where((t) => t.group == group)];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              // Hàng tiêu đề: tên nhóm · đường kẻ · số công cụ.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  spacing: 8,
                  children: [
                    Text(
                      _groupLabel(l, group),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: tokens.primaryText,
                      ),
                    ),
                    Expanded(child: Container(height: 1, color: tokens.line)),
                    Text(
                      '${tools.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _ToolGrid(tools: tools, onLaunch: onLaunch),
            ],
          );
        },
      ),
  ];
}

/// Khối nền surface bo 22 chứa lưới công cụ: điện thoại 4 cột,
/// máy tính bảng tự tính số cột theo bề rộng (ô ~100).
class _ToolGrid extends StatelessWidget {
  const _ToolGrid({required this.tools, required this.onLaunch});

  final List<ToolSpec> tools;
  final void Function(ToolSpec tool) onLaunch;

  @override
  Widget build(BuildContext context) {
    final tablet = isTabletLayout(context);
    // Material (không dùng Container màu) để hiệu ứng chạm của ô hiện trên nền khối.
    return Material(
      color: context.tokens.surface,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            var cols = 4;
            if (tablet && constraints.maxWidth.isFinite) {
              cols = (constraints.maxWidth / _kTabletCellWidth).floor();
              if (cols < 4) cols = 4;
            }
            return Column(
              spacing: 4,
              children: [
                for (var i = 0; i < tools.length; i += cols)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      for (var j = i; j < i + cols; j++)
                        Expanded(
                          child: j < tools.length
                              ? _ToolCell(
                                  tool: tools[j],
                                  onTap: () => onLaunch(tools[j]),
                                )
                              : const SizedBox.shrink(),
                        ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Bottom sheet công cụ mở từ nút giữa thanh điều hướng (dùng chung lưới với tab).
Future<void> showToolsSheet(BuildContext context) {
  final l = context.l10n;
  final tokens = context.tokens;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: tokens.bg,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              l.docs_toolsTitle,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 22 * -0.02,
                color: tokens.text,
              ),
            ),
          ),
          for (final section in _toolSections(context, (tool) {
            Navigator.of(sheetContext).pop();
            launchTool(context, tool);
          })) ...[const SizedBox(height: 22), section],
        ],
      ),
    ),
  );
}

/// Tab "Công cụ": không AppBar, tiêu đề lớn + các nhóm công cụ.
class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tablet = isTabletLayout(context);
    final hPad = tablet ? 32.0 : 16.0;
    final gap = tablet ? 26.0 : 22.0;
    final sections = _toolSections(context, (tool) => launchTool(context, tool));
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Icon thanh trạng thái: tối trên nền sáng, sáng trên nền tối.
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: tokens.bg,
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(hPad, tablet ? 32 : 16, hPad, 28),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  context.l10n.docs_toolsTitle,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 30 * -0.02,
                    height: 1.2,
                    color: tokens.text,
                  ),
                ),
              ),
              for (final section in sections) ...[
                SizedBox(height: gap),
                section,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolCell extends StatelessWidget {
  const _ToolCell({required this.tool, required this.onTap});

  final ToolSpec tool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = _toolColor(tool);
    return InkWell(
      key: ValueKey('tool-${tool.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: dark ? 0.2 : 0.11),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                tool.icon,
                size: 24,
                color: dark ? Colors.white : color,
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 31),
              child: Text(
                toolLabel(context, tool),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                  color: tokens.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
