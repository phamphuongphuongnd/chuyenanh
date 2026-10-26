import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    as mlkit;
import 'package:image_ops/image_ops.dart' as ops;

import '../../../core/errors/app_error.dart';
import '../../../engines/ocr/ocr_engine.dart';

/// Hệ chữ của app → hệ chữ của ML Kit. Hàm thuần.
mlkit.TextRecognitionScript mlKitScriptFor(OcrScript script) =>
    switch (script) {
      OcrScript.latin => mlkit.TextRecognitionScript.latin,
      OcrScript.chinese => mlkit.TextRecognitionScript.chinese,
      OcrScript.japanese => mlkit.TextRecognitionScript.japanese,
      OcrScript.korean => mlkit.TextRecognitionScript.korean,
    };

/// Đổi kết quả ML Kit sang model của app. Toạ độ giữ nguyên (pixel ảnh gốc).
/// Hàm thuần — có unit test.
OcrResult ocrResultFromMlKit(
  mlkit.RecognizedText recognized, {
  int? imageWidth,
  int? imageHeight,
}) {
  final blocks = [
    for (final b in recognized.blocks)
      OcrBlock(b.text, b.boundingBox, [
        for (final l in b.lines) OcrLine(l.text, l.boundingBox),
      ]),
  ];
  // Toàn văn: các block cách nhau bằng dòng trống (ML Kit nối bằng '\n').
  final text = blocks.isEmpty
      ? recognized.text.trim()
      : blocks.map((b) => b.text.trim()).where((t) => t.isNotEmpty).join('\n\n');
  return OcrResult(
    text: text,
    blocks: blocks,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
  );
}

/// Hàm chạy ML Kit cho một ảnh (tách ra để test bằng fake).
typedef MlKitRecognizeFn =
    Future<mlkit.RecognizedText> Function(
      String imagePath,
      mlkit.TextRecognitionScript script,
    );

/// OCR offline bằng ML Kit (model đóng sẵn trong APK). Mỗi hệ chữ giữ một
/// `TextRecognizer` để lần sau không phải khởi tạo lại; [dispose] đóng hết.
///
/// Chỉ chạy được trên máy thật (plugin native) — logic ngoài plugin đã tách thành
/// [mlKitScriptFor] và [ocrResultFromMlKit] để test.
class MlKitOcrEngine implements OcrEngine {
  MlKitOcrEngine({MlKitRecognizeFn? recognizeFn}) {
    _recognizeFn = recognizeFn ?? _defaultRecognize;
  }

  late final MlKitRecognizeFn _recognizeFn;
  final Map<mlkit.TextRecognitionScript, mlkit.TextRecognizer> _recognizers =
      {};

  Future<mlkit.RecognizedText> _defaultRecognize(
    String imagePath,
    mlkit.TextRecognitionScript script,
  ) {
    final recognizer = _recognizers.putIfAbsent(
      script,
      () => mlkit.TextRecognizer(script: script),
    );
    return recognizer.processImage(
      mlkit.InputImage.fromFilePath(imagePath),
    );
  }

  @override
  Future<OcrResult> recognize(String imagePath, OcrScript script) async {
    if (!await File(imagePath).exists()) {
      throw const CorruptFile('image not found');
    }
    // Đọc kích thước (và kiểm ảnh có đọc được) trong isolate; JPEG chỉ đọc header.
    final ops.ImageInfoLite info;
    try {
      info = await Isolate.run(
        () => ops.probe(Uint8List.fromList(File(imagePath).readAsBytesSync())),
      );
    } on FormatException {
      throw const CorruptFile('image unreadable');
    }
    try {
      final recognized = await _recognizeFn(imagePath, mlKitScriptFor(script));
      return ocrResultFromMlKit(
        recognized,
        imageWidth: info.width,
        imageHeight: info.height,
      );
    } on AppError {
      rethrow;
    } catch (e) {
      throw AppError.from(e);
    }
  }

  @override
  Future<void> dispose() async {
    final all = _recognizers.values.toList();
    _recognizers.clear();
    for (final r in all) {
      await r.close();
    }
  }
}
