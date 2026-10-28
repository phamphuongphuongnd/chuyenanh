// Vẽ một slide PPTX bằng widget: canvas theo pt (EMU/12700) co lại bằng FittedBox.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pptx_reader/pptx_reader.dart';

import '../../core/l10n/l10n.dart';
import '../../core/utils/link_opener.dart';
import 'pptx_layout.dart';
import 'pptx_search.dart';

Color _argb(int v) => Color(v);

/// Từ khoá đang tìm: mọi đoạn chữ bên dưới tô vàng chỗ khớp (không phân biệt hoa thường).
/// Kết quả hiện tại (slide [currentSlide], thứ tự [currentOccurrence] trong slide) tô cam.
class PptxSearchHighlight extends InheritedWidget {
  const PptxSearchHighlight({
    super.key,
    required this.query,
    required super.child,
    this.index,
    this.currentSlide = -1,
    this.currentOccurrence = -1,
  });

  final String query;
  final Map<PptxParagraph, PptxParagraphPos>? index;
  final int currentSlide;
  final int currentOccurrence;

  static PptxSearchHighlight? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PptxSearchHighlight>();

  static String queryOf(BuildContext context) => of(context)?.query ?? '';

  @override
  bool updateShouldNotify(PptxSearchHighlight old) =>
      query != old.query ||
      index != old.index ||
      currentSlide != old.currentSlide ||
      currentOccurrence != old.currentOccurrence;
}

const Color _highlightBg = Color(0xFFFFEB3B);
const Color _highlightCurrentBg = Color(0xFFFF9800);

/// Tách [text] của một run thành các đoạn; phần giao với [ranges] (toạ độ trên cả đoạn văn,
/// run bắt đầu ở [runStart]) có nền vàng + chữ đen, kết quả [isCurrent] nền cam.
List<TextSpan> highlightRunSpans(
  String text,
  int runStart,
  List<(int, int)> ranges,
  TextStyle? style,
  GestureRecognizer? recognizer, {
  bool Function(int rangeIndex)? isCurrent,
}) {
  final runEnd = runStart + text.length;
  final spans = <TextSpan>[];
  var cursor = runStart;
  for (var k = 0; k < ranges.length; k++) {
    final s = ranges[k].$1 > runStart ? ranges[k].$1 : runStart;
    final e = ranges[k].$2 < runEnd ? ranges[k].$2 : runEnd;
    if (e <= s) continue;
    if (s > cursor) {
      spans.add(
        TextSpan(
          text: text.substring(cursor - runStart, s - runStart),
          style: style,
          recognizer: recognizer,
        ),
      );
    }
    spans.add(
      TextSpan(
        text: text.substring(s - runStart, e - runStart),
        style: (style ?? const TextStyle()).copyWith(
          backgroundColor: (isCurrent?.call(k) ?? false)
              ? _highlightCurrentBg
              : _highlightBg,
          color: Colors.black,
        ),
        recognizer: recognizer,
      ),
    );
    cursor = e;
  }
  if (cursor < runEnd || spans.isEmpty) {
    spans.add(
      TextSpan(
        text: text.substring(cursor - runStart),
        style: style,
        recognizer: recognizer,
      ),
    );
  }
  return spans;
}

/// Bản đơn giản: tô vàng mọi chỗ khớp [query] trong một chuỗi (không có kết quả hiện tại).
List<TextSpan> highlightSpans(
  String text,
  TextStyle? style,
  String query,
  GestureRecognizer? recognizer,
) {
  final q = query.trim().toLowerCase();
  final lower = text.toLowerCase();
  // Đổi hoa/thường làm lệch độ dài (vài ký tự đặc biệt) thì bỏ qua tô sáng.
  if (q.isEmpty || lower.length != text.length) {
    return [TextSpan(text: text, style: style, recognizer: recognizer)];
  }
  return highlightRunSpans(
    text,
    0,
    findMatchRanges(lower, q),
    style,
    recognizer,
  );
}

