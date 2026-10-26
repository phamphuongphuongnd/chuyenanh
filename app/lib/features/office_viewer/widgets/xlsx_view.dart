import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:office_reader/office_reader.dart' as rd;
import 'package:path/path.dart' as p;
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../logic/xlsx_grid_layout.dart';
import 'office_common.dart';

const double _headerColWidth = 44;
const double _headerRowHeight = 24;
const Color _gridLine = Color(0xFFD4D4D4);
const Color _headerBg = Color(0xFFEFEFEF);

class XlsxViewerPage extends StatefulWidget {
  const XlsxViewerPage({super.key, required this.path, required this.workbook});

  final String path;
  final rd.XlsxWorkbook workbook;

  @override
  State<XlsxViewerPage> createState() => _XlsxViewerPageState();
}

class _XlsxViewerPageState extends State<XlsxViewerPage> {
  late final List<rd.XlsxSheet> _sheets = () {
    final visible = widget.workbook.sheets.where((s) => !s.hidden).toList();
    return visible.isEmpty ? widget.workbook.sheets : visible;
  }();
  int _index = 0;
  double _zoom = 1;

  void _setZoom(double z) => setState(() => _zoom = z.clamp(0.5, 3.0));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.xls,
        foregroundColor: Colors.white,
        title: Text(p.basename(widget.path), overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: l.office_zoomOut,
            icon: const Icon(Icons.zoom_out),
            onPressed: () => _setZoom(_zoom - 0.25),
          ),
          IconButton(
            tooltip: l.office_zoomIn,
            icon: const Icon(Icons.zoom_in),
            onPressed: () => _setZoom(_zoom + 0.25),
          ),
          IconButton(
            tooltip: l.office_convertToPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () =>
                context.push(Routes.excelToPdf, extra: widget.path),
          ),
        ],
      ),
      body: _sheets.isEmpty
          ? Center(child: Text(l.office_emptySheet))
          : Column(
              children: [
                Expanded(
                  child: PinchZoom(
                    scale: _zoom,
                    min: 0.5,
                    max: 3,
                    onScaleChanged: _setZoom,
                    child: XlsxSheetGrid(
                      key: ValueKey(_index),
                      sheet: _sheets[_index],
                      zoom: _zoom,
                    ),
                  ),
                ),
                _SheetTabs(
                  names: [for (final s in _sheets) s.name],
                  selected: _index,
                  onSelected: (i) => setState(() => _index = i),
                ),
              ],
            ),
    );
  }
}

class _SheetTabs extends StatelessWidget {
  const _SheetTabs({
    required this.names,
    required this.selected,
    required this.onSelected,
  });

