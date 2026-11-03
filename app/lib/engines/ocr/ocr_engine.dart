import 'dart:ui';

/// Hệ chữ cho OCR (ML Kit). App chỉ hỗ trợ tiếng Việt và tiếng Anh nên chỉ có latin.
enum OcrScript { latin }

class OcrLine {
  const OcrLine(this.text, this.bounds);
  final String text;

  /// Pixel trên ảnh gốc.
  final Rect bounds;
}

class OcrBlock {
  const OcrBlock(this.text, this.bounds, this.lines);
  final String text;
  final Rect bounds;
  final List<OcrLine> lines;
}

class OcrResult {
  const OcrResult({
    required this.text,
    required this.blocks,
    this.imageWidth,
    this.imageHeight,
  });

  /// Toàn văn, block cách nhau bằng dòng trống.
  final String text;
  final List<OcrBlock> blocks;
  final int? imageWidth;
  final int? imageHeight;

  static const empty = OcrResult(text: '', blocks: []);
}

/// Nhận dạng chữ offline bằng ML Kit (model đóng sẵn, không cần mạng).
abstract interface class OcrEngine {
  /// Lỗi: `CorruptFile` (ảnh hỏng), `UnsupportedFormat` (định dạng ảnh không đọc được).
  Future<OcrResult> recognize(String imagePath, OcrScript script);

  /// Giải phóng recognizer.
  Future<void> dispose();
}
