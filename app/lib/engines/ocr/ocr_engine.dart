import 'dart:ui';

/// Hệ chữ cho OCR. latin gồm cả tiếng Việt, Indonesia, Anh. thai dùng Tesseract.
enum OcrScript { latin, chinese, japanese, korean, thai }

/// Hệ chữ mặc định theo mã ngôn ngữ app (`vi`, `zh`…). Hàm thuần.
OcrScript ocrScriptForLanguage(String languageCode) => switch (languageCode) {
  'zh' => OcrScript.chinese,
  'ja' => OcrScript.japanese,
  'ko' => OcrScript.korean,
  'th' => OcrScript.thai,
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

/// Nhận dạng chữ offline (ML Kit; tiếng Thái qua Tesseract `assets/tessdata/tha.traineddata`).
abstract interface class OcrEngine {
  /// Lỗi: `CorruptFile` (ảnh hỏng), `UnsupportedFormat` (thiếu traineddata cho [script]).
  Future<OcrResult> recognize(String imagePath, OcrScript script);

  /// Giải phóng recognizer.
  Future<void> dispose();
}