/// Slide hoàn chỉnh, tự co theo bề rộng có sẵn (giữ tỉ lệ).
/// [renderScale]: số pixel thiết bị dự kiến trên mỗi pt canvas (giới hạn giải mã ảnh).
class SlideView extends StatelessWidget {
  const SlideView({
    super.key,
    required this.deck,
    required this.slide,
    this.renderScale = 1.5,
  });

  final PptxDeck deck;
  final PptxSlide slide;
  final double renderScale;

  @override
  Widget build(BuildContext context) {
    final size = slideCanvasSize(deck);
    return AspectRatio(
      aspectRatio: size.width / size.height,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: ClipRect(
            child: ColoredBox(
              color: Colors.white,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  if (slide.background != null)
                    _FillBox(fill: slide.background!, scale: renderScale),
                  for (final s in slide.shapes)
                    ShapeWidget(shape: s, renderScale: renderScale),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FillBox extends StatelessWidget {
  const _FillBox({required this.fill, required this.scale});
  final PptxFill fill;
  final double scale;

  @override
  Widget build(BuildContext context) {
    if (fill.isPicture) {
      return Image.memory(
        fill.imageBytes!,
        fit: BoxFit.fill,
        gaplessPlayback: true,
        cacheWidth: (1280 * scale / 1.5).round(),
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    return ColoredBox(color: _argb(fill.colorArgb ?? 0xFFFFFFFF));
  }
}

/// Một hình bất kỳ, trả về `Positioned` (đặt trong Stack của canvas hoặc của nhóm).
class ShapeWidget extends StatelessWidget {
  const ShapeWidget({
    super.key,
    required this.shape,
    required this.renderScale,
  });

  final PptxShape shape;
  final double renderScale;

  @override
  Widget build(BuildContext context) {
    final s = shape;
    final rect = rectOfFrame(s.frame);
    if (s is PptxGroupShape) {
      return Positioned.fill(
        child: Transform(
          transform: Matrix4.rotationZ(rotationRadians(s)),
          origin: rect.center,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              for (final c in s.children)
                ShapeWidget(shape: c, renderScale: renderScale),
            ],
          ),
        ),
      );
    }
    final Widget body = switch (s) {
      PptxTextShape() =>
        s.unsupportedKind != null
            ? UnsupportedBox(kind: s.unsupportedKind!)
            : TextShapeBody(shape: s, size: rect.size),
      PptxPictureShape() => PictureBody(
        shape: s,
        size: rect.size,
        renderScale: renderScale,
      ),
      PptxTableShape() => TableBody(shape: s),
      PptxGroupShape() => const SizedBox.shrink(),
    };
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: s is PptxTableShape ? tableSize(s).width : rect.width,
      height: s is PptxTableShape ? tableSize(s).height : rect.height,
      child: Transform.rotate(angle: rotationRadians(s), child: body),
    );
  }
}

// ---------------------------------------------------------------- hình + chữ

class TextShapeBody extends StatelessWidget {
  const TextShapeBody({super.key, required this.shape, required this.size});
  final PptxTextShape shape;
  final Size size;

  bool get _hasPaint =>
      shape.fill != null || shape.line != null || shape.customPaths.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final hasText = shape.paragraphs.any((p) => p.runs.isNotEmpty);
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        if (_hasPaint)
          Transform.flip(
            flipX: shape.flipH,
            flipY: shape.flipV,
            child: CustomPaint(painter: ShapePainter(shape)),
          ),
        if (hasText)
          Padding(
            padding: EdgeInsets.zero,
            child: ParagraphsView(
              paragraphs: shape.paragraphs,
              insets: insetsOf(shape.insets),
              anchor: shape.verticalAnchor,
              wrap: shape.wrap,
              width: size.width,
            ),
          ),
      ],
    );
  }
}

class ShapePainter extends CustomPainter {
  ShapePainter(this.shape);
  final PptxTextShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = shape.fill;
    final line = shape.line;
    final fillPaint = fill != null && !fill.isPicture
        ? (Paint()..color = _argb(fill.colorArgb ?? 0xFF000000))
        : null;
    final linePaint = line == null
        ? null
        : (Paint()
            ..style = PaintingStyle.stroke
            ..color = _argb(line.colorArgb)
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = emuToPt(line.widthEmu).clamp(0.5, 200).toDouble());

