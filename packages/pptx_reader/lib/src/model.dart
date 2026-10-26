import 'dart:typed_data';

/// Thrown when the input is not a readable .pptx package.
class PptxFormatException implements Exception {
  const PptxFormatException(this.message);

  final String message;

  @override
  String toString() => 'PptxFormatException: $message';
}

/// A whole presentation. Sizes are in EMU (914400 EMU = 1 inch, 12700 EMU = 1 pt).
class PptxDeck {
  const PptxDeck({
    required this.slideWidthEmu,
    required this.slideHeightEmu,
    required this.slides,
  });

  final int slideWidthEmu;
  final int slideHeightEmu;
  final List<PptxSlide> slides;
}

class PptxSlide {
  const PptxSlide({
    required this.index,
    required this.background,
    required this.shapes,
    required this.notesText,
    this.hidden = false,
  });

  /// 0-based position in presentation order.
  final int index;

  /// Effective background (slide, else layout, else master). Null = none (white).
  final PptxFill? background;

  /// Shapes in z-order (back to front). Includes non-placeholder shapes of the
  /// master and layout (unless `showMasterSp="0"`), followed by the slide's own.
  final List<PptxShape> shapes;

  /// Plain text of the speaker notes (paragraphs joined by '\n'), or null.
  final String? notesText;

  /// `show="0"` on the slide.
  final bool hidden;
}

/// Rectangle in EMU, in slide coordinates.
class PptxRect {
  const PptxRect(this.x, this.y, this.cx, this.cy);

  final int x;
  final int y;
  final int cx;
  final int cy;

  @override
  bool operator ==(Object other) =>
      other is PptxRect &&
      other.x == x &&
      other.y == y &&
      other.cx == cx &&
      other.cy == cy;

  @override
  int get hashCode => Object.hash(x, y, cx, cy);

  @override
  String toString() => 'PptxRect($x, $y, $cx, $cy)';
}

sealed class PptxShape {
  const PptxShape({
    required this.frame,
    this.rotationDeg = 0,
    this.flipH = false,
    this.flipV = false,
    this.name = '',
  });

  final PptxRect frame;

  /// Clockwise rotation around the frame centre, in degrees.
  final double rotationDeg;
  final bool flipH;
  final bool flipV;

  /// `p:cNvPr/@name` (debug / accessibility).
  final String name;
}

enum PptxGeometry { rect, roundRect, ellipse, triangle, line, other }

/// Path verbs of a freeform (`a:custGeom`) shape.
enum PptxPathOp { moveTo, lineTo, cubicTo, quadTo, arcTo, close }

/// One path command. [args] by kind (all in the path's own coordinate space,
/// i.e. 0..[PptxCustomPath.widthEmu] x 0..[PptxCustomPath.heightEmu]):
/// - moveTo / lineTo: x, y
/// - cubicTo: x1, y1, x2, y2, x, y
/// - quadTo: x1, y1, x, y
/// - arcTo: wR, hR, stAngDeg, swAngDeg (relative to the current point, like
///   `a:arcTo`; angles in degrees, clockwise)
/// - close: no args
class PptxPathCommand {
  const PptxPathCommand(this.kind, [this.args = const []]);

  final PptxPathOp kind;
  final List<double> args;
}

/// One `a:path` of a freeform shape. To draw it, scale the path space
/// ([widthEmu] x [heightEmu]) onto the shape frame.
class PptxCustomPath {
  const PptxCustomPath({
    required this.widthEmu,
    required this.heightEmu,
    required this.commands,
    this.filled = true,
    this.stroked = true,
  });

  final int widthEmu;
  final int heightEmu;
  final List<PptxPathCommand> commands;

  /// False when `a:path fill="none"`.
  final bool filled;

  /// False when `a:path stroke="0"`.
  final bool stroked;
}

enum PptxAnchor { top, middle, bottom }

enum PptxAlign { left, center, right, justify }

