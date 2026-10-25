import 'dart:math' as math;

import 'package:collection/collection.dart';

import 'analysis.dart';
import 'blocks.dart';
import 'model.dart';
import 'options.dart';
import 'text_utils.dart';

/// Rebuilds headings, paragraphs, lists and tables from extracted lines.
///
/// Pure and synchronous; safe to run inside `Isolate.run`.
List<DocBlock> rebuildDocument(
  List<LayoutPage> pages, {
  RebuildOptions options = const RebuildOptions(),
}) {
  final analysis = analyzePages(pages, options);
  final metrics = _Metrics.of(analysis, options);
  final blocks = <DocBlock>[];
  for (var p = 0; p < analysis.length; p++) {
    if (p > 0 && options.insertPageBreaks) blocks.add(const DocPageBreak());
    for (final flow in analysis[p].flows) {
      final builder = _BlockBuilder(flow, metrics, options, blocks);
      for (final item in flow.items) {
        switch (item) {
          case TableItem t:
            builder.flush();
            blocks.add(DocTable(cells: t.cells));
          case RowItem r:
            builder.add(r.row);
        }
      }
      builder.flush();
    }
  }
  return blocks;
}

class _Metrics {
  /// Weighted median font size of body text.
  final double bodyFontSize;

  /// Max top-to-top distance between lines of a paragraph, in line heights.
  final double maxPitchFactor;

  _Metrics(this.bodyFontSize, this.maxPitchFactor);

  factory _Metrics.of(List<PageAnalysis> pages, RebuildOptions o) {
    final sizes = <(double, int)>[];
    final ratios = <double>[];
    for (final p in pages) {
      for (final f in p.flows) {
        Row? prev;
        for (final item in f.items) {
          if (item is! RowItem) {
            prev = null;
            continue;
          }
          final r = item.row;
          sizes.add((r.fontSize, math.max(1, r.text.runes.length)));
          if (prev != null &&
              (prev.fontSize - r.fontSize).abs() <= o.fontSizeTolerance) {
            final ratio = (r.top - prev.top) / prev.height;
            if (ratio > 0 && ratio < 3) ratios.add(ratio);
          }
          prev = r;
        }
      }
    }
    var body = 10.0;
    if (sizes.isNotEmpty) {
      sizes.sort((a, b) => a.$1.compareTo(b.$1));
      final total = sizes.fold<int>(0, (s, e) => s + e.$2);
      var acc = 0;
      for (final (size, w) in sizes) {
        acc += w;
        if (acc * 2 >= total) {
          body = size;
          break;
        }
      }
    }
    var factor = o.lineGapFactor;
    if (ratios.isNotEmpty) {
      ratios.sort();
      final typical = ratios[(ratios.length - 1) ~/ 4];
      factor = math.max(
        factor,
        math.min(typical * o.typicalPitchFactor, o.maxLineGapFactor),
      );
    }
    return _Metrics(body, factor);
  }
}

class _BlockBuilder {
  final Flow flow;
  final _Metrics m;
  final RebuildOptions o;
  final List<DocBlock> out;

  final List<Row> _lines = [];
  double? _bodyLeft;
  bool _centered = false;
  bool _isList = false;

  _BlockBuilder(this.flow, this.m, this.o, this.out);

  void add(Row row) {
    if (_lines.isNotEmpty && !_canMerge(row)) flush();
    if (_lines.isEmpty) {
      _isList = matchListMarker(row.text) != null;
    } else if (_lines.length == 1 && !_centered) {
      _bodyLeft = row.left;
    }
    _lines.add(row);
  }

  bool _isShort(Row r) =>
      r.right - flow.colLeft < o.shortLineRatio * flow.colWidth;

  bool _isCenteredRow(Row r) {
    final fs = r.fontSize;
    return (r.centerX - flow.colCenter).abs() <= fs &&
        r.left - flow.colLeft > 2 * fs &&
        flow.colRight - r.right > 2 * fs;
  }

  bool _canMerge(Row b) {
    final a = _lines.last;
    if (matchListMarker(b.text) != null) return false;
    if ((a.fontSize - b.fontSize).abs() > o.fontSizeTolerance) return false;
    if (a.bold != b.bold) return false;
    final pitch = b.top - a.top;
    if (pitch <= 0 || pitch > m.maxPitchFactor * a.height) return false;
    if (_isShort(a) && endsWithTerminal(a.text)) return false;

    final tol = o.leftToleranceFactor * a.fontSize;
    final maxIndent = o.maxIndentFactor * a.fontSize;
    if (_centered) return _isCenteredRow(b);
    final bodyLeft = _bodyLeft;
    if (bodyLeft != null) return (b.left - bodyLeft).abs() <= tol;

    final dx = b.left - a.left;
    if (dx.abs() <= tol) return true;
    // First line indented, the following ones at the margin.
    if (-dx > tol && -dx <= maxIndent && !_isShort(a)) return true;
    // Hanging indent of a list item.
    if (_isList && dx > tol && dx <= maxIndent) return true;
    if (_isCenteredRow(a) && _isCenteredRow(b)) {
      _centered = true;
      return true;
    }
    return false;
  }

