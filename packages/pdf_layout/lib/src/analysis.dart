/// Page analysis shared by [rebuildDocument] and [detectSheets]:
/// running header/footer removal, splitting lines into text runs, two-column
/// detection, row grouping and table detection.
library;

import 'dart:math' as math;

import 'package:collection/collection.dart';

import 'model.dart';
import 'options.dart';
import 'text_utils.dart';

/// A run of words of one source line without large gaps (a cell or a column
/// fragment of the line).
class Seg {
  final LayoutLine line;

  /// Number of segments the source line was split into.
  final int lineSegCount;

  /// Words of the run; empty when the line had no word information.
  final List<LayoutWord> words;
  final double left, top, right, bottom, fontSize;
  final bool bold;

  Seg._(
    this.line,
    this.lineSegCount,
    this.words,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.fontSize,
    this.bold,
  );

  double get height => math.max(bottom - top, 0.1);
  double get width => right - left;
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;

  bool get isWholeLine => lineSegCount == 1;

  String get text =>
      (isWholeLine || words.isEmpty) && line.text.trim().isNotEmpty
      ? line.text.trim()
      : joinWords(words);
}

double _fontSizeOf(LayoutLine line) => line.fontSize > 0
    ? line.fontSize
    : (line.bounds.height > 0 ? line.bounds.height : 10);

String joinWords(List<LayoutWord> words) {
  final sb = StringBuffer();
  LayoutWord? prev;
  for (final w in words) {
    final t = w.text.trim();
    if (t.isEmpty) continue;
    if (prev != null) {
      sb.write(
        wordSeparator(
          prev.text.trim(),
          t,
          w.bounds.left - prev.bounds.right,
          w.fontSize > 0 ? w.fontSize : w.bounds.height,
        ),
      );
    }
    sb.write(t);
    prev = w;
  }
  return sb.toString();
}

/// Splits [line] into runs at horizontal gaps wider than
/// `cellGapFactor x font size`.
List<Seg> segmentLine(LayoutLine line, RebuildOptions o) {
  final fs = _fontSizeOf(line);
  final words = line.words.where((w) => w.text.trim().isNotEmpty).toList()
    ..sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
  if (words.isEmpty) {
    if (line.text.trim().isEmpty) return const [];
    final b = line.bounds;
    return [
      Seg._(line, 1, const [], b.left, b.top, b.right, b.bottom, fs, false),
    ];
  }
  final groups = <List<LayoutWord>>[
    [words.first],
  ];
  for (var i = 1; i < words.length; i++) {
    final gap = words[i].bounds.left - groups.last.last.bounds.right;
    if (gap > o.cellGapFactor * fs) {
      groups.add([words[i]]);
    } else {
      groups.last.add(words[i]);
    }
  }
  return [
    for (final g in groups)
      Seg._(
        line,
        groups.length,
        g,
        g.map((w) => w.bounds.left).min,
        g.map((w) => w.bounds.top).min,
        g.map((w) => w.bounds.right).max,
        g.map((w) => w.bounds.bottom).max,
        fs,
        g.every((w) => w.bold),
      ),
  ];
}

/// A visual row of a flow: runs sharing the same vertical position.
class Row {
  final List<Seg> segs; // sorted by left
  final int page;
  Row(this.segs, this.page);

  double get left => segs.first.left;
  double get right => segs.map((s) => s.right).max;
  double get top => segs.map((s) => s.top).min;
  double get bottom => segs.map((s) => s.bottom).max;
  double get height => math.max(bottom - top, 0.1);
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;

  /// Font size of the run holding most text.
  double get fontSize =>
      segs.reduce((a, b) => b.text.length > a.text.length ? b : a).fontSize;
  bool get bold => segs.every((s) => s.bold);

  late final String text = _buildText();

  String _buildText() {
    final first = segs.first;
    if (segs.every((s) => identical(s.line, first.line)) &&
        segs.length == first.lineSegCount) {
      return first.line.text.trim();
    }
    final sb = StringBuffer();
    for (var i = 0; i < segs.length; i++) {
      final t = segs[i].text;
      if (i > 0 && sb.isNotEmpty) {
        sb.write(
          wordSeparator(
            sb.toString(),
            t,
            segs[i].left - segs[i - 1].right,
            segs[i].fontSize,
          ),
        );
      }
      sb.write(t);
    }
    return sb.toString();
  }