    if (shape.customPaths.isNotEmpty) {
      for (final cp in shape.customPaths) {
        final path = customPathToFlutter(cp, size);
        if (fillPaint != null && cp.filled) canvas.drawPath(path, fillPaint);
        if (linePaint != null && cp.stroked) canvas.drawPath(path, linePaint);
      }
      return;
    }
    final path = presetPath(shape.geometry, shape.presetGeometry, size);
    if (shape.geometry == PptxGeometry.line) {
      if (linePaint != null) canvas.drawPath(path, linePaint);
      return;
    }
    if (fill != null && fill.isPicture) {
      // Ảnh nền hình: vẽ qua widget lớp trên nếu cần; ở đây chỉ tô xám nhạt.
      canvas.drawPath(path, Paint()..color = const Color(0x11000000));
    }
    if (fillPaint != null) canvas.drawPath(path, fillPaint);
    if (linePaint != null) canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(ShapePainter old) => old.shape != shape;
}

/// Khối đoạn văn: căn dọc theo anchor, tràn chữ không báo lỗi layout.
class ParagraphsView extends StatelessWidget {
  const ParagraphsView({
    super.key,
    required this.paragraphs,
    required this.insets,
    required this.anchor,
    required this.wrap,
    required this.width,
    this.defaultColor = const Color(0xFF000000),
  });

  final List<PptxParagraph> paragraphs;
  final EdgeInsets insets;
  final PptxAnchor anchor;
  final bool wrap;
  final double width;
  final Color defaultColor;

  @override
  Widget build(BuildContext context) {
    final labels = bulletLabels(paragraphs);
    final inner = (width - insets.horizontal).clamp(0.0, double.infinity);
    return Padding(
      padding: insets,
      child: OverflowBox(
        alignment: alignmentOfAnchor(anchor),
        minWidth: inner,
        maxWidth: inner,
        minHeight: 0,
        maxHeight: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < paragraphs.length; i++)
              ParagraphWidget(
                paragraph: paragraphs[i],
                bullet: paragraphs[i].runs.isEmpty ? null : labels[i],
                wrap: wrap,
                defaultColor: defaultColor,
              ),
          ],
        ),
      ),
    );
  }
}

class ParagraphWidget extends StatefulWidget {
  const ParagraphWidget({
    super.key,
    required this.paragraph,
    required this.bullet,
    required this.wrap,
    required this.defaultColor,
  });

  final PptxParagraph paragraph;
  final String? bullet;
  final bool wrap;
  final Color defaultColor;

  @override
  State<ParagraphWidget> createState() => _ParagraphWidgetState();
}

class _ParagraphWidgetState extends State<ParagraphWidget> {
  static const double _defaultSize = 18;
  final List<TapGestureRecognizer> _recognizers = [];