  void flush() {
    if (_lines.isEmpty) return;
    out.add(_toBlock());
    _lines.clear();
    _bodyLeft = null;
    _centered = false;
    _isList = false;
  }

  DocBlock _toBlock() {
    final fs = _lines.first.fontSize;
    final sizePt = (fs - m.bodyFontSize).abs() > o.fontSizeTolerance
        ? fs
        : null;
    var spans = _spans(sizePt);
    final text = spans.map((s) => s.text).join();
    final ratio = fs / m.bodyFontSize;

    if (ratio >= o.headingRatio) {
      final level = ratio >= o.heading1Ratio
          ? 1
          : ratio >= o.heading2Ratio
          ? 2
          : 3;
      return DocHeading(level: level, spans: spans);
    }

    final allBold = _lines.every((l) => l.bold);
    final boldHeading =
        allBold &&
        _lines.length == 1 &&
        text.runes.length <= o.boldHeadingMaxChars;

    final marker = matchListMarker(text);
    if (marker != null) {
      final ordered = isOrderedMarker(marker.$1);
      if (!(ordered && boldHeading)) {
        return DocListItem(
          ordered: ordered,
          marker: marker.$1,
          spans: _dropPrefix(spans, marker.$2),
        );
      }
    }
    if (boldHeading) return DocHeading(level: 3, spans: spans);

    final first = _lines.first;
    final fsTol = first.fontSize;
    DocAlign align;
    if (_centered || (_lines.length == 1 && _isCenteredRow(first))) {
      align = DocAlign.center;
    } else if (first.left - flow.colLeft > 2 * fsTol &&
        _lines.every((l) => (flow.colRight - l.right).abs() <= fsTol)) {
      align = DocAlign.right;
    } else if (_lines.length >= 2 &&
        _lines
            .take(_lines.length - 1)
            .every((l) => (flow.colRight - l.right).abs() <= 0.5 * fsTol)) {
      align = DocAlign.justify;
    } else {
      align = DocAlign.left;
    }

    var indent = 0.0, firstLine = 0.0;
    if (align == DocAlign.left || align == DocAlign.justify) {
      final body = _lines.length >= 2 ? _lines[1].left : first.left;
      indent = _round(body - flow.colLeft);
      firstLine = _lines.length >= 2 ? _round(first.left - body) : 0;
      if (indent < 0) indent = 0;
    }
    return DocParagraph(
      spans: spans,
      align: align,
      indentPt: indent,
      firstLineIndentPt: firstLine,
    );
  }

  static double _round(double v) {
    final r = (v * 2).round() / 2;
    return r.abs() < 1 ? 0 : r;
  }

  List<DocSpan> _spans(double? sizePt) {
    final pieces = <(String, bool)>[];
    for (final line in _lines) {
      final runs = line.styledRuns.where((r) => r.$1.isNotEmpty).toList();
      if (runs.isEmpty) continue;
      if (pieces.isNotEmpty) {
        final (prevText, prevBold) = pieces.last;
        final join = lineJoin(prevText, runs.first.$1);
        pieces[pieces.length - 1] = (
          prevText.substring(0, prevText.length - join.trimEnd) +
              join.separator,
          prevBold,
        );
      }
      pieces.addAll(runs);
    }
    final merged = <(String, bool)>[];
    for (final p in pieces) {
      if (merged.isNotEmpty && merged.last.$2 == p.$2) {
        merged[merged.length - 1] = (merged.last.$1 + p.$1, p.$2);
      } else {
        merged.add(p);
      }
    }
    return [
      for (final (t, b) in merged)
        if (t.isNotEmpty) DocSpan(t, bold: b, fontSizePt: sizePt),
    ];
  }

  static List<DocSpan> _dropPrefix(List<DocSpan> spans, int count) {
    final result = <DocSpan>[];
    var left = count;
    for (final s in spans) {
      if (left <= 0) {
        result.add(s);
      } else if (s.text.length <= left) {
        left -= s.text.length;
      } else {
        result.add(
          DocSpan(
            s.text.substring(left),
            bold: s.bold,
            fontSizePt: s.fontSizePt,
          ),
        );
        left = 0;
      }
    }
    return result.whereNot((s) => s.text.isEmpty).toList();
  }
}