/// Text inset of a text body, in EMU.
class PptxInsets {
  const PptxInsets({
    this.left = 91440,
    this.top = 45720,
    this.right = 91440,
    this.bottom = 45720,
  });

  final int left;
  final int top;
  final int right;
  final int bottom;
}

/// A shape fill: either a solid colour or a picture.
class PptxFill {
  const PptxFill.solid(int this.colorArgb)
    : imageBytes = null,
      imageExtension = null;

  const PptxFill.picture(Uint8List this.imageBytes, String this.imageExtension)
    : colorArgb = null;

  /// ARGB colour (0xAARRGGBB) for a solid fill. Gradients are approximated by
  /// their first stop, patterns by their foreground colour.
  final int? colorArgb;
  final Uint8List? imageBytes;

  /// Lower-case file extension without dot ('png', 'jpeg', ...).
  final String? imageExtension;

  bool get isPicture => imageBytes != null;
}

class PptxLine {
  const PptxLine({required this.colorArgb, required this.widthEmu});

  final int colorArgb;
  final int widthEmu;
}

/// Picture crop as fractions (0..1) of the source image removed on each side.
/// Negative values mean the image is padded (OOXML allows it).
class PptxCrop {
  const PptxCrop({
    this.left = 0,
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
}

/// Any shape that can hold text (autoshape, text box, placeholder, connector).
/// Also used as an empty frame for unsupported objects (chart, SmartArt, OLE,
/// media) — then [unsupportedKind] is set.
class PptxTextShape extends PptxShape {
  const PptxTextShape({
    required super.frame,
    super.rotationDeg,
    super.flipH,
    super.flipV,
    super.name,
    this.geometry = PptxGeometry.rect,
    this.presetGeometry,
    this.fill,
    this.line,
    this.paragraphs = const [],
    this.insets = const PptxInsets(),
    this.verticalAnchor = PptxAnchor.top,
    this.wrap = true,
    this.verticalText = false,
    this.unsupportedKind,
    this.customPaths = const [],
  });

  final PptxGeometry geometry;

  /// Paths of an `a:custGeom` freeform (then [geometry] is `other` and
  /// [presetGeometry] null). Empty when the freeform uses guide formulas that
  /// are not evaluated.
  final List<PptxCustomPath> customPaths;

  /// Raw `a:prstGeom/@prst` (e.g. 'rightArrow') when available.
  final String? presetGeometry;
  final PptxFill? fill;
  final PptxLine? line;
  final List<PptxParagraph> paragraphs;
  final PptxInsets insets;
  final PptxAnchor verticalAnchor;

  /// False when `bodyPr wrap="none"`.
  final bool wrap;

  /// True when `bodyPr vert` is a vertical mode.
  final bool verticalText;

  /// 'chart', 'diagram' (SmartArt), 'ole', 'media', 'graphic' or null.
  final String? unsupportedKind;
}

class PptxPictureShape extends PptxShape {
  const PptxPictureShape({
    required super.frame,
    super.rotationDeg,
    super.flipH,
    super.flipV,
    super.name,
    required this.bytes,
    required this.extension,
    this.crop,
    this.line,
  });

  final Uint8List bytes;

  /// Lower-case file extension without dot.
  final String extension;
  final PptxCrop? crop;
  final PptxLine? line;
}

class PptxTableShape extends PptxShape {
  const PptxTableShape({
    required super.frame,
    super.rotationDeg,
    super.flipH,
    super.flipV,
    super.name,
    required this.columnWidthsEmu,
    required this.rows,
  });

  final List<int> columnWidthsEmu;
  final List<PptxTableRow> rows;
}

class PptxTableRow {
  const PptxTableRow({required this.heightEmu, required this.cells});

  final int heightEmu;
  final List<PptxTableCell> cells;
}

class PptxTableCell {
  const PptxTableCell({
    this.paragraphs = const [],
    this.fill,
    this.gridSpan = 1,
    this.rowSpan = 1,
    this.hMerge = false,
    this.vMerge = false,
    this.insets = const PptxInsets(),
    this.verticalAnchor = PptxAnchor.top,
    this.borderLeft,
    this.borderTop,
    this.borderRight,
    this.borderBottom,
  });

  final List<PptxParagraph> paragraphs;
  final PptxFill? fill;

  /// Number of grid columns covered by this cell (>= 1).
  final int gridSpan;

  /// Number of rows covered by this cell (>= 1).
  final int rowSpan;

  /// True when this cell is covered by a cell to its left (do not draw).
  final bool hMerge;

  /// True when this cell is covered by a cell above (do not draw).
  final bool vMerge;
  final PptxInsets insets;
  final PptxAnchor verticalAnchor;
  final PptxLine? borderLeft;
  final PptxLine? borderTop;
  final PptxLine? borderRight;
  final PptxLine? borderBottom;
}

/// Children frames are already converted to slide coordinates (the group's
/// own rotation/flip is NOT baked in: rotate the whole group around its frame).
class PptxGroupShape extends PptxShape {
  const PptxGroupShape({
    required super.frame,
    super.rotationDeg,
    super.flipH,
    super.flipV,
    super.name,
    required this.children,
  });

  final List<PptxShape> children;
}

class PptxParagraph {
  const PptxParagraph({
    this.align = PptxAlign.left,
    this.level = 0,
    this.bulletChar,
    this.numbered = false,
    this.numberingScheme,
    this.bulletFontFamily,
    this.bulletColorArgb,
    this.bulletSizePct,
    this.runs = const [],
    this.spaceBeforePt,
    this.spaceAfterPt,
    this.lineSpacingPct,
    this.lineSpacingPt,
    this.marginLeftEmu = 0,
    this.indentEmu = 0,
    this.endFontSizePt,
  });

  final PptxAlign align;

  /// Outline level 0..8.
  final int level;

  /// Bullet character, null when there is no character bullet.
  final String? bulletChar;

  /// True for an auto-numbered bullet (see [numberingScheme]).
  final bool numbered;

  /// `a:buAutoNum/@type`, e.g. 'arabicPeriod'.
  final String? numberingScheme;

  /// `a:buFont/@typeface` (e.g. 'Wingdings 3', 'Arial'). Symbol fonts store
  /// private-use code points in [bulletChar]: the app should map or replace
  /// them when that font is not available.
  final String? bulletFontFamily;

  /// `a:buClr`; null = same colour as the first run.
  final int? bulletColorArgb;

  /// `a:buSzPct` as percent of the text size (100 = same size), null = 100.
  final double? bulletSizePct;
  final List<PptxRun> runs;
  final double? spaceBeforePt;
  final double? spaceAfterPt;

  /// Line spacing in percent of single spacing (100 = single).
  final double? lineSpacingPct;

  /// Exact line spacing in points (`a:lnSpc/a:spcPts`).
  final double? lineSpacingPt;
  final int marginLeftEmu;

  /// First-line indent relative to [marginLeftEmu] (often negative for bullets).
  final int indentEmu;

  /// Font size of the end-of-paragraph mark (height of an empty paragraph).
  final double? endFontSizePt;

  String get text => runs.map((r) => r.text).join();
}

class PptxRun {
  const PptxRun({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.fontSizePt,
    this.colorArgb,
    this.fontFamily,
    this.isLineBreak = false,
    this.baselineOffsetPct = 0,
    this.hyperlink,
  });

  /// Run text; '\n' for a line break run.
  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;

  /// Effective size after inheritance and `normAutofit fontScale`.
  final double? fontSizePt;

  /// ARGB colour, null when not specified anywhere (render as black).
  final int? colorArgb;
  final String? fontFamily;
  final bool isLineBreak;

  /// Superscript (> 0) / subscript (< 0) offset in percent.
  final double baselineOffsetPct;

  /// External hyperlink target, if any.
  final String? hyperlink;
}
