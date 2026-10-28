import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:office_reader/office_reader.dart' as rd;
import 'package:path/path.dart' as p;

import '../../../core/l10n/l10n.dart';
import '../../../core/utils/link_opener.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../logic/docx_table_grid.dart';
import '../logic/text_search.dart';
import 'office_common.dart';
import 'span_table.dart';

/// 1 point trên màn hình ở mức zoom 1 (≈ 11pt → 14,3 px).
const double _ptToPx = 1.3;
const List<double> _headingPt = [11, 20, 16, 14, 12, 11, 11];

/// Tham số vẽ chung cho các khối.
class DocxRenderCtx {
  const DocxRenderCtx({this.scale = 1, this.query = ''});

  final double scale;
  final String query;

  double get k => _ptToPx * scale;
}

/// Văn bản thuần của một khối (để tìm chữ). Bảng: mọi ô nối bằng xuống dòng.
String docxBlockText(rd.DocxBlock b) => switch (b) {
  rd.DocxParagraph() => b.plainText,
  rd.DocxPageBreak() => '',
  rd.DocxTable() => [
    for (final r in b.rows)
      for (final c in r.cells)
        if (!c.vMergeContinue) ...c.blocks.map(docxBlockText),
  ].join('\n'),
};

class DocxViewerPage extends StatefulWidget {
  const DocxViewerPage({super.key, required this.path, required this.document});

  final String path;
  final rd.DocxDocument document;

  @override
  State<DocxViewerPage> createState() => _DocxViewerPageState();
}

class _DocxViewerPageState extends State<DocxViewerPage> {
  late final List<String> _texts = [
    for (final b in widget.document.blocks) docxBlockText(b),
  ];
  final _scroller = IndexedScroller();
  final _searchCtrl = TextEditingController();
  double _scale = 1;
  bool _searching = false;
  List<SearchHit> _hits = const [];
  int _current = 0;