  /// Text split into (text, bold) runs.
  List<(String, bool)> get styledRuns {
    final words = [for (final s in segs) ...s.words];
    final hasWords = segs.every((s) => s.words.isNotEmpty);
    if (!hasWords || words.every((w) => w.bold == words.first.bold)) {
      return [(text, bold)];
    }
    final runs = <(String, bool)>[];
    final sb = StringBuffer();
    bool? cur;
    LayoutWord? prev;
    for (final w in words) {
      final t = w.text.trim();
      if (t.isEmpty) continue;
      final sep = prev == null
          ? ''
          : wordSeparator(
              prev.text.trim(),
              t,
              w.bounds.left - prev.bounds.right,
              w.fontSize > 0 ? w.fontSize : w.bounds.height,
            );
      if (cur != null && cur != w.bold) {
        sb.write(sep); // trailing separator stays with the previous run
        runs.add((sb.toString(), cur));
        sb.clear();
      } else {
        sb.write(sep);
      }
      sb.write(t);
      cur = w.bold;
      prev = w;
    }
    if (sb.isNotEmpty) runs.add((sb.toString(), cur ?? false));
    return runs;
  }
}

sealed class FlowItem {
  double get top;
}

class RowItem extends FlowItem {
  final Row row;
  RowItem(this.row);
  @override
  double get top => row.top;
}

class TableItem extends FlowItem {
  final List<Row> rows;
  final List<List<String>> cells;
  TableItem(this.rows, this.cells);
  @override
  double get top => rows.first.top;
  int get columnCount => cells.isEmpty ? 0 : cells.first.length;
}

/// A reading-order region of a page (whole page, or one text column).
class Flow {
  final double colLeft, colRight;
  final List<FlowItem> items;
  Flow(this.colLeft, this.colRight, this.items);

  double get colWidth => math.max(colRight - colLeft, 1);
  double get colCenter => (colLeft + colRight) / 2;
}

class PageAnalysis {
  final LayoutPage page;
  final List<Flow> flows;
  PageAnalysis(this.page, this.flows);
}

/// Runs the whole analysis for every page.
List<PageAnalysis> analyzePages(List<LayoutPage> pages, RebuildOptions o) {
  final running = findRunningLines(pages, o);
  return [
    for (final page in pages)
      PageAnalysis(page, _analyzePage(page, running, o)),
  ];
}

List<Flow> _analyzePage(
  LayoutPage page,
  Set<LayoutLine> running,
  RebuildOptions o,
) {
  final segs = [
    for (final l in page.lines)
      if (!running.contains(l)) ...segmentLine(l, o),
  ];
  if (segs.isEmpty) return const [];
  final pageLeft = segs.map((s) => s.left).min;
  final pageRight = segs.map((s) => s.right).max;

  final gutter = o.detectColumns ? findGutter(segs, page, o) : null;
  final regions = <(List<Seg>, double, double)>[];
  if (gutter == null) {
    regions.add((segs, pageLeft, pageRight));
  } else {
    final above = <Seg>[], below = <Seg>[], left = <Seg>[], right = <Seg>[];
    for (final s in segs) {
      if (s.centerY < gutter.y0) {
        above.add(s);
      } else if (s.centerY > gutter.y1) {
        below.add(s);
      } else if (s.centerX < gutter.x) {
        left.add(s);
      } else {
        right.add(s);
      }
    }
    if (above.isNotEmpty) regions.add((above, pageLeft, pageRight));
    regions.add((left, pageLeft, left.map((s) => s.right).max));
    regions.add((right, right.map((s) => s.left).min, pageRight));
    if (below.isNotEmpty) regions.add((below, pageLeft, pageRight));
  }

  return [
    for (final (rs, l, r) in regions)
      Flow(l, r, _flowItems(groupRows(rs, page.index, o), o)),
  ];
}

List<FlowItem> _flowItems(List<Row> rows, RebuildOptions o) {
  final tables = o.detectTables ? _findTables(rows, o) : const <_TableHit>[];
  final items = <FlowItem>[];
  var t = 0;
  for (var i = 0; i < rows.length; i++) {
    if (t < tables.length && tables[t].first == i) {
      final hit = tables[t];
      items.add(TableItem(rows.sublist(hit.first, hit.last + 1), hit.cells));
      i = hit.last;
      t++;
    } else {
      items.add(RowItem(rows[i]));
    }
  }
  return items;
}