  PptxParagraph get paragraph => widget.paragraph;
  String? get bullet => widget.bullet;
  bool get wrap => widget.wrap;
  Color get defaultColor => widget.defaultColor;

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
              ? l10n.pptx_linkOpening(res.uri.toString())
              : l10n.pptx_linkOpenFailed,
        ),
      ),
    );
  }

  TapGestureRecognizer? _recognizerFor(PptxRun r) {
    final url = r.hyperlink;
    if (url == null) return null;
    final rec = TapGestureRecognizer()..onTap = () => _openLink(url);
    _recognizers.add(rec);
    return rec;
  }

  double get _firstSize {
    for (final r in paragraph.runs) {
      if (r.fontSizePt != null && r.text.trim().isNotEmpty) {
        return r.fontSizePt!;
      }
    }
    return paragraph.runs.firstOrNull?.fontSizePt ??
        paragraph.endFontSizePt ??
        _defaultSize;
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    final p = paragraph;
    final height = lineHeightFactor(p, _firstSize);
    final hl = PptxSearchHighlight.of(context);
    final q = hl?.query.trim().toLowerCase() ?? '';
    final fullText = p.runs.map((r) => r.text).join();
    final lowerFull = fullText.toLowerCase();
    // Đổi hoa/thường làm lệch độ dài (vài ký tự đặc biệt) thì bỏ qua tô sáng.
    final ranges = (q.isEmpty || lowerFull.length != fullText.length)
        ? const <(int, int)>[]
        : findMatchRanges(lowerFull, q);
    final pos = hl?.index?[p];
    final spans = <InlineSpan>[];
    var offset = 0;
    for (final r in p.runs) {
      final style = runStyle(r, defaultColor, _firstSize, height);
      final rec = _recognizerFor(r);
      if (ranges.isEmpty) {
        spans.add(TextSpan(text: r.text, style: style, recognizer: rec));
      } else {
        spans.addAll(
          highlightRunSpans(
            r.text,
            offset,
            ranges,
            style,
            rec,
            isCurrent: (k) =>
                pos != null &&
                pos.slideIndex == hl!.currentSlide &&
                pos.firstOccurrence + k == hl.currentOccurrence,
          ),
        );
      }
      offset += r.text.length;
    }
    if (spans.isEmpty) {
      spans.add(
        TextSpan(
          text: ' ',
          style: TextStyle(
            fontSize: p.endFontSizePt ?? _defaultSize,
            height: height,
          ),
        ),
      );
    }
    final text = RichText(
      textAlign: textAlignOf(p.align),
      softWrap: wrap,
      text: TextSpan(children: spans),
    );

    final marginLeft = emuToPt(p.marginLeftEmu);
    final indent = emuToPt(p.indentEmu);
    Widget child;
    if (bullet != null) {
      final bulletColor = p.bulletColorArgb != null
          ? _argb(p.bulletColorArgb!)
          : (p.runs.firstOrNull?.colorArgb != null
                ? _argb(p.runs.first.colorArgb!)
                : defaultColor);
      final bulletSize = _firstSize * ((p.bulletSizePct ?? 100) / 100);
      // Bullet treo: đặt tại marginLeft + indent (indent thường âm), chữ tại marginLeft.
      final hang = indent < 0 ? -indent : _firstSize;
      child = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: hang,
            child: Text(
              bullet!,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: TextStyle(
                fontSize: bulletSize,
                height: height,
                color: bulletColor,
              ),
            ),
          ),
          Expanded(child: text),
        ],
      );
    } else {
      child = text;
    }
    final left = bullet != null
        ? (marginLeft + (indent < 0 ? indent : 0))
        : marginLeft;
    return Padding(
      padding: EdgeInsets.only(
        left: left < 0 ? 0 : left,
        top: p.spaceBeforePt ?? 0,
        bottom: p.spaceAfterPt ?? 0,
      ),
      child: child,
    );
  }
}

/// Kiểu chữ của một run (pt dùng thẳng).
TextStyle runStyle(
  PptxRun r,
  Color defaultColor,
  double paragraphSize,
  double height,
) {
  final sizeBase = r.fontSizePt ?? paragraphSize;
  final scaled = r.baselineOffsetPct != 0 ? sizeBase * 0.65 : sizeBase;
  final decorations = <TextDecoration>[
    if (r.underline || r.hyperlink != null) TextDecoration.underline,
    if (r.strike) TextDecoration.lineThrough,
  ];
  final family = r.fontFamily?.toLowerCase() ?? '';
  return TextStyle(
    fontSize: scaled,
    height: height,
    fontWeight: r.bold ? FontWeight.bold : FontWeight.normal,
    fontStyle: r.italic ? FontStyle.italic : FontStyle.normal,
    color: r.colorArgb != null ? _argb(r.colorArgb!) : defaultColor,
    decoration: decorations.isEmpty
        ? TextDecoration.none
        : TextDecoration.combine(decorations),
    fontFamily: family.contains('consolas') || family.contains('courier')
        ? 'monospace'
        : null,
  );
}