  @override
  void dispose() {
    _scroller.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _setScale(double s) => setState(() => _scale = s.clamp(0.6, 3.0));

  void _onQuery(String q) {
    setState(() {
      _hits = findHits(_texts, q);
      _current = 0;
    });
    _goToCurrent();
  }

  void _step(int delta) {
    if (_hits.isEmpty) return;
    setState(() => _current = (_current + delta + _hits.length) % _hits.length);
    _goToCurrent();
  }

  void _goToCurrent() {
    if (_hits.isEmpty) return;
    _scroller.jumpTo(_hits[_current].block, widget.document.blocks.length);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final blocks = widget.document.blocks;
    final ctx = DocxRenderCtx(
      scale: _scale,
      query: _searching ? _searchCtrl.text : '',
    );
    final cur = _hits.isEmpty ? null : _hits[_current];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.doc,
        foregroundColor: Colors.white,
        title: Text(p.basename(widget.path), overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: l.office_search,
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _searching = !_searching),
          ),
          IconButton(
            tooltip: l.office_zoomOut,
            icon: const Icon(Icons.zoom_out),
            onPressed: () => _setScale(_scale - 0.2),
          ),
          IconButton(
            tooltip: l.office_zoomIn,
            icon: const Icon(Icons.zoom_in),
            onPressed: () => _setScale(_scale + 0.2),
          ),
          IconButton(
            tooltip: l.office_convertToPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () =>
                context.push(Routes.wordToPdf, extra: widget.path),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_searching)
            OfficeSearchBar(
              color: AppColors.doc,
              controller: _searchCtrl,
              onChanged: _onQuery,
              current: _hits.isEmpty ? 0 : _current + 1,
              total: _hits.length,
              onPrev: () => _step(-1),
              onNext: () => _step(1),
              onClose: () => setState(() {
                _searching = false;
                _searchCtrl.clear();
                _hits = const [];
              }),
            ),
          Expanded(
            child: blocks.isEmpty
                ? Center(child: Text(l.office_emptyDocument))
                : PinchZoom(
                    scale: _scale,
                    min: 0.6,
                    max: 3,
                    onScaleChanged: _setScale,
                    child: ColoredBox(
                      color: Colors.white,
                      child: SelectionArea(
                        child: ListView.builder(
                          controller: _scroller.controller,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount: blocks.length,
                          itemBuilder: (context, i) => KeyedSubtree(
                            key: _scroller.keyFor(i),
                            child: DocxBlockView(
                              block: blocks[i],
                              ctx: ctx,
                              currentStart: cur != null && cur.block == i
                                  ? cur.start
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Vẽ một khối (đoạn / bảng / ngắt trang).
class DocxBlockView extends StatelessWidget {
  const DocxBlockView({
    super.key,
    required this.block,
    required this.ctx,
    this.currentStart,
  });

  final rd.DocxBlock block;
  final DocxRenderCtx ctx;

  /// Vị trí kết quả tìm "hiện tại" trong đoạn (chỉ đoạn cấp cao nhất).
  final int? currentStart;

  @override
  Widget build(BuildContext context) => switch (block) {
    rd.DocxParagraph b => DocxParagraphView(
      para: b,
      ctx: ctx,
      currentStart: currentStart,
    ),
    rd.DocxTable b => DocxTableView(table: b, ctx: ctx),
    rd.DocxPageBreak() => Padding(
      padding: EdgeInsets.symmetric(vertical: 8 * ctx.scale),
      child: const Divider(height: 1, color: Color(0xFFBDBDBD)),
    ),
  };
}

TextAlign _textAlign(rd.DocxAlign a) => switch (a) {
  rd.DocxAlign.left => TextAlign.left,
  rd.DocxAlign.center => TextAlign.center,
  rd.DocxAlign.right => TextAlign.right,
  rd.DocxAlign.justify => TextAlign.justify,
};

Alignment _boxAlign(rd.DocxAlign a) => switch (a) {
  rd.DocxAlign.center => Alignment.center,
  rd.DocxAlign.right => Alignment.centerRight,
  _ => Alignment.centerLeft,
};

class DocxParagraphView extends StatefulWidget {
  const DocxParagraphView({
    super.key,
    required this.para,
    required this.ctx,
    this.currentStart,
  });

  final rd.DocxParagraph para;
  final DocxRenderCtx ctx;
  final int? currentStart;

  @override
  State<DocxParagraphView> createState() => _DocxParagraphViewState();
}

class _DocxParagraphViewState extends State<DocxParagraphView> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _openLink(String url) async {
    final launcher = linkLauncherOf(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    final res = await openLink(launcher, url);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          res.opened
              ? l10n.office_linkOpening(res.uri.toString())
              : l10n.office_linkOpenFailed,
        ),
      ),
    );
  }

  TextStyle _runStyle(rd.DocxRun r, int heading, double k) {
    final basePt = r.fontSizePt ?? _headingPt[heading.clamp(0, 6)];
    final sizePt = (r.superscript || r.subscript) ? basePt * 0.75 : basePt;
    final link = r.hyperlink != null;
    final decorations = <TextDecoration>[
      if (r.underline || link) TextDecoration.underline,
      if (r.strike) TextDecoration.lineThrough,
    ];
    return TextStyle(
      fontSize: sizePt * k,
      fontWeight: (r.bold || heading > 0) ? FontWeight.bold : null,
      fontStyle: r.italic ? FontStyle.italic : null,
      color: link
          ? const Color(0xFF0563C1)
          : (r.colorArgb != null ? Color(r.colorArgb!) : Colors.black),
      backgroundColor: r.highlightArgb != null ? Color(r.highlightArgb!) : null,
      decoration: decorations.isEmpty
          ? null
          : TextDecoration.combine(decorations),
    );
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final para = widget.para;
    final ctx = widget.ctx;
    final k = ctx.k;
    final heading = para.headingLevel ?? 0;
    final baseStyle = TextStyle(
      fontSize: 11 * k,
      color: Colors.black,
      height: para.lineSpacing ?? 1.25,
    );

    final parts = <Widget>[];
    var spans = <InlineSpan>[];
    var offset = 0;

    void flushText() {
      if (spans.isEmpty) return;
      parts.add(
        Align(
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(children: spans),
            textAlign: _textAlign(para.align),
            style: baseStyle,
          ),
        ),
      );
      spans = <InlineSpan>[];
    }

    for (final inline in para.inlines) {
      switch (inline) {
        case rd.DocxRun r:
          final style = _runStyle(r, heading, k);
          TapGestureRecognizer? rec;
          if (r.hyperlink != null) {
            final url = r.hyperlink!;
            rec = TapGestureRecognizer()..onTap = () => _openLink(url);
            _recognizers.add(rec);
          }
          for (final seg in highlightSegments(r.text, ctx.query)) {
            final isCur =
                seg.matched && widget.currentStart == offset + seg.start;
            spans.add(
              TextSpan(
                text: seg.text.replaceAll('\t', '    '),
                recognizer: rec,
                style: seg.matched
                    ? style.copyWith(
                        backgroundColor: isCur ? Colors.orange : Colors.yellow,
                        color: Colors.black,
                      )
                    : style,
              ),
            );
          }
          offset += r.text.length;
        case rd.DocxBreak():
          spans.add(const TextSpan(text: '\n'));
          offset += 1;
        case rd.DocxImage img:
          flushText();
          parts.add(_ImageBlock(image: img, ctx: ctx, align: para.align));
      }
    }
    flushText();
    if (parts.isEmpty) {
      parts.add(SizedBox(height: 11 * k * 1.25));
    }

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: parts,
    );

    final label = para.listLabel;
    final level = para.listLevel;
    var padLeft = (para.indentLeftPt ?? 0) * k;
    if (label != null && level != null) {
      final labelW = 24 * k;
      padLeft = ((para.indentLeftPt ?? 18.0 * (level + 1)) * k - labelW)
          .clamp(0, double.infinity)
          .toDouble();
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelW,
            child: Text(label, style: baseStyle),
          ),
          Expanded(child: content),
        ],
      );
    }

    final padTop = (para.spaceBeforePt ?? (heading > 0 ? 8 : 0)) * k;
    final padBottom = (para.spaceAfterPt ?? 6) * k;
    final rawPadRight = (para.indentRightPt ?? 0) * k;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Trang Word rộng hơn màn hình nhiều: chừa ít nhất nửa bề rộng cho chữ.
        final left = padLeft.clamp(0.0, constraints.maxWidth * 0.5);
        final maxPad = (constraints.maxWidth - left) * 0.5;
        final padRight = rawPadRight.clamp(0.0, maxPad < 0 ? 0.0 : maxPad);
        return Padding(
          padding: EdgeInsets.fromLTRB(left, padTop, padRight, padBottom),
          child: content,
        );
      },
    );
  }
}

