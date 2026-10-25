import 'dart:typed_data';

/// 1 inch = 914400 EMU; 1 point = 12700 EMU.
const int emuPerPoint = 12700;

/// Khung hình theo EMU (gốc trên-trái của slide).
class PptxFrame {
  const PptxFrame(
    this.x,
    this.y,
    this.cx,
    this.cy, {
    this.rotation = 0,
    this.flipH = false,
    this.flipV = false,
  });

  final int x;
  final int y;
  final int cx;
  final int cy;

  /// Độ, theo chiều kim đồng hồ.
  final double rotation;
  final bool flipH;
  final bool flipV;
}

enum PptxAlign { left, center, right, justify }

enum PptxVAlign { top, middle, bottom }

class PptxTextRun {
  const PptxTextRun(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.fontSize,
    this.colorArgb,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;

  /// Point.
  final double? fontSize;
  final int? colorArgb;
}

class PptxParagraph {
  const PptxParagraph(
    this.runs, {
    this.align = PptxAlign.left,
    this.level = 0,
    this.bullet,
  });

  final List<PptxTextRun> runs;
  final PptxAlign align;
  final int level;

  /// Ký tự bullet (null = không có).
  final String? bullet;
}

/// Phần tử trên slide.
sealed class PptxShape {
  const PptxShape(this.frame);
  final PptxFrame frame;
}

/// Hình (`p:sp`): hình học preset + nền/viền + chữ (có thể rỗng).
final class PptxShapeText extends PptxShape {
  const PptxShapeText(
    super.frame, {
    this.geometry = 'rect',
    this.fillArgb,
    this.lineArgb,
    this.lineWidthEmu,
    this.paragraphs = const [],
    this.verticalAlign = PptxVAlign.top,
  });

  /// Tên `a:prstGeom` (`rect`, `roundRect`, `ellipse`, `line`…).
  final String geometry;
  final int? fillArgb;
  final int? lineArgb;
  final int? lineWidthEmu;
  final List<PptxParagraph> paragraphs;
  final PptxVAlign verticalAlign;
}

/// Ảnh (`p:pic`).
final class PptxPicture extends PptxShape {
  const PptxPicture(super.frame, this.bytes, {this.contentType});
  final Uint8List bytes;
  final String? contentType;
}

/// Bảng (`p:graphicFrame` + `a:tbl`) — chữ thuần mỗi ô.
final class PptxTable extends PptxShape {
  const PptxTable(super.frame, this.rows, {this.columnWidthsEmu = const []});
  final List<List<String>> rows;
  final List<int> columnWidthsEmu;
}

/// Nhóm (`p:grpSp`) — con đã đổi về toạ độ slide.
final class PptxGroup extends PptxShape {
  const PptxGroup(super.frame, this.children);
  final List<PptxShape> children;
}

class PptxSlide {
  const PptxSlide({required this.shapes, this.backgroundArgb, this.notes});

  /// Theo thứ tự vẽ (dưới → trên), đã kế thừa vị trí placeholder từ layout/master.
  final List<PptxShape> shapes;
  final int? backgroundArgb;
  final String? notes;
}

/// Bộ slide đã parse. Kích thước slide theo EMU (`presentation.xml` `p:sldSz`).
class PptxDeck {
  const PptxDeck({
    required this.slideWidthEmu,
    required this.slideHeightEmu,
    required this.slides,
  });

  final int slideWidthEmu;
  final int slideHeightEmu;
  final List<PptxSlide> slides;

  double get aspectRatio => slideWidthEmu / slideHeightEmu;
}

/// Đọc .pptx thành [PptxDeck].
abstract interface class PptxEngine {
  /// Lỗi: `CorruptFile`.
  Future<PptxDeck> parseFile(String path);

  Future<PptxDeck> parseBytes(Uint8List bytes);
}
