import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class SpanTableParentData extends ContainerBoxParentData<RenderBox> {
  int row = 0;
  int col = 0;
  int rowSpan = 1;
  int colSpan = 1;
}

/// Gắn vị trí ô trong lưới cho [SpanTable].
class SpanTableCell extends ParentDataWidget<SpanTableParentData> {
  const SpanTableCell({
    super.key,
    required this.row,
    required this.col,
    this.rowSpan = 1,
    this.colSpan = 1,
    required super.child,
  });

  final int row;
  final int col;
  final int rowSpan;
  final int colSpan;

  @override
  void applyParentData(RenderObject renderObject) {
    final pd = renderObject.parentData! as SpanTableParentData;
    var dirty = false;
    if (pd.row != row) {
      pd.row = row;
      dirty = true;
    }
    if (pd.col != col) {
      pd.col = col;
      dirty = true;
    }
    if (pd.rowSpan != rowSpan) {
      pd.rowSpan = rowSpan;
      dirty = true;
    }
    if (pd.colSpan != colSpan) {
      pd.colSpan = colSpan;
      dirty = true;
    }
    if (dirty) renderObject.parent?.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => SpanTable;
}

/// Bảng có ô gộp (cả ngang và dọc). Chiều rộng cột cho trước ([columnWidths]); nếu tổng
/// vượt chiều rộng cho phép thì co đều lại. Chiều cao hàng theo nội dung ô (và [minRowHeights]).
class SpanTable extends MultiChildRenderObjectWidget {
  const SpanTable({
    super.key,
    required this.columnWidths,
    required this.rowCount,
    this.minRowHeights = const [],
    super.children,
  });

  final List<double> columnWidths;
  final int rowCount;
  final List<double> minRowHeights;

  @override
  RenderSpanTable createRenderObject(BuildContext context) =>
      RenderSpanTable(columnWidths, rowCount, minRowHeights);

  @override
  void updateRenderObject(BuildContext context, RenderSpanTable renderObject) {
    renderObject
      ..columnWidths = columnWidths
      ..rowCount = rowCount
      ..minRowHeights = minRowHeights;
  }
}

class RenderSpanTable extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, SpanTableParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, SpanTableParentData> {
  RenderSpanTable(this._columnWidths, this._rowCount, this._minRowHeights);

  List<double> _columnWidths;
  int _rowCount;
  List<double> _minRowHeights;

  set columnWidths(List<double> v) {
    _columnWidths = v;
    markNeedsLayout();
  }

  set rowCount(int v) {
    if (_rowCount == v) return;
    _rowCount = v;
    markNeedsLayout();
  }

  set minRowHeights(List<double> v) {
    _minRowHeights = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! SpanTableParentData) {
      child.parentData = SpanTableParentData();
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.constrain(Size(_fitWidths(constraints.maxWidth).total, 0));

  ({List<double> widths, double total}) _fitWidths(double maxWidth) {
    var total = _columnWidths.fold<double>(0, (a, b) => a + b);
    var widths = _columnWidths;
    if (total > maxWidth && maxWidth.isFinite && total > 0) {
      final f = maxWidth / total;
      widths = [for (final w in _columnWidths) w * f];
      total = maxWidth;
    }
    return (widths: widths, total: total);
  }

  @override
  void performLayout() {
    final fit = _fitWidths(constraints.maxWidth);
    final widths = fit.widths;
    final colX = <double>[0];
    for (final w in widths) {
      colX.add(colX.last + w);
    }
    double spanWidth(int col, int span) {
      final end = math.min(col + span, widths.length);
      final start = math.min(col, widths.length);
      return colX[end] - colX[start];
    }

    final rows = math.max(_rowCount, 1);
    final rowH = List<double>.generate(
      rows,
      (i) => i < _minRowHeights.length ? _minRowHeights[i] : 0,
    );

    final kids = <RenderBox>[];
    var child = firstChild;
    while (child != null) {
      kids.add(child);
      child = (child.parentData! as SpanTableParentData).nextSibling;
    }

    final natural = <RenderBox, double>{};
    for (final k in kids) {
      final pd = k.parentData! as SpanTableParentData;
      final w = spanWidth(pd.col, pd.colSpan);
      k.layout(BoxConstraints(minWidth: w, maxWidth: w), parentUsesSize: true);
      natural[k] = k.size.height;
    }
    for (final k in kids) {
      final pd = k.parentData! as SpanTableParentData;
      if (pd.rowSpan == 1 && pd.row < rows) {
        rowH[pd.row] = math.max(rowH[pd.row], natural[k]!);
      }
    }
    for (final k in kids) {
      final pd = k.parentData! as SpanTableParentData;
      if (pd.rowSpan > 1 && pd.row < rows) {
        final last = math.min(pd.row + pd.rowSpan, rows) - 1;
        var sum = 0.0;
        for (var r = pd.row; r <= last; r++) {
          sum += rowH[r];
        }
        if (natural[k]! > sum) rowH[last] += natural[k]! - sum;
      }
    }
    final rowY = <double>[0];
    for (final h in rowH) {
      rowY.add(rowY.last + h);
    }
    for (final k in kids) {
      final pd = k.parentData! as SpanTableParentData;
      if (pd.row >= rows) {
        k.layout(const BoxConstraints.tightFor(width: 0, height: 0));
        continue;
      }
      final end = math.min(pd.row + pd.rowSpan, rows);
      final h = rowY[end] - rowY[pd.row];
      final w = spanWidth(pd.col, pd.colSpan);
      k.layout(BoxConstraints.tightFor(width: w, height: h));
      pd.offset = Offset(colX[math.min(pd.col, widths.length)], rowY[pd.row]);
    }
    size = constraints.constrain(Size(fit.total, rowY.last));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