class _ImageBlock extends StatelessWidget {
  const _ImageBlock({
    required this.image,
    required this.ctx,
    required this.align,
  });

  final rd.DocxImage image;
  final DocxRenderCtx ctx;
  final rd.DocxAlign align;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final natural = image.widthPt * ctx.k;
        // Không có kích thước (VML/`wp:extent` = 0) thì lấp đầy bề ngang thay vì thành vạch 1px.
        final w = (natural > 1 ? natural : c.maxWidth)
            .clamp(1.0, c.maxWidth)
            .toDouble();
        final decodeW = (w * MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(1, 2048);
        return Align(
          alignment: _boxAlign(align),
          child: Image.memory(
            image.bytes,
            width: w,
            cacheWidth: decodeW,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (context, _, _) => Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image_outlined, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.office_imageUnsupported,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class DocxTableView extends StatelessWidget {
  const DocxTableView({super.key, required this.table, required this.ctx});

  final rd.DocxTable table;
  final DocxRenderCtx ctx;

  @override
  Widget build(BuildContext context) {
    final grid = buildTableGrid(table);
    if (grid.cells.isEmpty) return const SizedBox.shrink();
    final k = ctx.k;
    final widths = tableColumnWidths(table, grid.colCount, k);
    final natural = widths.fold<double>(0, (a, b) => a + b);
    final border = BorderSide(
      color: table.bordered ? Colors.black54 : Colors.black12,
      width: table.bordered ? 1 : 0.5,
    );

    Widget build(double? fixedWidth) => SpanTable(
      columnWidths: widths,
      rowCount: grid.rowCount,
      minRowHeights: [
        for (final r in table.rows) (r.heightTwips ?? 0) / 20 * k,
      ],
      children: [
        for (final pc in grid.cells)
          SpanTableCell(
            row: pc.row,
            col: pc.col,
            rowSpan: pc.rowSpan,
            colSpan: pc.colSpan,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: pc.cell.shadingArgb != null
                    ? Color(pc.cell.shadingArgb!)
                    : null,
                border: Border.fromBorderSide(border),
              ),
              child: Padding(
                padding: EdgeInsets.all(4 * ctx.scale),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final b in pc.cell.blocks)
                      DocxBlockView(block: b, ctx: ctx),
                  ],
                ),
              ),
            ),
          ),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 8 * ctx.scale),
      child: LayoutBuilder(
        builder: (context, c) {
          // Phóng to quá khổ → cho cuộn ngang thay vì co lại.
          if (ctx.scale > 1 && natural > c.maxWidth) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: natural, child: build(natural)),
            );
          }
          return Align(
            alignment: Alignment.centerLeft,
            child: build(null),
          );
        },
      ),
    );
  }
}