  final List<String> names;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: names.length,
            itemBuilder: (context, i) {
              final sel = i == selected;
              return InkWell(
                key: ValueKey('sheetTab$i'),
                onTap: () => onSelected(i),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: sel ? theme.colorScheme.surface : null,
                    border: Border(
                      bottom: BorderSide(
                        color: sel ? AppColors.xls : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(
                    names[i],
                    style: TextStyle(
                      fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                      color: sel ? AppColors.xls : null,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Lưới một sheet (hàng 0 / cột 0 là nhãn A, B, C / 1, 2, 3).
class XlsxSheetGrid extends StatelessWidget {
  const XlsxSheetGrid({super.key, required this.sheet, this.zoom = 1});

  final rd.XlsxSheet sheet;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    if (sheet.maxRow == 0 || sheet.maxCol == 0) {
      return Center(child: Text(context.l10n.office_emptySheet));
    }
    final layout = XlsxGridLayout(sheet);
    return ColoredBox(
      color: Colors.white,
      child: TableView.builder(
        diagonalDragBehavior: DiagonalDragBehavior.free,
        rowCount: layout.rowCount + 1,
        columnCount: layout.colCount + 1,
        pinnedRowCount: layout.pinnedRows + 1,
        pinnedColumnCount: layout.pinnedCols + 1,
        columnBuilder: (c) => TableSpan(
          extent: FixedTableSpanExtent(
            (c == 0 ? _headerColWidth : layout.columnWidth(c - 1)) * zoom,
          ),
        ),
        rowBuilder: (r) => TableSpan(
          extent: FixedTableSpanExtent(
            (r == 0 ? _headerRowHeight : layout.rowHeight(r - 1)) * zoom,
          ),
        ),
        cellBuilder: (context, v) {
          if (v.row == 0 || v.column == 0) {
            final label = v.row == 0 && v.column == 0
                ? ''
                : v.row == 0
                ? columnLabel(v.column - 1)
                : '${v.row}';
            return TableViewCell(child: _HeaderCell(label, zoom));
          }
          final r = v.row - 1, c = v.column - 1;
          final m = layout.mergeAt(r, c);
          final cell = sheet.cell(m?.firstRow ?? r, m?.firstCol ?? c);
          return TableViewCell(
            rowMergeStart: m == null ? null : m.firstRow + 1,
            rowMergeSpan: m?.rowSpan,
            columnMergeStart: m == null ? null : m.firstCol + 1,
            columnMergeSpan: m?.colSpan,
            child: XlsxCellView(cell: cell, zoom: zoom),
          );
        },
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, this.zoom);
  final String label;
  final double zoom;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: _headerBg,
      border: Border(
        right: BorderSide(color: _gridLine),
        bottom: BorderSide(color: _gridLine),
      ),
    ),
    child: Center(
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(
          fontSize: 12 * zoom,
          color: Colors.black54,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  );
}

/// Một ô dữ liệu (luôn vẽ nền sáng, chữ đen giống Excel).
class XlsxCellView extends StatelessWidget {
  const XlsxCellView({super.key, required this.cell, required this.zoom});

  final rd.XlsxCell? cell;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    final cell = this.cell;
    final style = cell?.style ?? rd.XlsxStyle.plain;
    final fill = style.fillArgb != null ? Color(style.fillArgb!) : Colors.white;
    final fontColor = style.fontColorArgb != null
        ? Color(style.fontColorArgb!)
        : contrastOn(fill);
    final border = BorderSide(
      color: style.hasBorder ? Colors.black87 : _gridLine,
      width: style.hasBorder ? 1 : 0.5,
    );

    final decorations = <TextDecoration>[
      if (style.underline) TextDecoration.underline,
      if (style.strike) TextDecoration.lineThrough,
    ];

    final hAlign = switch (style.hAlign) {
      rd.XlsxHAlign.left || rd.XlsxHAlign.justify => Alignment.centerLeft,
      rd.XlsxHAlign.center ||
      rd.XlsxHAlign.centerContinuous => Alignment.center,
      rd.XlsxHAlign.right => Alignment.centerRight,
      _ => switch (cell?.type) {
        rd.XlsxCellType.number || rd.XlsxCellType.date => Alignment.centerRight,
        rd.XlsxCellType.boolean || rd.XlsxCellType.error => Alignment.center,
        _ => Alignment.centerLeft,
      },
    };
    final vy = switch (style.vAlign) {
      rd.XlsxVAlign.top => -1.0,
      rd.XlsxVAlign.center => 0.0,
      _ => 1.0,
    };
    final alignment = Alignment(hAlign.x, vy);

    Widget? text;
    final display = cell?.display ?? '';
    if (display.isNotEmpty) {
      text = Text(
        display,
        softWrap: style.wrap,
        maxLines: style.wrap ? null : 1,
        overflow: TextOverflow.clip,
        textAlign: switch (hAlign.x) {
          < 0 => TextAlign.left,
          > 0 => TextAlign.right,
          _ => TextAlign.center,
        },
        style: TextStyle(
          fontSize: (style.fontSizePt ?? 11) * 4 / 3 * zoom,
          fontWeight: style.bold ? FontWeight.bold : null,
          fontStyle: style.italic ? FontStyle.italic : null,
          color: fontColor,
          decoration: decorations.isEmpty
              ? null
              : TextDecoration.combine(decorations),
          height: 1.1,
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        border: Border(right: border, bottom: border),
      ),
      child: Container(
        alignment: alignment,
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(),
        padding: EdgeInsets.fromLTRB(
          (3 + style.indent * 8) * zoom,
          1 * zoom,
          3 * zoom,
          1 * zoom,
        ),
        child: text,
      ),
    );
  }
}
