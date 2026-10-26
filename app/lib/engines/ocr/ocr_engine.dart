import 'dart:ui';

/// Hệ chữ cho OCR (ML Kit). latin gồm cả tiếng Việt, Indonesia, Anh.
/// Không hỗ trợ OCR tiếng Thái (người dùng chốt bỏ 26/10).
enum OcrScript { latin, chinese, japanese, korean }

/// Hệ chữ mặc định theo mã ngôn ngữ app (`vi`, `zh`…). Hàm thuần.
/// Giao diện tiếng Thái (`th`) vẫn OCR bằng latin.
OcrScript ocrScriptForLanguage(String languageCode) => switch (languageCode) {
  'zh' => OcrScript.chinese,
  'ja' => OcrScript.japanese,
  'ko' => OcrScript.korean,
  _ => OcrScript.latin,
};

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