// --- running header / footer -----------------------------------------------

/// Lines repeated (same text with digits ignored, same height) near the top
/// or bottom edge on at least `headerFooterMinPageRatio` of the pages.
Set<LayoutLine> findRunningLines(List<LayoutPage> pages, RebuildOptions o) {
  final result = Set<LayoutLine>.identity();
  if (pages.length < o.headerFooterMinPages) return result;
  final need = math.max(
    2,
    (pages.length * o.headerFooterMinPageRatio - 1e-9).ceil(),
  );
  final groups = <String, List<(int, LayoutLine)>>{};
  for (var p = 0; p < pages.length; p++) {
    final page = pages[p];
    final zone = page.height * o.headerFooterZone;
    for (final l in page.lines) {
      if (l.bounds.top > zone && l.bounds.bottom < page.height - zone) continue;
      final key = headerFooterKey(l.text);
      if (key.isEmpty) continue;
      (groups[key] ??= []).add((p, l));
    }
  }
  for (final entries in groups.values) {
    if (entries.length < need) continue;
    for (final (_, anchor) in entries) {
      final members = entries
          .where(
            (e) =>
                (e.$2.bounds.top - anchor.bounds.top).abs() <=
                o.headerFooterYTolerance,
          )
          .toList();
      if (members.map((e) => e.$1).toSet().length >= need) {
        result.addAll(members.map((e) => e.$2));
      }
    }
  }
  return result;
}

// --- two columns -----------------------------------------------------------

class Gutter {
  final double x, y0, y1;
  Gutter(this.x, this.y0, this.y1);
}

/// Finds a vertical strip in the middle band of the page that no text run
/// crosses for at least `columnGutterMinHeightRatio` of the page height, with
/// prose-like text on both sides.
Gutter? findGutter(List<Seg> segs, LayoutPage page, RebuildOptions o) {
  if (segs.length < 2 * o.minColumnLines) return null;
  final contentTop = segs.map((s) => s.top).min;
  final contentBottom = segs.map((s) => s.bottom).max;
  final minH = page.height * o.columnGutterMinHeightRatio;
  if (contentBottom - contentTop < minH) return null;

  final candidates = <(double, double, double)>[]; // x, y0, y1
  for (
    var x = page.width * o.columnSearchFrom;
    x <= page.width * o.columnSearchTo;
    x += 2
  ) {
    final crossing = segs.where((s) => s.left < x && s.right > x).toList()
      ..sort((a, b) => a.top.compareTo(b.top));
    var cursor = contentTop;
    final free = <(double, double)>[];
    for (final s in crossing) {
      if (s.top > cursor) free.add((cursor, s.top));
      cursor = math.max(cursor, s.bottom);
    }
    if (contentBottom > cursor) free.add((cursor, contentBottom));
    for (final (a, b) in free) {
      if (b - a < minH) continue;
      if (_validColumns(segs, x, a, b, o)) candidates.add((x, a, b));
    }
  }
  if (candidates.isEmpty) return null;
  final best = candidates.map((c) => c.$3 - c.$2).max;
  final top = candidates.where((c) => c.$3 - c.$2 >= best - 0.01).toList();
  final pick = top[top.length ~/ 2];
  return Gutter(pick.$1, pick.$2, pick.$3);
}

bool _validColumns(
  List<Seg> segs,
  double x,
  double y0,
  double y1,
  RebuildOptions o,
) {
  final inside = segs.where((s) => s.centerY > y0 && s.centerY < y1);
  final left = inside.where((s) => s.right <= x).toList();
  final right = inside.where((s) => s.left >= x).toList();
  if (left.length < o.minColumnLines || right.length < o.minColumnLines) {
    return false;
  }
  bool prose(List<Seg> side, double span) =>
      side.where((s) => s.width >= 0.5 * span).length >= 0.5 * side.length;
  return prose(left, x - left.map((s) => s.left).min) &&
      prose(right, right.map((s) => s.right).max - x);
}

// --- rows ------------------------------------------------------------------

