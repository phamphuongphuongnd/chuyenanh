import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/tools/tool_registry.dart';
import '../document_actions.dart';

String _groupLabel(AppLocalizations l, ToolGroup g) => switch (g) {
  ToolGroup.create => l.core_groupCreate,
  ToolGroup.convert => l.core_groupConvert,
  ToolGroup.pdfTools => l.core_groupPdfTools,
  ToolGroup.edit => l.core_groupEdit,
};

/// Các nhóm công cụ (lấy từ `allTools`); [onLaunch] chạy khi chạm một công cụ.
List<Widget> _toolSections(
  BuildContext context,
  void Function(ToolSpec tool) onLaunch,
) {
  final l = context.l10n;
  final theme = Theme.of(context);
  return [
    for (final group in ToolGroup.values) ...[
      Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(
          _groupLabel(l, group),
          style: theme.textTheme.titleSmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      Wrap(
        spacing: 4,
        runSpacing: 8,
        children: [
          for (final tool in allTools.where((t) => t.group == group))
            _ToolCell(tool: tool, onTap: () => onLaunch(tool)),
        ],
      ),
    ],
  ];
}

/// Bottom sheet công cụ mở từ nút giữa thanh điều hướng.
Future<void> showToolsSheet(BuildContext context) {
  final l = context.l10n;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(
            l.docs_toolsTitle,
            style: Theme.of(sheetContext).textTheme.titleLarge,
          ),
          ..._toolSections(context, (tool) {
            Navigator.of(sheetContext).pop();
            launchTool(context, tool);
          }),
        ],
      ),
    ),
  );
}

/// Tab "Công cụ": cùng lưới công cụ nhưng nằm trong trang.
class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.docs_toolsTitle)),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: _toolSections(context, (tool) => launchTool(context, tool)),
    ),
  );
}

class _ToolCell extends StatelessWidget {
  const _ToolCell({required this.tool, required this.onTap});

  final ToolSpec tool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 82,
    child: InkWell(
      key: ValueKey('tool-${tool.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Icon(tool.icon, color: AppColors.primary),
            ),
            const SizedBox(height: 6),
            Text(
              toolLabel(context, tool),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    ),
  );
}
