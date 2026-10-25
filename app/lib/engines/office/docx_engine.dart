import 'dart:typed_data';

/// Căn lề đoạn.
enum DocxAlignment { left, center, right, justify }

/// Một đoạn chữ cùng định dạng.
class DocxRun {
  const DocxRun(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.fontSize,
    this.colorArgb,
    this.highlightArgb,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;

  /// Point; null = mặc định của tài liệu.
  final double? fontSize;
  final int? colorArgb;
  final int? highlightArgb;
}

/// Khối nội dung của tài liệu.
sealed class DocxBlock {
  const DocxBlock();
}

/// Đoạn văn. [headingLevel] 1–6 nếu là Heading, 0 = đoạn thường.
/// [listLevel] ≥ 0 nếu là mục danh sách (null = không), [listOrdered] số / chấm.
final class DocxParagraph extends DocxBlock {
  const DocxParagraph(
    this.runs, {
    this.headingLevel = 0,
    this.alignment = DocxAlignment.left,
    this.listLevel,
    this.listOrdered = false,
    this.spacingAfter,
  });

  final List<DocxRun> runs;
  final int headingLevel;
  final DocxAlignment alignment;
  final int? listLevel;
  final bool listOrdered;

  /// Point; null = mặc định.
  final double? spacingAfter;

  String get plainText => runs.map((r) => r.text).join();
}

/// Ô bảng; [colSpan]/[rowSpan] ≥ 1. Ô bị gộp (phần tiếp theo của rowSpan) có `rowSpan == 0`.
class DocxTableCell {
  const DocxTableCell(
    this.blocks, {
    this.colSpan = 1,
    this.rowSpan = 1,
    this.fillArgb,
  });

  final List<DocxBlock> blocks;
  final int colSpan;
  final int rowSpan;
  final int? fillArgb;
}

final class DocxTable extends DocxBlock {
  const DocxTable(this.rows, {this.columnWidths = const []});

  final List<List<DocxTableCell>> rows;

  /// Point (có thể rỗng nếu file không ghi).
  final List<double> columnWidths;
}

/// Ảnh nhúng. Kích thước theo point.
final class DocxImage extends DocxBlock {
  const DocxImage(this.bytes, {this.width, this.height, this.contentType});

  final Uint8List bytes;
  final double? width;
  final double? height;

  /// vd. `image/png`.
  final String? contentType;
}

/// Ngắt trang.
final class DocxPageBreak extends DocxBlock {
  const DocxPageBreak();
}

/// Tài liệu DOCX đã parse.
class DocxDocument {
  const DocxDocument({
    required this.blocks,
    this.title,
    this.defaultFontSize = 11,
  });

  final List<DocxBlock> blocks;
  final String? title;

  /// Point.
  final double defaultFontSize;
}

/// Đọc .docx thành [DocxDocument] (dùng bởi Office viewer và DOCX→PDF).
abstract interface class DocxEngine {
  /// Lỗi: `CorruptFile` (không phải zip / thiếu `word/document.xml`).
  Future<DocxDocument> parseFile(String path);

  Future<DocxDocument> parseBytes(Uint8List bytes);
}