/// Groups runs whose vertical centres differ by at most
/// `rowToleranceFactor x height` into rows, top to bottom.
List<Row> groupRows(List<Seg> segs, int page, RebuildOptions o) {
  final sorted = [...segs]
    ..sort((a, b) {
      final c = a.top.compareTo(b.top);
      return c != 0 ? c : a.left.compareTo(b.left);
    });
  final rows = <List<Seg>>[];
  final centers = <double>[];
  final heights = <double>[];
  for (final s in sorted) {
    var placed = false;
    for (var k = rows.length - 1; k >= 0 && k >= rows.length - 3; k--) {
      final tol = o.rowToleranceFactor * math.min(s.height, heights[k]);
      if ((s.centerY - centers[k]).abs() <= tol) {
        rows[k].add(s);
        placed = true;
        break;
      }
    }
    if (!placed) {
      rows.add([s]);
      centers.add(s.centerY);
      heights.add(s.height);
    }
  }
  final result = [
    for (final r in rows)
      Row(r..sort((a, b) => a.left.compareTo(b.left)), page),
  ]..sort((a, b) => a.top.compareTo(b.top));
  return result;
}

// --- tables ----------------------------------------------------------------

class _TableHit {
  final int first, last;
  final List<List<String>> cells;
  _TableHit(this.first, this.last, this.cells);
}

final _bareMarker = RegExp(r'^([•\-*–]|\d{1,3}[.)]|[a-z][.)])$');

/// Finds tables among consecutive multi-run rows: cell left edges are
/// clustered into columns; a run of `tableMinRows` rows with at least
/// `tableMinColumns` columns that each appear in `columnMinRowRatio` of the
/// rows is a table.
List<_TableHit> _findTables(List<Row> rows, RebuildOptions o) {
  final hits = <_TableHit>[];
  var i = 0;
  while (i < rows.length) {
    if (rows[i].segs.length < 2) {
      i++;
      continue;
    }
    var j = i;
    while (j + 1 < rows.length &&
        rows[j + 1].segs.length >= 2 &&
        rows[j + 1].top > rows[j].top &&
        rows[j + 1].top - rows[j].bottom <=
            o.tableMaxRowGapFactor * rows[j].height) {
      j++;
    }
    if (j - i + 1 >= o.tableMinRows) {
      final hit = _analyzeRun(rows, i, j, o);
      if (hit != null) hits.add(hit);
    }
    i = j + 1;
  }
  return hits;
}

_TableHit? _analyzeRun(List<Row> rows, int first, int last, RebuildOptions o) {
  final run = rows.sublist(first, last + 1);
  final fs = run
      .map((r) => r.fontSize)
      .toList()
      .sorted((a, b) => a.compareTo(b))[run.length ~/ 2];
  final tol = o.columnToleranceFactor * fs;

  final entries = <(double, int)>[
    for (var r = 0; r < run.length; r++)
      for (final s in run[r].segs) (s.left, r),
  ]..sort((a, b) => a.$1.compareTo(b.$1));

  final clusters = <_Cluster>[];
  for (final (x, r) in entries) {
    if (clusters.isNotEmpty && x - clusters.last.mean <= tol) {
      clusters.last.add(x, r);
    } else {
      clusters.add(_Cluster()..add(x, r));
    }
  }
  final anchors = clusters
      .where((c) => c.rows.length >= o.columnMinRowRatio * run.length - 1e-9)
      .map((c) => c.mean)
      .toList();
  if (anchors.length < o.tableMinColumns) return null;

  final cells = <List<String>>[];
  for (final row in run) {
    final cellRow = List<String>.filled(anchors.length, '');
    for (final s in row.segs) {
      var k = 0;
      for (var a = 1; a < anchors.length; a++) {
        if ((s.left - anchors[a]).abs() < (s.left - anchors[k]).abs()) k = a;
      }
      final t = s.text;
      cellRow[k] = cellRow[k].isEmpty ? t : '${cellRow[k]} $t';
    }
    cells.add(cellRow);
  }
  // A list with a tab after the marker is not a table.
  if (anchors.length == 2 &&
      cells.every((c) => c[0].isEmpty || _bareMarker.hasMatch(c[0]))) {
    return null;
  }
  return _TableHit(first, last, cells);
}

class _Cluster {
  double _sum = 0;
  int _n = 0;
  final rows = <int>{};
  double get mean => _sum / _n;
  void add(double x, int row) {
    _sum += x;
    _n++;
    rows.add(row);
  }
}