// ---------------------------------------------------------------- khác

class UnsupportedBox extends StatelessWidget {
  const UnsupportedBox({super.key, required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        border: Border.all(color: const Color(0xFFBDBDBD), width: 1.5),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.extension_off_outlined,
                size: 36,
                color: Color(0xFF757575),
              ),
              Text(
                context.l10n.pptx_unsupportedObject,
                style: const TextStyle(fontSize: 16, color: Color(0xFF616161)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PictureBody extends StatelessWidget {
  const PictureBody({
    super.key,
    required this.shape,
    required this.size,
    required this.renderScale,
  });
  final PptxPictureShape shape;
  final Size size;
  final double renderScale;

  @override
  Widget build(BuildContext context) {
    final r = cropImageRect(size, shape.crop);
    final cacheW = (r.width * renderScale).clamp(16, 2048).round();
    Widget img = ClipRect(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fromRect(
            rect: r,
            child: Image.memory(
              shape.bytes,
              fit: BoxFit.fill,
              gaplessPlayback: true,
              cacheWidth: cacheW,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Color(0xFFEEEEEE),
                child: Center(
                  child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (shape.flipH || shape.flipV) {
      img = Transform.flip(flipX: shape.flipH, flipY: shape.flipV, child: img);
    }
    final line = shape.line;
    if (line != null) {
      img = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(
            color: _argb(line.colorArgb),
            width: emuToPt(line.widthEmu).clamp(0.5, 100).toDouble(),
          ),
        ),
        child: img,
      );
    }
    return img;
  }
}

class TableBody extends StatelessWidget {
  const TableBody({super.key, required this.shape});
  final PptxTableShape shape;

  @override
  Widget build(BuildContext context) {
    final boxes = layoutTable(shape);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final b in boxes)
          Positioned.fromRect(
            rect: b.rect,
            child: _CellView(box: b),
          ),
      ],
    );
  }
}

class _CellView extends StatelessWidget {
  const _CellView({required this.box});
  final TableCellBox box;

  @override
  Widget build(BuildContext context) {
    final c = box.cell;
    final fill = c.fill;
    return CustomPaint(
      painter: _CellBorderPainter(c),
      child: ColoredBox(
        color: fill != null && !fill.isPicture
            ? _argb(fill.colorArgb ?? 0x00000000)
            : Colors.transparent,
        child: c.paragraphs.isEmpty
            ? null
            : ParagraphsView(
                paragraphs: c.paragraphs,
                insets: insetsOf(c.insets),
                anchor: c.verticalAnchor,
                wrap: true,
                width: box.rect.width,
              ),
      ),
    );
  }
}

class _CellBorderPainter extends CustomPainter {
  _CellBorderPainter(this.cell);
  final PptxTableCell cell;

  void _edge(Canvas canvas, PptxLine? l, Offset a, Offset b) {
    if (l == null) return;
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = _argb(l.colorArgb)
        ..strokeWidth = emuToPt(l.widthEmu).clamp(0.5, 20).toDouble(),
    );
  }

  @override
  void paint(Canvas canvas, Size s) {
    _edge(canvas, cell.borderLeft, Offset.zero, Offset(0, s.height));
    _edge(canvas, cell.borderTop, Offset.zero, Offset(s.width, 0));
    _edge(
      canvas,
      cell.borderRight,
      Offset(s.width, 0),
      Offset(s.width, s.height),
    );
    _edge(
      canvas,
      cell.borderBottom,
      Offset(0, s.height),
      Offset(s.width, s.height),
    );
  }

  @override
  bool shouldRepaint(_CellBorderPainter old) => old.cell != cell;
}
